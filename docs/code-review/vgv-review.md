## VGV Code Review -- Chromix Contiguity Drag Interaction

### Summary

This branch adds contiguity constraint enforcement and drag-based interaction to the Chromix game, replacing the old tap-to-select color palette with a drag-from-primary mechanic. It also extracts a shared `WinCelebration` widget to `lib/core/view/widgets/` and updates Signal and Guess the Number pages to use it. The code is generally well-structured and follows VGV conventions for Bloc/Cubit state management with `part of` state files, Equatable models, and barrel exports. The contiguity checker logic and puzzle solver updates are solid. However, there are several issues that should be addressed before merging: duplicated BFS logic across three locations in the cubit, a new shared widget that bypasses the barrel file and lacks tests, cubit tests with silent-skip guards that can mask regressions, and the win detection test that does not actually test winning. Overall assessment: **needs work** -- the critical issues should be addressed before merging.

### Critical -- Must Fix Before Merge

- **lib/core/view/widgets/win_celebration.dart** -- Not exported from any barrel file; imported via direct path.
  - Why: The project conventions state "Imports: use barrel files; never import across layer boundaries." All three consumers (`chromix_page.dart`, `signal_page.dart`, `game_page.dart`) import `win_celebration.dart` directly via `package:very_good_games/core/view/widgets/win_celebration.dart` instead of through `core.dart`. The `lib/core/core.dart` barrel does not export this widget, so it is invisible to consumers following barrel-file conventions.
  - Fix: Add `export 'view/widgets/win_celebration.dart';` to `lib/core/core.dart`. Update all three game page imports to use `package:very_good_games/core/core.dart`.

- **lib/core/view/widgets/win_celebration.dart** -- No unit or widget tests for a new shared widget.
  - Why: This widget is used by all three game pages (Chromix, Signal, Guess the Number). It manages timers, confetti controllers, and callback sequencing. A bug here breaks every game's win experience. No `test/core/view/widgets/win_celebration_test.dart` exists. Untested shared infrastructure is a liability -- this is the VGV standard: "Untested code is unfinished code."
  - Fix: Add `test/core/view/widgets/win_celebration_test.dart` covering: `trigger` fires confetti after 200ms delay, results callback fires after ~1.2s, `reset` cancels timers and hides confetti, `dispose` cleans up timers, `of()` returns state from ancestor.

- **lib/games/chromix/cubit/chromix_cubit.dart:352-386 and :467-512** -- Duplicated BFS contiguity logic in three places.
  - Why: The `_isColorContiguous` instance method (line 352), the static `_computeContiguityViolation` method (line 467), and the standalone `allGroupsContiguous` function in `contiguity_checker.dart` all implement the same BFS flood-fill algorithm for checking color group connectivity. Three copies of the same algorithm is a maintenance hazard -- a bug fix in one will be missed in the others.
  - Fix: Extract a `bool isColorGroupContiguous(ChromixGrid grid, ChromixColor color)` function to `contiguity_checker.dart`. Replace `_isColorContiguous` and the inline BFS in `_computeContiguityViolation` with calls to this function. The cubit should delegate contiguity checking entirely to the logic layer.

### Important -- Should Fix

- **test/games/chromix/cubit/chromix_cubit_test.dart** -- Multiple tests silently skip when preconditions are not met.
  - Why: Tests like `startDrag no-op for secondary cell` (line 160), all three overpower tests (lines 319, 362, 450), and `immediate overpower on secondary cell` have `if (pair == null) return;` guards that silently skip the entire test body. If the puzzle generator changes and these preconditions are never met for seed 42, the tests pass while testing nothing. This is a false-confidence anti-pattern.
  - Fix: Either use `fail('Expected to find adjacent different primaries for seed $seed')` to catch when preconditions are not met, or use a known seed that guarantees the precondition, or construct a cubit with a known grid state directly by mocking/injecting the generated result.

- **test/games/chromix/cubit/chromix_cubit_test.dart:547-575** -- Win detection test does not actually test winning.
  - Why: The test is named "emits won when grid matches target and is contiguous" but never drives the cubit to a won state. It does a single move and asserts `status == playing`. The actual `ChromixStatus.won` transition is never tested anywhere in the cubit test file.
  - Fix: Construct a nearly-complete grid (e.g., all cells filled except one, with distribution one short of target) and perform the final move to verify the transition to `ChromixStatus.won` and that `score` is computed. Alternatively, rename the test to reflect what it actually tests.

- **test/games/chromix/cubit/chromix_cubit_test.dart:577-587** -- Contiguity violation test is trivial.
  - Why: The `hasContiguityViolation` group contains only one test that checks the initial state is `false`. It never tests the case where a violation IS present or that it toggles back to `false` after an undo. The test name "recomputed after move and undo" does not match the test body.
  - Fix: Add a test that constructs a state where a color at its target count is non-contiguous, verifies `hasContiguityViolation` is true, then performs an undo or correction and verifies it toggles back to false.

- **lib/games/chromix/view/chromix_page.dart** -- No page-level widget test.
  - Why: `ChromixPage` orchestrates 5 BlocProviders, win celebration, result overlay toggling, streak persistence, instructions dialog, and debug shuffle. This is the integration point for the entire Chromix feature with zero test coverage. While the individual widgets have tests, the page-level wiring is untested.
  - Fix: Add `test/games/chromix/view/chromix_page_test.dart` covering at minimum: renders loading state, renders grid after loading, shows contiguity violation message, undo button disabled when history empty, results overlay appears on win.

- **lib/games/chromix/cubit/chromix_cubit.dart:59** -- Bare `on Object` catch without explanation.
  - Why: Catching `Object` is extremely broad and can swallow programming errors (assertion errors, type errors). The CLAUDE.md notes the only pre-existing `avoid_catching_errors` hint is in the identity cubit (which is intentional). This catch silently clears the session and falls through to generate a new puzzle, which could mask real deserialization bugs during development.
  - Fix: Narrow the catch to specific expected types (e.g., `on FormatException` or `on TypeError`), or add an explicit comment explaining why `Object` is necessary and add the appropriate lint ignore annotation.

- **lib/games/chromix/view/widgets/chromix_grid.dart:6** -- Direct import of `chromix_cell_widget.dart` instead of barrel.
  - Why: Convention is to import via barrel files. The grid widget imports `chromix_cell_widget.dart` directly rather than through the `widgets.dart` barrel.
  - Fix: Change to `import 'package:very_good_games/games/chromix/view/widgets/widgets.dart';` or accept this as an intra-directory import (depending on team convention for sibling files).

### Suggestions -- Nice to Have

- **lib/games/chromix/view/widgets/color_bar.dart:97-104 and chromix_cell_widget.dart:98-105** -- Duplicated `_colorFor` mapping.
  - Suggestion: Both files contain identical `ChromixColor -> Color` switch statements. Extract a shared `ChromixColor` extension method or a utility function in the theme package to avoid maintaining two identical mappings.

- **lib/games/chromix/cubit/chromix_cubit.dart:45** -- `await Future<void>.delayed(Duration.zero)` as initialization pattern.
  - Suggestion: Using `Future.delayed(Duration.zero)` to defer initialization works but makes the code harder to reason about. Consider documenting why this pattern is necessary (presumably to let the constructor complete before emitting via `compute`), or using a factory method that returns `Future<ChromixCubit>`.

- **lib/games/chromix/cubit/chromix_cubit.dart:300** -- `List<MoveRecord>.of(state.moveHistory)` for undo creates mutable copy.
  - Suggestion: This creates a mutable copy just to call `removeLast()`. Consider `state.moveHistory.sublist(0, state.moveHistory.length - 1)` and `state.moveHistory.last` to keep everything immutable.

- **lib/games/chromix/logic/puzzle_generator.dart:423-436** -- Last-resort fallback generates a trivial all-red puzzle.
  - Suggestion: Good defensive programming. Consider logging when the fallback is hit so it can be investigated -- a trivial puzzle is a bad user experience.

- **lib/games/chromix/cubit/chromix_state.dart:33-44** -- `ChromixState.loading()` allocates a new grid every time.
  - Suggestion: The loading factory constructor creates `List.filled(16, const EmptyCell())` on every call. Consider a `static final` constant for the loading grid.

- **test/games/chromix/cubit/chromix_cubit_test.dart:697-718** -- `_RealStorageHelper` uses `noSuchMethod` fallback.
  - Suggestion: This partial implementation silently returns null for any unimplemented method via `noSuchMethod`. If `GameStorageRepository` adds a new method that `ChromixCubit` calls, the test will silently do nothing instead of failing. Consider implementing all required methods explicitly.

- **lib/games/chromix/view/chromix_page.dart:191-202** -- Nested `BlocBuilder` inside `BlocConsumer` builder.
  - Suggestion: There is a `BlocBuilder<ChromixCubit, ChromixState>` nested inside the `BlocConsumer<ChromixCubit, ChromixState>` builder for the "Current" color bar. The outer builder already provides the state. Consider using `buildWhen` on the outer `BlocConsumer` or selecting only what the Current bar needs via `BlocSelector` to avoid the nesting.

### Simplicity Assessment
- Lines that could be removed: ~80 (duplicated BFS in cubit could be replaced with calls to `contiguity_checker.dart`)
- Unnecessary abstractions: None identified -- the layer separation is appropriate for the feature's complexity.
- YAGNI violations: None -- the contiguity checker, drag interaction, overpower timer, and win celebration are all required by the feature spec.
- Complexity verdict: Minor tweaks needed -- the main simplification is deduplicating the three copies of BFS contiguity logic into the logic layer.

### Testing Assessment
- New code with tests: Partial -- Missing for: `WinCelebration` widget (shared, new), `ChromixPage` (page-level integration), win state transition in cubit, contiguity violation positive case.
- Test quality: Mostly meaningful -- logic tests (contiguity checker, puzzle generator, puzzle solver) are thorough with good edge cases. Cubit tests cover key interactions but have silent-skip guards that could mask regressions, and the win detection test does not actually test winning.
- State management test coverage: Partial -- drag, undo, persistence, and overpower are well-tested. Win transition and contiguity violation toggle are undertested.
- UI component test coverage: Partial -- cell widget, grid, instructions dialog, and color bar are tested. Page-level integration is missing. Results overlay has a separate test file (not in diff but exists).
