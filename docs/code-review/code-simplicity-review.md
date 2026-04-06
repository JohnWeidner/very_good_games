# Code Simplicity Review: Leaderboard Feature

**Date**: 2026-04-06
**Scope**: 12 files (6 source, 6 test) -- leaderboard feature implementation
**Reviewer**: Code Simplicity Agent

---

## Simplification Analysis

### Core Purpose

Display a ranked top-10 leaderboard for each daily game by querying Nostr relay events, deduplicating by pubkey, sorting by score, and rendering a simple table. Handle the case where the user has no Nostr identity by prompting for setup.

### Unnecessary Complexity Found

#### 1. [Important] `containsUser` and `findUserEntry` are dead code
**File**: `lib/nostr/stats/models/leaderboard.dart:69-83`

Neither `containsUser()` nor `findUserEntry()` is called anywhere in the production codebase outside of the model file itself and its tests. The view widget (`_LeaderboardTable`) does its own user-matching directly via `_isUserEntry()` using `Helpers.decodeBech32`. These two methods perform redundant hex-to-npub conversion via `Nip19.encodePubKey` to search entries, but nothing calls them.

**Suggestion**: Remove both methods and their corresponding tests (~20 LOC saved in source, ~25 LOC saved in tests).

---

#### 2. [Important] Duplicated event-fetching and dedup logic in repository
**File**: `lib/nostr/stats/repository/community_stats_repository.dart:25-72` and `79-136`

`fetchStats()` and `fetchLeaderboard()` both:
- Build the same `Filter(kinds: [30042], dTags: [dTag], limit: 100)`
- Await with the same 5-second timeout
- Deduplicate by pubkey keeping latest `createdAt` (identical loop, lines 41-47 and 93-99)
- Call `_extractScore()` on each deduplicated event

The dedup-and-fetch portion is duplicated almost verbatim (~15 lines).

**Suggestion**: Extract a private `_fetchDedupedEvents(String dTag)` method that returns `Map<String, Nip01Event>`. Both public methods call it and then diverge for their specific aggregation. Saves ~15 LOC and removes a maintenance hazard where a fix in one copy gets missed in the other.

---

#### 3. [Important] `_isUserEntry` in the view decodes bech32 on every row render
**File**: `lib/nostr/stats/view/leaderboard_section.dart:192-204`

`_isUserEntry` calls `Helpers.decodeBech32(entry.npub)` for every row during every build. The conversion direction is also backwards from the model methods: the model converts hex->npub while the view converts npub->hex. Pick one direction and stick to it.

**Suggestion**: Since entries store npub (bech32), the simplest approach is to convert `userPubKeyHex` to npub once at the top of `_LeaderboardTable.build()` and compare strings directly. This eliminates the try/catch and repeated decode calls:

```dart
@override
Widget build(BuildContext context) {
  final userNpub = userPubKeyHex != null
      ? Nip19.encodePubKey(userPubKeyHex!)
      : null;
  // ...
  // In the row builder:
  color: entry.npub == userNpub
      ? theme.colorScheme.primaryContainer
      : null,
}
```

This removes the `_isUserEntry` method entirely and the `nip01/helpers.dart` import (~13 LOC).

---

#### 4. [Suggestion] `LeaderboardEntry.copyWith` is only used internally for rank assignment
**File**: `lib/nostr/stats/models/leaderboard.dart:36-48`

`copyWith` on `LeaderboardEntry` is only called in the repository to assign ranks after sorting (line 129 of the repository). No other production code calls it. It copies all four fields for a single-field override.

**Suggestion**: This follows project convention so keeping it is reasonable. However, an alternative is to construct entries with the correct rank inline during the take-and-assign loop, eliminating `copyWith` entirely. Low priority.

---

#### 5. [Suggestion] `LeaderboardState.copyWith` cannot clear `leaderboard` to null
**File**: `lib/nostr/stats/cubit/leaderboard_state.dart:41-51`

The `copyWith` uses `leaderboard ?? this.leaderboard`, which means once a leaderboard is set, it cannot be explicitly cleared back to null. The cubit works around this by constructing new `LeaderboardState(...)` instances directly (lines 43, 47-50, 53, 56 of the cubit). This means `copyWith` is only used once (line 36, for `hasIdentity`), and that single use could construct a new state directly.

**Suggestion**: Either use the project's `Type? Function()?` nullable copyWith pattern (documented in CLAUDE.md conventions) for the `leaderboard` field, or remove `copyWith` from `LeaderboardState` entirely since the cubit barely uses it. The simpler option: remove `copyWith` and always construct states directly. Saves ~10 LOC in source and ~33 LOC in tests.

---

#### 6. [Suggestion] `fetchLeaderboard` does not cache (inconsistent with `fetchStats`)
**File**: `lib/nostr/stats/repository/community_stats_repository.dart:79-136`

`fetchStats` caches results in `_cache`, but `fetchLeaderboard` does not. For a daily leaderboard that changes infrequently, the user pays a relay query (up to 5-second timeout) every time the cubit calls `fetchLeaderboard`.

**Suggestion**: Either add a simple cache (like `fetchStats` has) or add a comment explaining why caching is intentionally omitted for leaderboard.

---

#### 7. [Suggestion] `Leaderboard.isEmpty` is a trivial wrapper
**File**: `lib/nostr/stats/models/leaderboard.dart:66`

`isEmpty` delegates to `entries.isEmpty`. It is used once in the view. Callers could use `leaderboard.entries.isEmpty` directly without any clarity loss. Minor -- keep for readability if preferred.

---

### Code to Remove

| Location | Reason | LOC |
|---|---|---|
| `leaderboard.dart:69-83` | `containsUser` + `findUserEntry` unused in prod | ~15 |
| `leaderboard_test.dart:111-135` | Tests for dead methods | ~25 |
| `leaderboard_section.dart:192-204` | `_isUserEntry` method (replace with inline npub comparison) | ~13 |

**Estimated total removable LOC**: ~53 lines (source + test)
**With optional removals** (state copyWith, entry copyWith): ~96 lines

### Simplification Recommendations

1. **Extract shared fetch+dedup logic in repository** (Important)
   - Current: 15 lines of identical relay-query + dedup code in both `fetchStats` and `fetchLeaderboard`
   - Proposed: Single `_fetchDedupedEvents(String dTag)` returning `Map<String, Nip01Event>`
   - Impact: ~15 LOC saved, eliminates copy-paste maintenance risk

2. **Remove dead `containsUser`/`findUserEntry` methods** (Important)
   - Current: Two methods in `Leaderboard` that no production code calls
   - Proposed: Delete them and their tests
   - Impact: ~40 LOC removed (source + test), reduced API surface

3. **Simplify user-highlight logic in view** (Important)
   - Current: `_isUserEntry` decodes bech32 per row with try/catch
   - Proposed: Convert `userPubKeyHex` to npub once, compare strings
   - Impact: ~13 LOC saved, cleaner code, removes `nip01/helpers.dart` import

4. **Remove or fix `LeaderboardState.copyWith`** (Suggestion)
   - Current: `copyWith` used once; cannot null-clear `leaderboard`; violates project's nullable copyWith convention
   - Proposed: Remove it; construct states directly (cubit already does this for 3 of 4 emits)
   - Impact: ~10 LOC saved in source, ~33 in tests

### YAGNI Violations

1. **`containsUser` and `findUserEntry` on `Leaderboard`**
   - These methods anticipate future callers that do not exist today.
   - The view solves user-matching independently.
   - Remove them; add back if/when a caller needs them.

2. **Full `copyWith` on `LeaderboardEntry`**
   - Only the `rank` field override is ever used (in the repository's rank-assignment loop).
   - A four-field `copyWith` anticipates future mutations that do not exist.
   - Low severity since it follows project convention.

### Additional Observations

- **Test quality is solid**: Good coverage of edge cases (malformed scores, dedup, caching, exception handling, multiple calls). Tests are well-structured with appropriate use of `bloc_test`.
- **Barrel files are correct**: `models.dart`, `view.dart`, `stats.dart` all export appropriately.
- **State machine is clean**: The `LeaderboardStatus` enum and state transitions are straightforward.
- **View widget decomposition is good**: Private widgets for each state (`_IdentitySetupPrompt`, `_LoadingPlaceholder`, `_NoScoresYetMessage`, `_UnavailableMessage`, `_LeaderboardTable`) keep `LeaderboardSection.build` readable.
- **Triggering fetch via `addPostFrameCallback` in build**: This is a common Flutter pattern but can fire multiple times if the widget rebuilds while still in `initial` state. Consider whether the fetch should be triggered from the parent or via cubit constructor/`BlocProvider.create` instead.

### Final Assessment

**Total potential LOC reduction**: ~53-96 lines (~10-15% of reviewed code)
**Complexity score**: Low -- the code is generally well-structured and follows project conventions
**Recommended action**: Proceed with simplifications -- focus on the three Important items (extract shared dedup, remove dead methods, simplify user-highlight). The suggestions are lower priority and can be deferred.
