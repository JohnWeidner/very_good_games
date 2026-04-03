---
title: "feat: add NIP-09 relay content deletion on identity delete"
type: feat
date: 2026-04-03
---

## feat: add NIP-09 relay content deletion on identity delete

## Overview

When a user deletes their Nostr identity, attempt to delete their published game results (kind 30042) from relays using NIP-09 (kind 5 deletion events) before removing the local key. Show progress during the deletion flow.

## Problem Statement / Motivation

Currently, `NostrIdentityRepository.deleteIdentity()` only removes the nsec from secure storage. Published kind 30042 events remain on relays indefinitely. Users who delete their identity expect their content to be removed too. The delete dialog even says "Your published results will remain on the network" — this should become best-effort cleanup instead.

## Proposed Solution

### New Files

```
lib/
  nostr/
    sharing/
      repository/
        nostr_deletion_repository.dart   # Queries user events, sends kind 5 deletion
```

### Changes to Existing Files

| File | Change |
|---|---|
| `lib/nostr/identity/cubit/nostr_identity_cubit.dart` | Update `deleteIdentity()` to accept `NostrDeletionRepository`, run relay deletion before local key deletion, emit progress states |
| `lib/nostr/identity/cubit/nostr_identity_state.dart` | Add `deletionProgress` field (current/total) to state for progress display |
| `lib/settings/view/widgets/nostr_identity_section.dart` | Update delete dialog messaging, show deletion progress indicator |
| `lib/nostr/sharing/sharing.dart` | Export `nostr_deletion_repository.dart` |
| `lib/app/app.dart` | Provide `NostrDeletionRepository` via `RepositoryProvider` |
| `lib/main.dart` | Create `NostrDeletionRepository.lazy()` |

### Architecture

**`NostrDeletionRepository`**: Wraps Ndk relay operations for querying and deleting user events. Follows the same lazy-Ndk pattern as `NostrPublishRepository`. Exposes two methods:

- `queryUserEvents(String pubKeyHex)` — Queries relays with `Filter(authors: [pubKeyHex], kinds: [30042], limit: 1000)`, returns list of event IDs
- `deleteEvents({required List<String> eventIds, required NostrSigner signer, required String pubKeyHex})` — Creates a single kind 5 event with `['e', id]` tags for each event + `['k', '30042']`, signs it, broadcasts to default relays. Returns `true` if at least 1 relay accepts.

**Deletion flow in `NostrIdentityCubit.deleteIdentity()`:**
1. Emit `loading` state
2. Get signer and public key hex (before deleting the key!)
3. Query relays for user's kind 30042 events via `NostrDeletionRepository`
4. Emit progress state: "Found N results to delete"
5. If events found: create and broadcast kind 5 deletion event
6. Emit progress state: "Deletion request sent"
7. Delete local key via `NostrIdentityRepository.deleteIdentity()` (always, regardless of relay outcome)
8. Emit `none` state

**Progress in state**: Add an optional `deletionProgress` field to `NostrIdentityState`:
```dart
({int current, int total, String message})? deletionProgress
```
Used by the UI to show "Deleting 3 results from relays..." during the flow.

### NIP-09 Event Format

```jsonc
{
  "kind": 5,
  "tags": [
    ["e", "<event-id-1>"],
    ["e", "<event-id-2>"],
    ["k", "30042"]
  ],
  "content": "Deleting game results"
}
```

- One kind 5 event for all events (batched, not per-event)
- `k` tag identifies the kind being deleted (NIP-09 requirement)

### UI Changes

**Delete dialog** (`NostrIdentitySection._showDeleteDialog`):
- Update message from "Your published results will remain" to "We'll try to delete your published results from relays. This cannot be guaranteed."
- After user confirms, show progress via `BlocListener` on `NostrIdentityCubit`:
  - `deletionProgress != null` → show a non-dismissible dialog with progress message
  - When deletion completes (state back to `none`) → dismiss progress dialog

### Error Handling

- **No events found**: Skip deletion, proceed to local key delete
- **Query fails**: Log warning, proceed to local key delete
- **Kind 5 broadcast fails**: Log warning, proceed to local key delete
- **Signer unavailable**: Proceed to local key delete (shouldn't happen but defensive)
- In all cases: local key is always deleted. Best-effort relay cleanup.

## Acceptance Criteria

### Deletion Repository
- [ ] `queryUserEvents()` queries relays with correct filter (kind 30042, author pubkey, limit 1000)
- [ ] `queryUserEvents()` returns list of event IDs
- [ ] `queryUserEvents()` returns empty list on failure or timeout (5s)
- [ ] `deleteEvents()` creates kind 5 event with correct `e` and `k` tags
- [ ] `deleteEvents()` signs the event via the provided signer
- [ ] `deleteEvents()` returns true if at least 1 relay accepts
- [ ] `deleteEvents()` returns false on failure
- [ ] Full unit test coverage (mock `Ndk`)

### Cubit Updates
- [ ] `deleteIdentity()` queries for user events before deleting local key
- [ ] Signs kind 5 deletion event before deleting the nsec
- [ ] Emits progress states during deletion flow
- [ ] Always deletes local key, even if relay deletion fails
- [ ] Full unit test coverage with `bloc_test`

### UI Updates
- [ ] Delete dialog message updated to mention relay deletion
- [ ] Progress shown during deletion (message visible to user)
- [ ] Widget tests for progress display

## Technical Considerations

- The signer must be obtained *before* deleting the local key — once the nsec is gone, we can't sign the kind 5 event
- The `NostrDeletionRepository` reuses the same lazy-Ndk pattern. Open question from brainstorm: should we share an Ndk instance? For now, keep independent — simplicity over optimization.
- `NdkResponse.future` collects events until EOSE, same pattern as `CommunityStatsRepository`

## Dependencies

- Requires identity management (PR 2) and sharing infrastructure (PR 3)
- Independent of community stats (PR 4)

## References

- NIP-09 spec: https://github.com/nostr-protocol/nips/blob/master/09.md
- Divine-mobile implementation: `mobile/lib/services/account_deletion_service.dart`
- Current deletion: `lib/nostr/identity/cubit/nostr_identity_cubit.dart:90-105`
- Delete dialog: `lib/settings/view/widgets/nostr_identity_section.dart:73-97`
- Brainstorm: `docs/brainstorm/2026-04-03-relay-content-deletion-brainstorm-doc.md`
