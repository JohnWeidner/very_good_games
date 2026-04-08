# Test Quality Review: feat/chromix-contiguity-drag

**Date**: 2026-04-07
**Branch**: `feat/chromix-contiguity-drag` vs `main`
**Reviewer**: Automated Test Quality Agent
**Stack**: Flutter, flutter_bloc, bloc_test, mocktail, very_good_analysis

---

## Coverage Summary

- **Test run**: Pass (125/125 chromix tests green)
- **Files with tests**: 10/13 changed source files have corresponding tests
- **Missing test files**:
  - `lib/core/view/widgets/win_celebration.dart` (NEW) -- No corresponding test file
  - `lib/games/chromix/view/chromix_page.dart` -- No corresponding test file

### Deleted Files

- `lib/games/chromix/view/widgets/color_palette.dart` and its test `test/games/chromix/view/widgets/color_palette_test.dart` were properly deleted together. No orphaned tests.

### Non-Chromix Changed Files (Low Risk)

- `lib/games/guess_the_number/view/game_page.dart` -- Changed to integrate `WinCelebration`. Additive UI wiring only.
- `lib/games/signal/view/signal_page.dart` -- Same `WinCelebration` integration. Same assessment.

---

## State Management Test Quality

### chromix_cubit_test.dart: Issues Found

**Strengths**:
- Uses `bloc_test` with `blocTest` for most state transitions (VGV convention).
- Uses `mocktail` for `GameStorageRepository` mocking.
- Good coverage of drag lifecycle: startDrag, dragTo, endDrag.
- Overpower timer tests cover mix-then-timeout, cancel-on-lift, and undo-restores-mix-then-original.
- Persistence round-trip test with `_RealStorageHelper` is well-designed.
- Corrupted session graceful recovery is tested.

**Issues**:

1. **[Critical] Win detection test does not actually verify the won state** (line 548-575).
   The test titled "emits won when grid matches target and is contiguous" does not drive the cubit to a won state. It verifies the solver confirms uniqueness and that a single drag produces `playing` status -- but never tests the `ChromixStatus.won` transition. This is the most critical state transition in the game and it has no direct test. The `score` field being set on win, and `stars` computed from score, are also untested.
   - **Fix**: Create a test that constructs a cubit one move from winning (using a known seed or direct state manipulation), performs the winning move, and asserts `status == ChromixStatus.won`, `score != null`, and `stars > 0`.

2. **[Important] hasContiguityViolation test is trivial** (line 577-587).
   The test only verifies the initial state has no violation. It never creates a state with a violation and verifies `hasContiguityViolation == true`, nor does it verify the violation clears after undo. The group name says "recomputed after move and undo" but only checks initial state.
   - **Fix**: Create a test with a known grid layout where placing a color creates a disconnected group matching the target count. Assert `hasContiguityViolation == true`. Then undo and assert it returns to `false`.

3. **[Important] Multiple tests silently skip on null helpers** (lines 319, 367, 456, etc.).
   Tests in the overpower group use `if (pair == null) { cubit.close(); return; }` which means the test passes without executing any assertions. Since seed 42 is deterministic, these helpers should always return valid cells. If they do not, the test should fail rather than silently skip. This creates false confidence about coverage.
   - **Fix**: Replace with `final pair = _adjacentDifferentPrimaries(cubit.state.grid)!;` or add `expect(pair, isNotNull, reason: 'seed 42 must have adjacent different primaries');`.

4. **[Suggestion] Persistence test does not verify serialized data structure**.
   The test (line 596-625) only verifies `saveSession` was called with any `Map<String, dynamic>`. It does not verify the map contains expected keys (`cells`, `moveCount`, `undoCount`, `moveHistory`).
   - **Fix**: Use `captureAny()` or a custom matcher to verify the saved map structure.

5. **[Suggestion] dragTo same-color primary is not tested**.
   The cubit has an explicit `if (targetCell.color == dragColor) return;` guard, but no test covers dragging a primary onto the same primary color (should be a no-op).

6. **[Suggestion] No test for `startDrag`/`undo` when status is `won`**.
   Both methods have early returns when `status != ChromixStatus.playing`, but this guard is never tested.

7. **[Suggestion] `resetWithSeed` has no direct unit test**.
   It is only used implicitly. A test could verify it re-initializes state with a new seed.

---

## Logic Test Quality

### contiguity_checker_test.dart: Pass

Well-structured with 7 test cases covering:
- Fully contiguous grid (true)
- Disconnected same-color group (false)
- Single-color grid (true)
- Single-cell colors -- trivially contiguous (true)
- Blockers separating colors (true)
- Empty cells breaking contiguity (false)
- Grid with only empty and blocker cells (true)

No issues found. Good edge case coverage.

### puzzle_generator_test.dart: Pass

Good coverage with 8 tests:
- Determinism (same seed = same puzzle)
- Different seeds produce different puzzles
- Generated puzzles have unique solutions
- Blocker count in valid range (tested across 20 seeds)
- Pre-filled count > 0 (tested across 20 seeds)
- Target distribution matches non-blocker count
- Optimal moves is positive
- At least 5 colors in target (tested across 15 seeds)
- Max blocker edge case

No issues found.

### puzzle_solver_test.dart: Pass

Good coverage with 5 test cases:
- Unique contiguous solution returns `isUnique: true`
- Matching distribution but non-contiguous returns `isUnique: false`
- No solution returns `isUnique: false` with `optimalMoves: 0`
- Pre-filled primary layering explored (red + yellow = orange)
- Pre-filled primary left as-is
- Two valid contiguous arrangements yield `isUnique: false`

Clean, well-documented, meaningful assertions.

---

## UI Component Test Quality

### chromix_cell_widget_test.dart: Pass

5 test cases covering:
- Empty cell rendering
- Blocker cell rendering
- Color cell rendering
- Highlight border when `isHighlighted: true`
- Corner rounding based on shared edges

Uses `MaterialApp` wrapper correctly. Assertions check `BoxDecoration` properties -- verifies visual behavior.

### chromix_grid_test.dart: Minor Issues

**Strengths**:
- Uses `MockCubit` with `bloc_test`/`mocktail` (VGV convention).
- Tests render count (16 cells), gesture callbacks, and edge sharing.

**Issues**:

1. **[Suggestion] No test for drag origin highlight**.
   The grid applies `isHighlighted: true` to the cell at `state.dragOrigin`. No test verifies this visual state.

2. **[Suggestion] Blob labels are not tested**.
   The grid renders floating text labels (R, Y, B, O, G, P) at blob centroids. No test verifies these labels appear.

### color_bar_test.dart: Pass

4 tests covering label rendering, empty distribution, segments with count labels, and all six colors present. Clean and well-organized.

### instructions_dialog_test.dart: Pass

Verifies dialog opens with expected sections (Goal, Color Mixing, Drag to Spread Color, Contiguity Rule, Score) and dismisses on "Got it!" button. Appropriate for a static informational dialog.

---

## Anti-Patterns Found

### 1. chromix_cubit_test.dart: Silent skip on null helpers

- **Location**: Lines 319, 367, 456 and similar patterns
- **Issue**: `if (pair == null) { cubit.close(); return; }` causes the test to pass without executing any assertions. With deterministic seed 42, these helpers should always return values.
- **Fix**: Use non-null assertion (`pair!`) or add `expect(pair, isNotNull)` before proceeding.

### 2. chromix_cubit_test.dart:549-574: Test name does not match behavior

- **Location**: "emits won when grid matches target and is contiguous"
- **Issue**: The test never reaches the won state. It verifies solver uniqueness and a single drag, but the win transition is never tested. The name creates false expectations.
- **Fix**: Either rename to match actual behavior ("solver confirms generated puzzle is solvable") or implement the actual win detection test.

---

## Missing Test Coverage

### Missing Test Files

| Source File | Priority | Reason |
|---|---|---|
| `lib/core/view/widgets/win_celebration.dart` (NEW) | Important | Shared widget used by 3 game pages. Timer-based celebration sequence with confetti + callback. Should test trigger/reset lifecycle. |
| `lib/games/chromix/view/chromix_page.dart` | Important | Top-level page with BlocConsumer wiring, win celebration trigger, streak persistence, instructions dialog gating. |

### Missing Behavioral Coverage (Within Existing Test Files)

| Area | What Is Missing |
|---|---|
| Cubit: Won state transition | No test drives the cubit to `ChromixStatus.won` |
| Cubit: Score calculation on win | No test verifies `state.score` is set correctly |
| Cubit: Star rating from score | No test verifies `state.stars` property |
| Cubit: Contiguity violation = true | No test creates an actual violation state |
| Cubit: Drag/undo rejected when won | No test for early-return guards on won status |
| Cubit: `resetWithSeed` | No direct unit test |

---

## Pattern Compliance

| Pattern | Status | Notes |
|---|---|---|
| bloc_test for cubits | Pass | ChromixCubit uses blocTest correctly |
| mocktail for mocks | Pass | All mocks use mocktail |
| UI tests with MaterialApp wrapper | Pass | All widget tests wrap in MaterialApp |
| Seeded initial states | Pass | Cubit tests use async `_waitForReady` for non-initial state |
| setUp/tearDown | Partial | Used in persistence group but not in overpower group (some duplication) |
| Group organization | Pass | All tests use group() for logical organization |
| MockCubit for UI tests | Pass | Uses `MockCubit<ChromixState>` from bloc_test |

---

## Recommendations

1. **[Most impactful] Add a win detection integration test for ChromixCubit.** This is the core game mechanic and the most critical untested path. Find or construct a seed where one move away from winning is achievable, drive the cubit to completion, and verify `status == won`, `score != null`, and `stars > 0`.

2. **[High impact] Replace silent null returns with assertions in cubit tests.** The `if (pair == null) return` pattern silently skips test logic. With seed 42, all helpers should return valid values. Make them fail loudly if they do not.

3. **[High impact] Add a WinCelebration widget test.** This is a new shared widget used across all three games. Test that `trigger()` starts the confetti and fires the callback after the delay, and `reset()` cleans up state.

4. **[Medium impact] Add a ChromixPage widget test.** Test that loading state shows progress indicator, playing state shows grid + color bars + undo row, won state shows results overlay, and contiguity violation text appears when `hasContiguityViolation == true`.

5. **[Medium impact] Add a hasContiguityViolation positive test.** Construct a grid where a color has its target count met but cells are disconnected, verify the flag is set, then undo to clear.

6. **[Lower impact] Test blob labels and drag highlight in ChromixGrid widget test.** These are player-facing visual feedback mechanisms.

---

## Verdict

**Needs work before merging.** Fix 1 critical and 3 important issues.

The logic layer (contiguity checker, puzzle generator, puzzle solver) is well-tested with strong edge case coverage. The widget tests follow VGV conventions correctly. However, the cubit tests have a significant gap: the most critical state transition (winning the game) is not actually verified, and the contiguity violation flag is only tested in its trivial initial state. The silent null-return pattern in several tests creates false confidence about coverage. The new `WinCelebration` shared widget has no tests.

**Issue counts**:
- **Critical**: 1 (win state transition untested)
- **Important**: 3 (contiguity violation untested, silent null skips create false confidence, WinCelebration missing test file)
- **Suggestions**: 5 (persistence data verification, same-color drag no-op, drag/undo rejection when won, grid visual feedback, test name mismatch)
