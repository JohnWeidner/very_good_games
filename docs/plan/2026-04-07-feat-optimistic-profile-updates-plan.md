---
title: "feat: optimistic profile updates"
type: feat
date: 2026-04-07
---

## feat: optimistic profile updates

## Overview

Make profile saves feel instant by emitting the updated profile into state immediately after local validation, then publishing to Nostr relays in the background with silent retry. Scoped to profile updates only — result sharing and other relay flows are unchanged.

## Problem Statement / Motivation

When a user saves their profile, the UI shows a spinner and blocks for the full relay round-trip (sign, broadcast, wait for `OK` — up to 10 seconds on timeout). Relay publishes rarely fail, so this wait is perceived latency with no practical benefit.

Nostr kind-0 events are self-authenticating (signed locally) and replaceable. The event is valid the moment it's signed — the relay is just a distribution layer. Most Nostr clients (Damus, Primal, Amethyst) use optimistic updates for this reason.

## Proposed Solution

### High-Level Flow

```
User taps Save
  → Cubit emits `publishing` (prevents double-tap)
  → await getSigner() + getPublicKeyHex() (fast, local)
  → If no identity → emit error (unchanged)
  → Construct optimistic NostrProfile from inputs + existing rawJson
  → Cache optimistic profile in Drift via repository
  → Emit `published` with optimistic profile in state
  → UI shows "Profile saved!" snackbar and pops (instant)
  → Background: repository.publishProfile() with retry
  → Background success: Drift cache overwritten with signed version
  → Background failure (all retries exhausted): log warning
```

### File Changes

#### 1. `NostrProfileRepository` — add `cacheProfile` public method

**File:** `packages/nostr_identity/lib/src/profile/nostr_profile_repository.dart`

Expose the existing `_cacheProfile` helper as a public method so the cubit can cache the optimistic profile before the background publish starts.

```dart
/// Caches a profile in the local Drift database.
///
/// Used for optimistic updates — caches the profile immediately
/// so subsequent reads return the updated values.
Future<void> cacheProfile(NostrProfile profile) => _cacheProfile(profile);
```

This resolves the race condition where the user navigates back to `ProfileEditPage` before the background publish completes — `_loadExistingProfile()` reads from Drift via `getProfile()`, which will now return the optimistic values.

#### 2. `ProfileCubit.publishProfile` — optimistic emit + background publish

**File:** `lib/nostr/profile/cubit/profile_cubit.dart`

Rewrite `publishProfile` to:

1. Emit `publishing` (prevents double-tap via button guard)
2. `await` signer + pubkey lookup (fast, local)
3. Guard: if `_publishInFlight` is true, return early (prevents concurrent publishes)
4. Set `_publishInFlight = true`
5. Construct optimistic `NostrProfile` from inputs, using existing profile's `rawJson` if available in state for field preservation
6. Cache optimistic profile via `_profileRepository.cacheProfile(optimisticProfile)`
7. Merge into profiles map, emit `published`
8. Fire `_backgroundPublish(...)` (unawaited)

Add `_backgroundPublish` private method:

```dart
Future<void> _backgroundPublish({
  required NostrSigner signer,
  required String pubkeyHex,
  required String name,
  String? picture,
  String? about,
}) async {
  try {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final success = await _profileRepository.publishProfile(
        signer: signer,
        pubkeyHex: pubkeyHex,
        name: name,
        picture: picture,
        about: about,
      );
      if (success) return;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    // All retries exhausted — log warning.
    // Drift cache has optimistic values; next publish will re-merge.
  } on Exception {
    // Silent failure — logged by repository.
  } finally {
    _publishInFlight = false;
  }
}
```

Add a `bool _publishInFlight = false;` instance field to guard against concurrent publishes.

#### 3. `ProfileEditPage` — no changes needed

The `BlocListener` already handles `ProfileStatus.published` by showing a snackbar and popping. The `BlocBuilder` on the Save button already checks `ProfileStatus.publishing`. Both work as-is — the transition from `publishing` → `published` will just be near-instant instead of waiting for relays.

#### 4. Tests — update cubit expectations

**File:** `test/nostr/profile/cubit/profile_cubit_test.dart`

Update the `publishProfile` test group:

- **Success path:** `[publishing, published]` — same states, but:
  - Verify `cacheProfile` is called with the optimistic profile
  - Verify `publishProfile` is called (background, may need `await Future<void>.delayed(Duration.zero)` to flush)
  - Remove dependency on `getProfile` being called after publish (it's no longer called)
- **No identity:** `[publishing, error]` — unchanged
- **Concurrent publish guard:** New test — call `publishProfile` twice rapidly, verify only one `publishProfile` repository call
- **Background failure:** New test — mock `publishProfile` to return `false` 3 times, verify state remains `published` (no error emitted), verify 3 attempts were made

**File:** `test/settings/view/profile_edit_page_test.dart` — no changes expected (widget tests mock the cubit, not the repository).

## Technical Considerations

### Race Conditions Addressed

1. **Save-then-reopen:** Optimistic profile is cached in Drift immediately, so `ProfileEditPage._loadExistingProfile()` reads updated values even before relay publish completes.

2. **Concurrent publishes:** `_publishInFlight` boolean prevents overlapping background publishes. Second save attempt returns early while first is in-flight.

3. **fetchProfiles overwriting optimistic data:** The leaderboard's `fetchProfiles` could overwrite the current user's entry with stale relay data. This is acceptable for v1 — the window is small (seconds) and the visual impact is minor (profile name in leaderboard briefly shows old value). A future enhancement could protect the current user's pubkey during background publish.

### Cubit Lifecycle

`ProfileCubit` is provided at the app level (used by both settings and leaderboard), so it outlives the `ProfileEditPage`. The background future will not be cancelled when the page pops.

### Retry Strategy

Simple linear backoff: 2s, 4s, 6s across 3 attempts. Each retry calls the full `publishProfile` (read-merge-sign-broadcast) to ensure the merge reflects the latest state. Total worst-case delay: ~12s in background, invisible to the user.

### Cache Consistency

The optimistic Drift cache entry will temporarily lack a valid `createdAt` (set to `null` since the event hasn't been signed yet). The background publish overwrites this with the signed event's `createdAt`. The `rawJson` field is constructed from the existing profile's `rawJson` merged with new values, so unknown fields (e.g., `nip05`, `lud16`) are preserved.

## Acceptance Criteria

- [ ] Profile save feels instant — page pops and snackbar shows within ~100ms of tapping Save
- [ ] Optimistic profile values appear in the settings page immediately after save
- [ ] Background relay publish succeeds silently (verified via relay `OK`)
- [ ] Background publish retries up to 3 times on failure with 2s/4s/6s delays
- [ ] Concurrent save taps do not trigger duplicate publishes
- [ ] Re-opening profile edit after save shows the new values (from Drift cache)
- [ ] Unknown fields in rawJson (e.g., `nip05`) are preserved through the optimistic update
- [ ] No identity → error state is unchanged
- [ ] All existing profile cubit tests pass (updated for new flow)
- [ ] New tests cover: concurrent publish guard, background retry exhaustion

## Success Metrics

- Profile save perceived time drops from ~2-5s to <200ms
- No increase in relay publish failure rate (background retries handle transient errors)

## Dependencies & Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Background publish fails permanently | Low | User sees updated profile locally but others see old one | Next `publishProfile` call will re-merge and push |
| Cubit disposed before background completes | Very low (app-level cubit) | Publish silently cancelled | Acceptable for v1; could move to isolate/service later |
| `fetchProfiles` overwrites optimistic data | Low (small time window) | Brief flicker of old profile in leaderboard | Acceptable for v1; could add pubkey guard later |

## References & Research

- Brainstorm: `docs/brainstorm/2026-04-07-optimistic-profile-updates-brainstorm-doc.md`
- ProfileCubit: `lib/nostr/profile/cubit/profile_cubit.dart`
- ProfileState: `lib/nostr/profile/cubit/profile_state.dart`
- NostrProfileRepository: `packages/nostr_identity/lib/src/profile/nostr_profile_repository.dart`
- ProfileEditPage: `lib/settings/view/profile_edit_page.dart`
- Cubit tests: `test/nostr/profile/cubit/profile_cubit_test.dart`
- Widget tests: `test/settings/view/profile_edit_page_test.dart`
- Nostr kind-0 spec: replaceable event, relays keep only latest per pubkey
- Nostr relay OK message: `["OK", event_id, true/false, message]` is definitive confirmation
