# Architecture Review: Leaderboard Feature

**Branch**: `main`
**Date**: 2026-04-06
**Reviewer**: Architecture Review Agent
**Scope**: 8 changed files in `lib/nostr/stats/` for leaderboard feature

---

## Architecture Review

### Layer Separation

**Layers within `lib/nostr/stats/`**:
- **Models** (`models/`): Data classes -- `LeaderboardEntry`, `Leaderboard`
- **Repository** (`repository/`): Relay queries and data transformation -- `CommunityStatsRepository`
- **Cubit** (`cubit/`): State management -- `LeaderboardCubit`, `LeaderboardState`
- **View** (`view/`): Presentation -- `LeaderboardSection` and private helper widgets

**Import scan results**:

| File | Imports | Status |
|------|---------|--------|
| `models/leaderboard.dart` | `equatable`, `ndk` | Clean |
| `models/models.dart` | (barrel) | Clean |
| `repository/community_stats_repository.dart` | `ndk`, `nostr/relay/*`, `nostr/stats/models/*` | Clean |
| `cubit/leaderboard_cubit.dart` | `bloc`, `equatable`, `nostr/identity/repository/*`, `nostr/stats/models/*`, `nostr/stats/repository/*` | Clean |
| `cubit/leaderboard_state.dart` | (part of cubit) | Clean |
| `view/leaderboard_section.dart` | `flutter`, `flutter_bloc`, `ndk/shared/nips/nip01/helpers.dart`, `nostr/identity/view/*`, `nostr/stats/cubit/*`, `nostr/stats/models/*` | **Violation** |
| `view/view.dart` | (barrel) | Clean |
| `stats.dart` | (barrel) | Clean |

- **Violations found: 1**
  - `lib/nostr/stats/view/leaderboard_section.dart:3` -- View layer imports `package:ndk/shared/nips/nip01/helpers.dart` directly. The `_LeaderboardTable._isUserEntry()` method (lines 192-203) performs bech32 decoding via `Helpers.decodeBech32()`, which is a data/protocol-layer operation leaking into a presentation widget.

- **Clean files**: All other 7 files have correct layer-respecting imports.

**Recommended fix**: The `Leaderboard` model already provides `containsUser(String userPubKeyHex)` (line 69) and `findUserEntry(String userPubKeyHex)` (line 75) which perform the same hex-to-npub conversion internally. The view's `_isUserEntry` duplicates this logic in reverse (npub-to-hex). Replace it with:

```dart
bool _isUserEntry(LeaderboardEntry entry) {
  if (userPubKeyHex == null) return false;
  return leaderboard.findUserEntry(userPubKeyHex!) == entry;
}
```

This eliminates the ndk import from the view entirely and reuses existing model logic.

---

### State Management Assessment

#### LeaderboardCubit: Correct

- Uses `Cubit` with `part of` state file -- follows VGV convention.
- State class (`LeaderboardState`) extends `Equatable` with all-`final` immutable fields.
- `copyWith` pattern present on state.
- Business logic (identity check, relay fetch, error handling) lives in the cubit, not the view.
- Both `CommunityStatsRepository` and `NostrIdentityRepository` injected via constructor -- testable.
- Status enum (`LeaderboardStatus`) covers all states: `initial`, `loading`, `loaded`, `unavailable` -- complete state machine.
- Exception handling wraps relay calls and emits `unavailable` on failure -- correct resilience pattern.

#### LeaderboardState: Correct

- All fields are `final` -- immutable.
- `props` includes all three fields (`status`, `leaderboard`, `hasIdentity`) -- Equatable will detect all changes.
- Nullable `Leaderboard?` field is appropriate (only present when loaded).
- Default values are sensible: `status = initial`, `hasIdentity = true`.

#### Minor Observation

`leaderboard_section.dart:32-37`: The view triggers `fetchLeaderboard` inside `BlocBuilder` using `addPostFrameCallback` when status is `initial`. The `initial` check prevents duplicate fetches on rebuild, which is good. However, triggering data loading from within a builder is borderline. Ideally, the cubit would receive the `dTag` at construction time and fetch automatically. This is a style observation, not a violation.

---

### Dependency Direction

**Direction violations: 0** (excluding the view-layer ndk import covered under Layer Separation)

```
stats.dart (barrel)
  |
  +---> models/leaderboard.dart
  |       +---> equatable, ndk (external only)
  |
  +---> repository/community_stats_repository.dart
  |       +---> ndk, nostr/relay/*, models/*
  |
  +---> cubit/leaderboard_cubit.dart
  |       +---> bloc, equatable
  |       +---> nostr/identity/repository/* (sibling module)
  |       +---> models/*, repository/*
  |
  +---> view/leaderboard_section.dart
          +---> flutter, flutter_bloc
          +---> nostr/identity/view/* (sibling module)
          +---> cubit/*, models/*
```

- No circular dependencies detected.
- No reverse dependencies (models do not import cubit, repository does not import view, etc.).
- Cross-module dependencies (`nostr/identity/`) flow at appropriate layers: cubit imports identity repository, view imports identity view. Both are lateral dependencies within the `nostr/` module, not upward violations.

**Minor note**: The cubit imports `nostr/identity/repository/nostr_identity_repository.dart` directly rather than through the `nostr/identity/identity.dart` barrel file. Per CLAUDE.md conventions ("use barrel files"), the import should be `package:very_good_games/nostr/identity/identity.dart` or the repository's barrel. Not a blocking issue.

---

### Package Structure

#### Barrel Files: Complete

- `lib/nostr/stats/models/models.dart` -- exports `community_stats.dart` and `leaderboard.dart`.
- `lib/nostr/stats/view/view.dart` -- exports `leaderboard_section.dart`.
- `lib/nostr/stats/stats.dart` -- exports cubits, models, and repository.
- Exports are alphabetically ordered -- matches VGV convention.

#### Test Coverage: Complete

All four layers have corresponding test files:
- `test/nostr/stats/models/leaderboard_test.dart`
- `test/nostr/stats/repository/community_stats_repository_test.dart`
- `test/nostr/stats/cubit/leaderboard_cubit_test.dart`
- `test/nostr/stats/view/leaderboard_section_test.dart`

#### Single Responsibility: Good

The leaderboard feature extends the existing `lib/nostr/stats/` module rather than creating a new top-level directory. This is correct since it shares the relay infrastructure (`CommunityStatsRepository`) and the same Nostr event type (kind 30042).

#### Naming: Consistent

All names are descriptive and follow Dart/VGV conventions: `LeaderboardCubit`, `LeaderboardState`, `LeaderboardStatus`, `LeaderboardEntry`, `Leaderboard`, `LeaderboardSection`.

---

### Additional Observations

#### Duplicate Deduplication Logic in Repository

`community_stats_repository.dart` contains identical "deduplicate by pubkey, keeping latest" logic in both `fetchStats` (lines 41-47) and `fetchLeaderboard` (lines 93-99). Extracting a shared private helper would reduce duplication:

```dart
Map<String, Nip01Event> _deduplicateByPubkey(Iterable<Nip01Event> events) {
  final byPubkey = <String, Nip01Event>{};
  for (final event in events) {
    final existing = byPubkey[event.pubKey];
    if (existing == null || event.createdAt > existing.createdAt) {
      byPubkey[event.pubKey] = event;
    }
  }
  return byPubkey;
}
```

#### Identity Setup Pattern: Correct

The view correctly uses `IdentitySetupLauncher.launch(context)` as specified in CLAUDE.md conventions. No custom navigation flow is duplicated.

---

### Detailed Findings

#### [I-1] View layer imports ndk data package directly

**File**: `lib/nostr/stats/view/leaderboard_section.dart:3`
**Severity**: Important

The `_LeaderboardTable._isUserEntry()` method imports `package:ndk/shared/nips/nip01/helpers.dart` to call `Helpers.decodeBech32()` for comparing user identity. This is a protocol-level operation that belongs in the model or repository layer. The `Leaderboard` model already provides equivalent methods (`containsUser`, `findUserEntry`) that encapsulate this logic. The view should use those instead.

#### [S-1] Extract deduplication helper in repository

**File**: `lib/nostr/stats/repository/community_stats_repository.dart:41-47, 93-99`
**Severity**: Suggestion

Identical pubkey deduplication logic is duplicated between `fetchStats` and `fetchLeaderboard`. Extract to a shared private method.

#### [S-2] Use barrel file for identity repository import

**File**: `lib/nostr/stats/cubit/leaderboard_cubit.dart:3`
**Severity**: Suggestion

Direct file import `nostr/identity/repository/nostr_identity_repository.dart` should use the barrel file per project convention.

---

### Verdict

**Ready to merge after fixing 1 important issue.**

| Severity | Count | Summary |
|----------|-------|---------|
| Critical | 0 | -- |
| Important | 1 | View imports ndk data-layer package directly; should use existing `Leaderboard` model methods instead |
| Suggestion | 2 | Extract deduplication helper in repository; use barrel file for identity repository import |

The leaderboard feature demonstrates clean architecture overall: proper Cubit/state separation with `part of`, Equatable models with immutable fields, constructor-based dependency injection, complete barrel exports, and test files for every layer. The one important issue is a straightforward fix that eliminates a data-layer import from the view by using model methods that already exist.
