---
title: "feat: add profile bottom sheet and follows-aware leaderboard"
type: feat
date: 2026-04-10
brainstorm: docs/brainstorm/2026-04-10-profile-sheet-follows-leaderboard-brainstorm-doc.md
---

## feat: add profile bottom sheet and follows-aware leaderboard

## Overview

Add a profile bottom sheet that opens when tapping a leaderboard row, displaying another user's Nostr profile (name, avatar, about, NIP-05, Lightning address), a "last updated" timestamp, a manual refresh button, and a "View on Nostr" external link. Make the leaderboard follows-aware by reading the current user's NIP-02 contact list (kind-3) from relays, querying game scores for followed users, and merging them into a single deduplicated list with global top scores. Followed users are marked with a subtle indicator icon.

## Problem Statement / Motivation

The leaderboard currently shows anonymous global top-10 scores with truncated npubs. Users cannot see who these people are or whether they know them. Tapping a row does nothing. The app has Nostr profile data available through relays but doesn't surface it in the leaderboard context. Adding profile viewing and follows integration makes the leaderboard socially meaningful — users see scores from people they follow alongside global top performers, and can peek at any player's profile with a tap.

## Proposed Solution

### Open Question Resolutions

These decisions resolve the open questions from the [brainstorm doc](../brainstorm/2026-04-10-profile-sheet-follows-leaderboard-brainstorm-doc.md):

| Question | Decision | Rationale |
|---|---|---|
| "View on Nostr" web client | `https://njump.me/{npub}` | Universal, no account needed, renders any profile |
| NIP-05 and lud16 on `NostrProfile` | Computed getters parsing from `rawJson` | No Drift schema migration, no model widening, fields extracted on demand |
| Follow list cap | 150 contacts (from end of list per NIP-02 ordering) | Balances relay query cost vs. coverage; most recently followed are most relevant |
| Kind-3 cache location | In-memory in `ContactListRepository` | Single event per user, avoids Drift schema migration; can upgrade to Drift later |
| No-identity users + leaderboard | Show global leaderboard to all users; gate only follows features behind identity | Current behavior (hiding leaderboard entirely) blocks majority of early users |
| `_staleDuration` configurability | Change the constant to 7 days | Simple, no API surface change; configurability can be added later |
| Kind-3 cache staleness | 24 hours | Contact lists change more frequently than profiles; cheap single-event re-fetch |
| Merged leaderboard cap | Top 10 global + up to 10 additional followed users not in global = max ~20 | Keeps the UI manageable; shows followed users who aren't top-10 stars |
| NIP-05 verification | Display as plain text, unverified | Adding HTTP verification requests is out of scope; matches "read-only window" principle |

### Architecture

The feature spans three layers:

1. **Data layer** (`packages/nostr_identity/`): Extend `NostrProfile` with `nip05`/`lud16` getters and `lastFetchedAt`. Add `ContactListRepository` for kind-3 fetching with in-memory cache.
2. **State management** (`lib/nostr/`): New `ContactListCubit`, updated `LeaderboardCubit` with follows-aware merge logic, new `ProfileSheetCubit` for the bottom sheet.
3. **UI layer** (`lib/nostr/`): New `ProfileBottomSheet` widget, updated `LeaderboardSection` with tappable rows and follow indicators.

### Progressive Loading Strategy

To avoid blocking the leaderboard on multiple sequential relay round-trips:

1. **Phase 1 (immediate)**: Fetch global leaderboard (existing single relay query) and display it
2. **Phase 2 (background)**: Fetch kind-3 contact list, then query followed users' scores, merge into leaderboard, and re-render with follow indicators

This means the UI shows global scores first, then enriches with follow data. The `LeaderboardState` needs a `followsStatus` field independent of the main `status`.

---

## Implementation Plan

### Phase 1: Data Layer — `NostrProfile` Extensions

**Files to modify:**

- [ ] `packages/nostr_identity/lib/src/profile/nostr_profile.dart` — Add computed getters and `lastFetchedAt`
- [ ] `packages/nostr_identity/lib/src/profile/nostr_profile_repository.dart` — Change stale duration, surface `lastFetchedAt`
- [ ] Update existing tests for `NostrProfile` and `NostrProfileRepository`

**Changes:**

`nostr_profile.dart`:
- Add `String? get nip05` getter that parses from `rawJson` (returns `json['nip05']`)
- Add `String? get lud16` getter that parses from `rawJson` (returns `json['lud16']`)
- Add `final int? lastFetchedAt` field (unix seconds) to the constructor and `props`
- Cache the parsed `rawJson` map lazily to avoid re-parsing on each getter call

`nostr_profile_repository.dart`:
- Change `_staleDuration` from `Duration(hours: 24)` to `Duration(days: 7)` (line 29)
- Update `_fromRow()` to pass `lastFetchedAt: row.lastFetchedAt` to `NostrProfile`
- Add `forceRefresh` parameter to `getProfile()` that bypasses cache freshness check (for manual refresh button)

### Phase 2: Data Layer — Contact List Repository

**New files:**

- [ ] `packages/nostr_identity/lib/src/contact_list/contact_list.dart` — Model
- [ ] `packages/nostr_identity/lib/src/contact_list/contact_list_repository.dart` — Repository
- [ ] `packages/nostr_identity/lib/src/contact_list/contact_list.dart` barrel file (or single barrel)
- [ ] Update `packages/nostr_identity/lib/nostr_identity.dart` barrel to export new files
- [ ] Unit tests for `ContactListRepository`

**`ContactList` model:**
```
ContactList {
  final String ownerPubkey;      // hex pubkey of the user
  final Set<String> followedPubkeys;  // hex pubkeys from kind-3 p-tags
  final int fetchedAt;           // unix seconds when fetched
}
```

**`ContactListRepository`:**
- Constructor takes `NdkProvider`
- `Future<ContactList?> getContactList(String pubkeyHex)` — checks in-memory cache (24h staleness), queries kind-3 from relays if stale/missing
- `Future<ContactList?> forceRefresh(String pubkeyHex)` — bypasses cache, re-fetches from relay
- Kind-3 query: `Filter(authors: [pubkeyHex], kinds: [3], limit: 1)` on `defaultRelayUrls`
- Extract followed pubkeys from `p` tags: `event.tags.where((t) => t[0] == 'p').map((t) => t[1])`
- Cap at 150 contacts (take from end of list, per NIP-02 append ordering)
- In-memory cache: `Map<String, ContactList>` keyed by owner pubkey

### Phase 3: State Management — Contact List & Leaderboard Updates

**New files:**

- [ ] `lib/nostr/stats/cubit/contact_list_cubit.dart` — Cubit
- [ ] `lib/nostr/stats/cubit/contact_list_state.dart` — State (part of cubit)
- [ ] Unit tests for `ContactListCubit`

**`ContactListCubit`:**
- Constructor takes `ContactListRepository` and `NostrIdentityRepository`
- `Future<void> loadFollows()` — checks identity, fetches contact list, emits loaded state
- State: `ContactListState { status (initial/loading/loaded/unavailable), followedPubkeys: Set<String> }`
- Used by both `LeaderboardSection` (for follow indicators) and `ProfileBottomSheet` (for "Following" badge)

**Files to modify:**

- [ ] `lib/nostr/stats/repository/community_stats_repository.dart` — Add `fetchScoresForAuthors()`
- [ ] `lib/nostr/stats/cubit/leaderboard_cubit.dart` — Add follows-aware merge
- [ ] `lib/nostr/stats/cubit/leaderboard_state.dart` — Add `followedPubkeys` and `followsStatus`
- [ ] `lib/nostr/stats/models/leaderboard.dart` — Add `isFollowed` field to `LeaderboardEntry`
- [ ] Update existing tests for modified cubits and repository

**`CommunityStatsRepository` additions:**
- Add `fetchScoresForAuthors(String dTag, List<String> authorPubkeys)` method
  - Query: `Filter(kinds: [30042], dTags: [dTag], authors: authorPubkeys, limit: authorPubkeys.length)`
  - Chunk author lists into batches of 50 for relay queries
  - Return `List<LeaderboardEntry>` (unranked, with scores extracted)

**`LeaderboardEntry` update:**
- Add `final bool isFollowed` field (default `false`) to constructor, `props`, and `copyWith`

**`LeaderboardState` update:**
- Add `followedPubkeys: Set<String>` (default `{}`)
- Add `followsStatus: LeaderboardStatus` (default `initial`) — independent of main `status`

**`LeaderboardCubit` update:**
- Remove the identity gate that prevents fetching global leaderboard (lines 33-38 in `leaderboard_cubit.dart`)
- Still check identity, but store it in state and proceed with global fetch regardless
- Add `Future<void> mergeFollowedScores(String dTag, Set<String> followedPubkeys)` method:
  1. Emit `followsStatus: loading`
  2. Call `_statsRepository.fetchScoresForAuthors(dTag, followedPubkeys.toList())`
  3. Merge: take existing global entries + followed entries, deduplicate by npub, sort by score DESC / createdAt ASC
  4. Mark entries where npub is in followedPubkeys as `isFollowed: true`
  5. Cap at 20 total, re-assign ranks 1-N
  6. Emit `followsStatus: loaded` with merged leaderboard

### Phase 4: UI — Profile Bottom Sheet

**New files:**

- [ ] `lib/nostr/profile/view/profile_bottom_sheet.dart` — Sheet widget
- [ ] `lib/nostr/profile/cubit/profile_sheet_cubit.dart` — Cubit for sheet state
- [ ] `lib/nostr/profile/cubit/profile_sheet_state.dart` — State
- [ ] Update barrel files
- [ ] Widget tests for `ProfileBottomSheet`
- [ ] Cubit tests for `ProfileSheetCubit`

**`ProfileSheetCubit`:**
- Constructor takes `NostrProfileRepository` and `String pubkeyHex`
- `Future<void> loadProfile()` — fetches profile via repository, emits loaded state
- `Future<void> refreshProfile()` — calls repository with `forceRefresh: true`, re-emits
- State: `ProfileSheetState { status, profile: NostrProfile?, error: String? }`

**`ProfileBottomSheet` widget:**
- Launched via `showModalBottomSheet()` from leaderboard row tap
- Creates its own `ProfileSheetCubit` inside the builder (wraps with `BlocProvider`), passing `NostrProfileRepository` from parent context via `context.read<NostrProfileRepository>()`
- Receives `pubkeyHex`, `isFollowed` (bool), and `isCurrentUser` (bool) as parameters

**Sheet layout (top to bottom):**
1. **Drag handle** — standard Material bottom sheet handle
2. **Avatar** — `CircleAvatar` with `NetworkImage(profile.picture)`, fallback to `Icons.person` placeholder. Use `errorBuilder` on `Image.network` for broken URLs
3. **Name** — `profile.displayName`, bold, large text
4. **"Following" badge** — `Chip` with `Icons.person_check`, shown only if `isFollowed == true`
5. **About** — `profile.about`, body text, max 3 lines with "show more" expand (optional, can just show full text if short enough)
6. **NIP-05** — `profile.nip05`, shown with a verification-style icon (but unverified), hidden if null
7. **Lightning address** — `profile.lud16`, shown with `Icons.bolt`, hidden if null
8. **"View on Nostr"** — `OutlinedButton` with `Icons.open_in_new`, opens `https://njump.me/{npub}` via `url_launcher`
9. **"Updated X ago"** — Subtle timestamp at bottom, relative format ("3 days ago")
10. **Refresh button** — `IconButton` with `Icons.refresh`, triggers `refreshProfile()` on cubit

**Loading state:** Show a shimmer/skeleton placeholder for avatar + name + 3 text lines.

**Error/empty state:** Show truncated npub as name, person icon as avatar, hide all optional fields.

**Own profile tap:** Same sheet, no "Following" badge, optionally add "Edit Profile" text button that navigates to existing profile edit in Settings.

### Phase 5: UI — Leaderboard Updates

**Files to modify:**

- [ ] `lib/nostr/stats/view/leaderboard_section.dart` — Tappable rows, follow indicators, progressive loading
- [ ] Widget tests for updated `LeaderboardSection`

**Tappable rows:**
- Replace `Table` with `Column` of `InkWell`-wrapped rows (or wrap each `TableRow`'s content in `GestureDetector`)
- Since `TableRow` doesn't support `onTap`, the simplest approach is to keep `Table` for layout but wrap each data row's cells in an `InkWell` that spans the row width
- Alternative: switch to `ListView` with a custom row widget. This is cleaner for tap handling but changes the layout approach. Recommend `InkWell`-wrapped `Row` inside a `ListView.builder` for cleaner code
- Header row: not tappable (no `InkWell`)
- On tap: call `showModalBottomSheet()` to open `ProfileBottomSheet` with the tapped entry's pubkey

**Follow indicator:**
- Add a small `Icon(Icons.person_check, size: 14)` next to the player name for entries where `isFollowed == true`
- Use `Row(children: [nameText, if (isFollowed) followIcon])` in the Player column

**Progressive loading:**
- `LeaderboardSection` triggers `ContactListCubit.loadFollows()` in `initState` (parallel with existing `fetchLeaderboard`)
- Add `BlocListener<ContactListCubit, ContactListState>` that calls `LeaderboardCubit.mergeFollowedScores()` when follows load
- If no identity: skip `ContactListCubit` load, show global leaderboard only (no identity prompt blocking the leaderboard)
- The identity setup prompt moves from replacing the leaderboard to appearing *above* it as an optional card

**No-identity behavior change:**
- Currently: `!state.hasIdentity` → show `_IdentitySetupPrompt`, no leaderboard visible
- New: Always show leaderboard. If `!state.hasIdentity`, show the identity prompt *above* the leaderboard as an informational card (not a gate)

### Phase 6: Wiring & Dependencies

**Files to modify:**

- [ ] `pubspec.yaml` — Add `url_launcher` dependency
- [ ] `lib/app/app.dart` or `main.dart` — Provide `ContactListRepository` via `RepositoryProvider`
- [ ] Game page files (each game's page) — Add `ContactListCubit` to `MultiBlocProvider`, wire up profile sheet access
- [ ] Update barrel files across all new directories

**Dependency injection:**
- `ContactListRepository` created in `main.dart` with `NdkProvider`
- Provided via `RepositoryProvider` at app level
- `ContactListCubit` created per game page in `MultiBlocProvider` (same scope as `LeaderboardCubit`)
- `ProfileBottomSheet` accesses `NostrProfileRepository` from parent context, creates its own `ProfileSheetCubit`

### Phase 7: Tests

- [ ] **Unit tests**: `ContactList` model, `ContactListRepository` (mock NdkProvider, test caching/staleness/cap)
- [ ] **Cubit tests**: `ContactListCubit` (loading, no identity, no follows, large list), `ProfileSheetCubit` (load, refresh, error), updated `LeaderboardCubit` (global-only, merged, dedup, no identity still loads)
- [ ] **Widget tests**: `ProfileBottomSheet` (loaded, loading, empty, refresh tap, view on nostr tap), `LeaderboardSection` (row tap opens sheet, follow indicators shown, progressive load, no-identity shows leaderboard)
- [ ] **Repository tests**: `CommunityStatsRepository.fetchScoresForAuthors` (chunking, dedup, empty)

---

## Technical Considerations

### Architecture Impacts
- **Bottom sheet context isolation**: `showModalBottomSheet` creates a new context that doesn't inherit `BlocProvider`s from the game page. The sheet must create its own cubits, receiving repositories from the parent context before the sheet opens.
- **Package boundary**: `ContactListRepository` lives in `nostr_identity` package since contact lists are user-identity-adjacent data. The cubit (`ContactListCubit`) lives in the app since it's app-level state management.
- **No Drift migration**: By using in-memory caching for the contact list and computed getters for NIP-05/lud16, we avoid a Drift schema v1→v2 migration. This can be added in a future iteration if persistent caching becomes necessary.

### Performance Implications
- **Sequential relay queries**: Follows-aware leaderboard requires kind-3 fetch → score query (2 sequential round-trips). Progressive loading mitigates perceived latency.
- **Author list chunking**: For users with 150 follows, relay queries are split into 3 batches of 50 authors each. NDK handles connection pooling.
- **Profile caching at 7 days**: Reduces relay traffic ~7x compared to 24-hour staleness. Manual refresh compensates for users wanting fresh data.

### Security Considerations
- **NIP-05 displayed unverified**: Shown as plain text without a verification badge to avoid implying the app has verified the DNS record. No HTTP requests to third-party domains.
- **External links**: `url_launcher` opens njump.me in system browser. No in-app WebView that could be manipulated.
- **Lightning address display**: Shown as informational text only. No payment actions in the app.

---

## Acceptance Criteria

### Data Layer
- [ ] `NostrProfile.nip05` returns the NIP-05 identifier from `rawJson`, or null
- [ ] `NostrProfile.lud16` returns the Lightning address from `rawJson`, or null
- [ ] `NostrProfile.lastFetchedAt` is populated from Drift cache
- [ ] Profile cache staleness is 7 days
- [ ] `NostrProfileRepository.getProfile()` accepts `forceRefresh` parameter
- [ ] `ContactListRepository` fetches kind-3 events and extracts followed pubkeys
- [ ] Contact list is capped at 150 entries (from end of list)
- [ ] Contact list cache has 24-hour staleness

### Leaderboard
- [ ] Global leaderboard visible to users without Nostr identity (no longer gated)
- [ ] Identity setup prompt appears above leaderboard, not instead of it
- [ ] Followed users' scores merged with global top-10, deduplicated by pubkey
- [ ] Merged list capped at ~20 entries with correct rank assignment
- [ ] Followed users marked with a subtle person-check icon
- [ ] Global leaderboard loads first; follow data merges in when available

### Profile Bottom Sheet
- [ ] Tapping a leaderboard row opens a modal bottom sheet
- [ ] Sheet displays: name, avatar, about, NIP-05, lud16 (all conditionally hidden if null)
- [ ] "Following" badge shown when viewed user is in contact list
- [ ] "View on Nostr" button opens `njump.me/{npub}` in system browser
- [ ] "Updated X ago" timestamp shown at bottom
- [ ] Refresh button fetches fresh profile from relay
- [ ] Loading state shows placeholder/skeleton
- [ ] Error/empty state shows truncated npub as fallback

### Edge Cases
- [ ] No identity: global leaderboard shown, no follow indicators, profile sheet works (no "Following" badge)
- [ ] No follows (empty kind-3): leaderboard is global-only, no follow indicators
- [ ] Kind-3 fetch fails: leaderboard is global-only, no error shown to user
- [ ] Profile not found on relay: sheet shows truncated npub, person icon placeholder
- [ ] Own row tap: profile sheet opens for self, no "Following" badge

### Tests
- [ ] Unit tests for `ContactList` model and `ContactListRepository`
- [ ] Cubit tests for `ContactListCubit`, `ProfileSheetCubit`, updated `LeaderboardCubit`
- [ ] Widget tests for `ProfileBottomSheet` and updated `LeaderboardSection`
- [ ] Repository tests for `CommunityStatsRepository.fetchScoresForAuthors`

---

## Success Metrics

- Leaderboard is visible to 100% of users (not just those with identity)
- Profile sheet loads in under 2 seconds for cached profiles
- Follow indicators appear within 5 seconds of game completion (progressive load)
- No regressions in existing leaderboard functionality

---

## Dependencies & Risks

| Dependency | Risk | Mitigation |
|---|---|---|
| `url_launcher` package | Low — mature, well-maintained | Standard Flutter plugin |
| Kind-3 relay availability | Medium — user's kind-3 may not exist on our 3 relays | Graceful degradation to global-only leaderboard |
| Large author relay queries | Medium — some relays reject large filter arrays | Chunk into batches of 50; accept partial results |
| Bottom sheet context isolation | Low — known Flutter pattern | Create cubits inside sheet builder with repositories from parent |
| In-memory contact list cache | Low — lost on app restart | Contact list is cheap to re-fetch; Drift upgrade can come later |

---

## References & Research

- Brainstorm: [2026-04-10 Profile Sheet & Follows Leaderboard](../brainstorm/2026-04-10-profile-sheet-follows-leaderboard-brainstorm-doc.md)
- Existing profile model: [nostr_profile.dart](../../packages/nostr_identity/lib/src/profile/nostr_profile.dart)
- Existing profile repo: [nostr_profile_repository.dart](../../packages/nostr_identity/lib/src/profile/nostr_profile_repository.dart)
- Existing leaderboard UI: [leaderboard_section.dart](../../lib/nostr/stats/view/leaderboard_section.dart)
- Existing leaderboard cubit: [leaderboard_cubit.dart](../../lib/nostr/stats/cubit/leaderboard_cubit.dart)
- Existing stats repo: [community_stats_repository.dart](../../lib/nostr/stats/repository/community_stats_repository.dart)
- Existing leaderboard model: [leaderboard.dart](../../lib/nostr/stats/models/leaderboard.dart)
- NIP-02 (Contact List): https://github.com/nostr-protocol/nips/blob/master/02.md
- NIP-01 (Kind-0 Profile): https://github.com/nostr-protocol/nips/blob/master/01.md
