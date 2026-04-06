# VGV Code Review: High Score Leaderboard Implementation Plan

## Summary

**Verdict: READY TO IMPLEMENT WITH MINOR CORRECTIONS**

This is a well-structured, thorough implementation plan that adheres strongly to Very Good Ventures engineering standards. The architecture is sound, testing strategy is comprehensive, and the approach respects VGV conventions for state management, layer separation, and code organization.

The plan demonstrates excellent discipline: it identifies legitimate risks, proposes appropriate mitigations, and stays focused on the MVP scope. The three critical issues flagged below are corrections, not architectural problems—they're easy fixes that ensure the implementation matches existing VGV patterns in this codebase.

---

## CRITICAL — Must Fix Before Implementation Starts

These are not blockers but must be corrected in code before the PR goes up. All are simple refactors that align the plan with project conventions.

### 1. **State file NOT using `part of` pattern** (Line 181)

The plan shows `LeaderboardState` as a standalone class in the same file as `LeaderboardCubit`. This violates the project's established `part of` convention.

**Current (wrong):**
```dart
// leaderboard_cubit.dart
class LeaderboardCubit extends Cubit<LeaderboardState> { ... }
class LeaderboardState extends Equatable { ... }
```

**Should be:**
```dart
// leaderboard_cubit.dart
import 'package:bloc/bloc.dart';
part 'leaderboard_state.dart';

class LeaderboardCubit extends Cubit<LeaderboardState> { ... }
```

```dart
// leaderboard_state.dart
part of 'leaderboard_cubit.dart';

class LeaderboardState extends Equatable { ... }
```

**Why:** Every cubit in this project (CommunityStatsCubit, GameCubit, SignalCubit, ResultSharingCubit) uses `part of` state files. The plan must follow this convention consistently. This also improves code organization and file clarity.

**Fix:** Create separate `leaderboard_state.dart` file with `part of 'leaderboard_cubit.dart'` declaration, move state class and enum there.

---

### 2. **Identity check logic in UI violates layer separation** (Lines 299-311)

The `LeaderboardSection` widget directly calls `NostrIdentityRepository.hasIdentity()` in `_checkAndFetchLeaderboard()`. This breaks the VGV data flow rule: **UI must never access data repositories directly**.

**Problem area:**
```dart
void _checkAndFetchLeaderboard(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted) return;

    // BUG: Direct repo access from UI
    final identityRepo = context.read<NostrIdentityRepository>();
    final hasIdentity = await identityRepo.hasIdentity();

    if (context.mounted) {
      context.read<LeaderboardCubit>().fetchLeaderboard(dTag);
    }
  });
}
```

**Why it matters:** The UI should dispatch to the cubit (state management), which then decides whether to fetch. This keeps data/identity logic centralized and testable. Direct repo calls from UI are a testing and maintainability nightmare.

**Fix:** Move identity check into the cubit. Add an optional `userPubKey` parameter to `fetchLeaderboard()` or create a separate method `initLeaderboard(dTag, userPubKey?)` that the UI calls. The cubit checks identity and decides whether to fetch. The UI just calls the cubit method on init.

**Suggested refactor:**
```dart
// In LeaderboardCubit:
Future<void> initLeaderboard(String dTag) async {
  // Cubit checks identity
  final identityRepo = context.read<NostrIdentityRepository>();
  final hasIdentity = await identityRepo.hasIdentity();
  
  // Only fetch if identity exists
  if (hasIdentity) {
    await fetchLeaderboard(dTag);
  } else {
    emit(const LeaderboardState(status: LeaderboardStatus.unavailable));
  }
}

// In LeaderboardSection UI:
if (state.status == LeaderboardStatus.initial) {
  context.read<LeaderboardCubit>().initLeaderboard(dTag);
}
```

---

### 3. **Missing `firstWhereOrNull` extension import** (Line 95)

The plan uses `firstWhereOrNull()` in the `Leaderboard` model (line 94-95) but doesn't import the extension.

**Current:**
```dart
LeaderboardEntry? findUserEntry(String userPubKey) =>
  entries.firstWhereOrNull((e) => e.npub == userPubKey);
```

**Fix:** Add import to `leaderboard.dart`:
```dart
import 'package:collection/collection.dart';
```

This is a transitive dependency (already in the project via `flutter_bloc` → `collection`), but it must be explicitly imported.

---

## IMPORTANT — Should Fix

### 4. **LeaderboardEntry.alias field is premature generalization** (Lines 75-84)

The plan includes an `alias` field and `displayName` getter that uses it, but admits in "Out of Scope" (line 51) that "Player names (aliases) instead of raw npubs...deferred to future if too complex."

This is a YAGNI violation. The code supports a feature (aliases) that isn't implemented and won't be used in v1.

**Current:**
```dart
class LeaderboardEntry extends Equatable {
  final String? alias;  // Unused in v1
  String get displayName => alias ?? _truncateNpub(npub);
}
```

**Problem:** The field adds cognitive load (what is `alias` for? when is it populated?), adds properties to equality checks unnecessarily, and sets a confusing precedent that we've "prepared for" NIP-05 resolution when we haven't.

**Fix for v1 only (recommended):** Remove `alias` and just use truncated npub.

```dart
class LeaderboardEntry extends Equatable {
  final String npub;
  final int score;
  final int rank;
  final int createdAt;
  
  String get displayName => _truncateNpub(npub);
  
  static String _truncateNpub(String npub) => '${npub.substring(0, 8)}...';
}
```

**When to add alias:** During the v2 feature branch for NIP-05 support, add the field, update EventBuilder to populate it, and update tests. Don't carry dead code.

**Why it matters:** VGV's principle is "Duplication is far cheaper than the wrong abstraction." Carry what you need now. Future code can add the field without major refactoring.

---

### 5. **Mocking strategy for widget tests underspeiced** (Lines 564-575)

The widget test checklist mentions `MockBuildContext` and "BlocBuilder mocking," but the codebase doesn't use custom mocks—it uses `mocktail` for real object mocking.

**Current plan language:**
```
Use flutter_test with MockBuildContext and BlocBuilder mocking.
```

**Fix:** Specify the actual testing pattern used in this project:

```
Use flutter_test with blocTest and testWidgets.
Mock CommunityStatsRepository and LeaderboardCubit via mocktail.
Provide BlocProvider<LeaderboardCubit> in test widget tree.
Test state transitions and rendered output, not framework internals.
```

Look at existing widget tests in the codebase (e.g., in `test/games/guess_the_number/view/`) for the exact pattern to follow.

---

### 6. **Identity setup prompt logic is incomplete** (Lines 268-271)

The UI checks `if (state.status != LeaderboardStatus.loading && state.status != LeaderboardStatus.loaded)` before showing the identity prompt. But the cubit never explicitly sets an "identity_not_set" status—it just returns null.

**Current:**
```dart
if (state.status != LeaderboardStatus.loading &&
    state.status != LeaderboardStatus.loaded) {
  return _IdentitySetupPrompt();
}
```

**Problem:** This shows the prompt for `initial` and `unavailable` states, but the logic is backwards. We should show the prompt ONLY if the user has no identity. The current logic conflates "identity not set" with "relay unavailable," which aren't the same.

**Fix:** Clarify the cubit's responsibility. The cubit should know whether the user has identity:

```dart
// In LeaderboardState
class LeaderboardState extends Equatable {
  const LeaderboardState({
    this.status = LeaderboardStatus.initial,
    this.leaderboard,
    this.hasIdentity = false,
  });
  
  final LeaderboardStatus status;
  final Leaderboard? leaderboard;
  final bool hasIdentity;  // Track identity setup separately from relay state
  
  // ...
}

// In LeaderboardCubit.initLeaderboard()
Future<void> initLeaderboard(String dTag) async {
  final identityRepo = context.read<NostrIdentityRepository>();
  final hasIdentity = await identityRepo.hasIdentity();
  
  emit(state.copyWith(hasIdentity: hasIdentity));
  
  if (!hasIdentity) {
    // Don't fetch; leave status as initial
    return;
  }
  
  await fetchLeaderboard(dTag);
}

// In LeaderboardSection UI
if (!state.hasIdentity) {
  return _IdentitySetupPrompt();
}

if (state.status == LeaderboardStatus.loading) {
  return _LeaderboardSkeleton();
}
```

This separates concerns: `hasIdentity` answers "can the user participate?" and `status` answers "what is the network state?"

---

## SUGGESTIONS — Nice to Have

### 7. **LeaderboardEntry.rank is redundant** (Line 79)

The `rank` field is always `1..10` based on the position in the list. It's only assigned after sorting (lines 161-163) and never updated.

```dart
final int rank;  // Always index + 1, could be computed
```

**Trade-off:** Storing rank makes rendering simpler (`entry.rank`) vs. computing it during render (`leaderboard.entries.indexOf(entry) + 1`). For a top-10 list, this is negligible. **Keep it as-is**—the clarity gain (entry carries its rank) outweighs the minor redundancy, and rank is semantically meaningful in leaderboard context.

---

### 8. **File locations are non-standard** (Lines 231, 627)

The plan puts `LeaderboardSection` in `lib/nostr/sharing/view/leaderboard_section.dart`, but `leaderboard` is stats data, not result sharing.

**Current:**
```
lib/nostr/sharing/view/leaderboard_section.dart  ← Wrong parent
```

**Better:**
```
lib/nostr/stats/view/leaderboard_section.dart  ← Correct parent
```

**Why:** The pattern in this codebase is: each domain module (sharing, stats, identity) owns its view layer. `leaderboard_section.dart` displays leaderboard data from stats, so it belongs under `stats/view/`. This keeps related code together.

**Justification:** `sharing` is for posting results to Nostr. `stats` is for fetching leaderboard data and displaying it. The UI displaying stats belongs in the stats module.

---

### 9. **Cubit provides identity repo dependency unnecessarily** (Lines 304-305)

The plan has `LeaderboardSection` reading `NostrIdentityRepository` directly, but after the refactor (issue #2), the cubit should handle this. The widget shouldn't need identity repo access.

**After fixing issue #2:** Remove this line:
```dart
final identityRepo = context.read<NostrIdentityRepository>();
```

The cubit will handle identity checks internally.

---

### 10. **Skip NoIdentity check if identity has been checked once** (Design note)

The plan calls `_checkAndFetchLeaderboard` on every build in the initial state. After the first fetch (successful or not), skip the check.

**Minor optimization:** Once `initLeaderboard()` has been called and state is no longer `initial`, don't call it again. This prevents re-running identity checks on rebuilds.

The current code does this implicitly (state transitions out of `initial`), so no change needed—just a clarifying comment in the code.

---

## Testing Assessment

**Test coverage: GOOD** — The plan is comprehensive and follows VGV standards.

### Strengths

- [x] Unit tests for models (Equatable, displayName, isEmpty, containsUser)
- [x] Repository tests cover sorting, tie-breaking, deduplication, timeout, exceptions
- [x] Cubit tests cover state transitions (initial → loading → loaded, initial → loading → unavailable)
- [x] Widget tests cover all UI states and user interactions
- [x] Uses `bloc_test` for cubits, `mocktail` for mocks (standard for this project)

### Areas to Verify in Implementation

- **Cubit identity integration:** Make sure the cubit's `initLeaderboard()` properly reads the identity repo and emits state accordingly. Test the path where user has no identity.
- **Widget build cycles:** Verify that `addPostFrameCallback` isn't called multiple times. Test rebuilds after initial load.
- **User highlighting:** In the widget test, verify the highlighting logic correctly converts between npub (stored in LeaderboardEntry) and userPubKey (hex, passed from page). The plan shows `Nip19.decodePubKey(entry.npub) == userPubKey` (line 400)—make sure both are the same format.
- **Relay timeout:** Test the 5-second timeout with a slow relay. Ensure state goes to `unavailable` cleanly.
- **Empty list:** Test "No scores yet" message when `entries.isEmpty`.

---

## Simplicity Assessment

**Complexity verdict: ALREADY MINIMAL**

- **Lines of code:** ~750 total (models + cubit + UI + tests). Appropriate for feature scope.
- **Unnecessary abstractions:** None. Models are simple data holders, cubit is straightforward state machine, UI is layered but clear.
- **YAGNI violations:** One significant one (alias field, issue #4). Remove it for v1.
- **Code clarity:** Naming is excellent (`LeaderboardEntry`, `LeaderboardStatus`, `fetchLeaderboard`, `displayName`). Everything reads clearly.

**Simplifications to apply:**
1. Remove `alias` field from `LeaderboardEntry` (issue #4).
2. Simplify identity check to cubit responsibility (issue #2).

After these changes, the code will be even cleaner.

---

## Regressions & Breaking Changes

**Risk: MINIMAL**

- No existing code is modified except: results overlays (+1 line each), game pages (+5 lines each), barrel files (+1 line each).
- `CommunityStatsRepository.fetchLeaderboard()` is a new method; no breaking changes to existing `fetchStats()`.
- No dependencies added (uses ndk, flutter_bloc, equatable—already in project).
- No public API changes to existing code.

**Verification checklist:**
- [ ] Ensure `dTag` is accessible in both `GameState` and `SignalState` (assumption check before starting).
- [ ] Verify barrel file exports are added correctly.
- [ ] Run `dart fix --apply` and `dart analyze` after implementation.

---

## Architecture & Conventions Compliance

### State Management
- [x] Uses Bloc/Cubit (LeaderboardCubit) — correct pattern
- [x] State is immutable with copyWith — correct pattern
- [x] Equatable for equality — correct pattern
- [NEEDS FIX] State file must use `part of` (issue #1)

### Layer Separation
- [NEEDS FIX] Identity check must move to cubit, not UI (issue #2)
- [x] Data source calls go through repository (CommunityStatsRepository)
- [x] No cross-layer imports (UI → view, view → cubit, cubit → repository)
- [SHOULD FIX] LeaderboardSection belongs in `stats/view/`, not `sharing/view/` (issue #8)

### Models & Data
- [x] LeaderboardEntry and Leaderboard are Equatable immutable
- [x] No force unwraps (uses nullable types correctly)
- [NEEDS FIX] firstWhereOrNull requires explicit import (issue #3)
- [SHOULD REMOVE] alias field is unused in v1 (issue #4)

### Naming & Clarity
- [x] File names match primary export (`leaderboard_cubit.dart`, `leaderboard_section.dart`)
- [x] Class names are descriptive (LeaderboardStatus, LeaderboardEntry, etc.)
- [x] Method names are action-oriented (fetchLeaderboard, findUserEntry)
- [x] All follow 5-second rule—no unclear names

### Barrel Files & Imports
- [SHOULD ADD] Create `lib/nostr/stats/view/view.dart` and export LeaderboardSection
- [SHOULD ADD] Create `lib/nostr/stats/cubit/cubit.dart` and export LeaderboardCubit + LeaderboardState
- [NEEDS FIX] Create `lib/nostr/stats/models/leaderboard.dart` (and no barrel file needed if only one file, or add to any existing barrel)

---

## Files to Create (Corrected)

- [x] `lib/nostr/stats/models/leaderboard.dart` — LeaderboardEntry, Leaderboard models
- [x] `lib/nostr/stats/cubit/leaderboard_cubit.dart` — LeaderboardCubit class ONLY
- [x] `lib/nostr/stats/cubit/leaderboard_state.dart` — LeaderboardState class with `part of` declaration
- [CORRECTED] `lib/nostr/stats/view/leaderboard_section.dart` — UI widget (NOT in sharing/)

---

## Implementation Checklist

Before you start coding:

- [ ] **Review existing tests** in `test/games/guess_the_number/view/` to match testing patterns exactly (widget test setup, BlocProvider wrapping, etc.)
- [ ] **Verify GameState and SignalState have dTag field** accessible in results overlay context
- [ ] **Check CommunityStatsRepository imports** (does it already import `collection` for firstWhereOrNull? Verify.)
- [ ] **Verify nostr_identity_repository exists** and has `hasIdentity()` method

After implementing:

- [ ] Run `dart fix --apply` to auto-fix any linting issues
- [ ] Run `dart analyze` and ensure zero issues (except pre-existing info hints)
- [ ] Run all new tests: `flutter test test/nostr/stats/ test/nostr/sharing/`
- [ ] Manually test both games' result overlays with and without Nostr relays available
- [ ] Verify user's entry highlights correctly when in top 10

---

## Final Recommendation

**PROCEED WITH IMPLEMENTATION** after applying the critical fixes:

1. Fix state file to use `part of` pattern.
2. Move identity check to cubit (remove from UI).
3. Add collection import for firstWhereOrNull.
4. (Recommended) Remove alias field for v1.
5. (Recommended) Move leaderboard_section to stats/view/.

This is a well-planned, well-scoped feature that will ship cleanly with minor corrections. The architecture is sound, testing is thorough, and it respects VGV conventions throughout. After the fixes above, it will be indistinguishable from code written by the VGV team.
