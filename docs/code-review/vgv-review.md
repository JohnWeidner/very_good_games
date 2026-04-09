## VGV Code Review -- Cascade Ball-Routing Puzzle

### Summary

The Cascade ball-routing puzzle is a well-structured new game module that follows VGV conventions closely. The architecture mirrors existing games (Chromix, Signal) with proper layer separation (models, logic, cubit, view, theme), correct barrel files, immutable state via Equatable, and consistent use of shared infrastructure (GameDefinition, GameStorageRepository, Nostr sharing widgets, WinCelebration). The pure logic layer (BallSimulator, PuzzleGenerator, ScoreCalculator) is cleanly separated from presentation, and the cubit manages state transitions correctly. All 62 tests pass and static analysis reports zero issues.

The code needs a few fixes before merge -- primarily around a deleted test from an unrelated game, a potential use-after-dispose race in the animation controller, and missing test coverage for key widgets. No architectural rethink is needed. **Verdict: needs minor work before merge.**

---

### Critical -- Must Fix Before Merge

- **test/games/chromix/view/widgets/color_palette_test.dart (deleted)** -- Unrelated test file removed
  - Why: The git diff shows this 61-line test file was deleted. It tested the Chromix game's `ColorPalette` widget. This deletion is not part of the Cascade feature. The `color_palette.dart` source file also no longer exists (confirmed via glob), and the deletion likely happened in an earlier commit on this branch (`dee6eef changes for chromix game`). If the ColorPalette widget was intentionally removed or refactored as part of changes on this branch, the test deletion is correct. However, if the widget still exists in any form, this represents lost test coverage.
  - Fix: Verify the Chromix ColorPalette widget was deliberately removed in commit `dee6eef`. If the widget was renamed/refactored, confirm the replacement has equivalent test coverage. If it was accidentally deleted, restore with `git checkout main -- test/games/chromix/view/widgets/color_palette_test.dart`.

- **lib/games/cascade/view/widgets/cascade_board_widget.dart:84-88** -- Animation status listener may fire after widget disposal
  - Why: The `addStatusListener` callback at line 84 calls `context.read<CascadeCubit>().completeDrop()` when the animation completes. However, this callback has no `mounted` guard. If the user navigates away during the drop animation, `dispose()` is called which disposes the controller, but there is a race condition: if the animation completes in the same frame that disposal is triggered, the status listener may still fire on a disposed widget's context. The `addListener` callback at line 61 correctly checks `if (!mounted) return;`, but this pattern is missing from the status listener.
  - Fix: Add a `mounted` guard:
    ```dart
    _dropController!.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        context.read<CascadeCubit>().completeDrop();
      }
    });
    ```

---

### Important -- Should Fix

- **Missing test: `test/games/cascade/view/widgets/cascade_board_widget_test.dart`** -- No test for the most complex widget
  - Why: `CascadeBoardWidget` at 553 lines is the largest and most complex widget in the Cascade game. It handles animation, drag targets, lever rendering, ball interpolation, and multiple game states. Other games have tests for their main grid widgets (e.g., `chromix_grid_test.dart`, `signal_grid_test.dart`). This widget has zero test coverage.
  - Fix: Add a `cascade_board_widget_test.dart` with tests for: rendering levers in configuring state, rendering bins with expected ball labels, rendering drop slots with assigned balls, rendering landed balls after a won/failed state. Use a `MockCascadeCubit` to control the state.

- **Missing test: `test/games/cascade/view/widgets/cascade_results_overlay_test.dart`** -- No test for results overlay
  - Why: Other games have results overlay tests (e.g., `chromix_results_overlay_test.dart`, `signal_results_overlay_test.dart`). The Cascade results overlay renders score, attempts, stars, share button, community stats, and leaderboard. It has no test coverage.
  - Fix: Add a `cascade_results_overlay_test.dart` mirroring the pattern in `chromix_results_overlay_test.dart`. Mock `ResultSharingCubit`, `CommunityStatsCubit`, and `LeaderboardCubit`. Verify it renders score text, attempt count, star rating, and share button.

- **Missing test: `test/games/cascade/view/widgets/ball_tray_test.dart`** -- No test for ball tray drag interaction
  - Why: The `BallTray` widget handles drag-and-drop ball assignment with conditional rendering based on the `enabled` flag. It filters unassigned balls from the display. No test exists for this widget.
  - Fix: Add a `ball_tray_test.dart` that verifies: unassigned balls are rendered, balls are wrapped in `Draggable` when enabled, balls are not draggable when disabled.

- **Missing test: `test/games/cascade/cascade_game_test.dart`** -- No test for game definition
  - Why: The Signal game has a `signal_game_test.dart`. The `CascadeGame` class has specific values for `id`, `name`, `description`, `routePath` that should be verified.
  - Fix: Add a test that verifies `id == 'cascade'`, `name == 'Cascade'`, `routePath == '/games/cascade'`, and `routes` is not empty.

- **lib/games/cascade/cubit/cascade_cubit.dart:182** -- `cast<BallId>()` is a runtime type assertion that could crash
  - Why: At line 182, `state.slotAssignments.cast<BallId>()` performs a runtime cast on a `List<BallId?>`. The `allBallsAssigned` check on line 176 guards this, but `cast<BallId>()` will throw a `TypeError` at runtime if any element is null. If a future refactor changes the guard logic or reorders the checks, this becomes a crash. A safer approach makes the type assertion explicit.
  - Fix: Replace with:
    ```dart
    final assignments = state.slotAssignments.whereType<BallId>().toList();
    ```

- **lib/games/cascade/cubit/cascade_cubit.dart:63-64** -- `on Object` catch is too broad
  - Why: The `on Object` catch block catches every possible exception and error during deserialization. While the comment explains the intent (corrupted data), catching `Object` could mask programming errors during development (e.g., a typo in a key name silently falls through). The CLAUDE.md notes only one pre-existing `avoid_catching_errors` hint for a `StateError` catch in the identity cubit.
  - Fix: Narrow the catch or add debug logging:
    ```dart
    on Object catch (e) {
      debugPrint('Cascade session restore failed: $e');
      unawaited(
        storage.saveSession('$_storagePrefix$dateKey', null),
      );
    }
    ```

- **lib/games/cascade/cubit/cascade_cubit.dart:259-304** -- `_deserializeState` nullable return type is misleading
  - Why: The method returns `CascadeState?` and the caller checks `if (restoredState != null)`. But the method body never returns `null` -- it always constructs and returns a `CascadeState`. If deserialization fails, it throws (caught by the `on Object` handler). The nullable return type suggests a soft failure mode that does not exist.
  - Fix: Change return type to `CascadeState` (non-nullable) and remove the null check at the call site.

- **lib/games/cascade/models/cascade_board.dart:2 and drop_result.dart:2** -- Direct file imports instead of barrel file
  - Why: `cascade_board.dart` imports `lever.dart` directly and `drop_result.dart` imports `ball.dart` directly, rather than using the `models.dart` barrel file. VGV convention per CLAUDE.md is to "use barrel files" for imports.
  - Fix: Change both to `import 'package:very_good_games/games/cascade/models/models.dart';`. Since barrel files in this project are simple re-exports without circular dependency risk, this should work directly.

---

### Suggestions -- Nice to Have

- **lib/games/cascade/view/widgets/cascade_board_widget.dart** -- Consider extracting the 553-line widget
  - Suggestion: The `CascadeBoardWidget` is 553 lines with 14 methods. While the methods are well-named and logically grouped, consider extracting the animation interpolation logic (`_interpolatedPosition`, `_landedXNudge`) into a pure utility class in the `logic/` layer. This would enable independent unit testing of the interpolation math without needing a widget test harness.

- **lib/games/cascade/cubit/cascade_cubit.dart:37-39** -- Mutable `_preDropBoard` and `_preDropSlots` fields
  - Suggestion: These mutable fields break the otherwise immutable state pattern. They store pre-drop snapshots needed for `reset()`. Consider moving them into `CascadeState` as optional fields so they survive serialization. Currently, if the app is backgrounded during `failed` status and the cubit is recreated from persisted state, these fields are null and `reset()` falls back to `state.board.resetLevers(state.initialLevers)` with default slot assignments instead of the user's pre-drop configuration.

- **lib/games/cascade/logic/puzzle_generator.dart:27-28** -- Fallback puzzle may not have a unique solution
  - Suggestion: The `bestFallback` might have multiple solutions, and `_generateFallback` at line 169 uses a hardcoded lever arrangement without verifying uniqueness. Consider logging when fallback is used so you can investigate seeds that fail to produce unique puzzles.

- **test/games/cascade/cubit/cascade_cubit_test.dart** -- Consider using `bloc_test` package
  - Suggestion: The cubit tests use raw `test()` blocks with manual cubit lifecycle management (`await cubit.close()`). The project convention per CLAUDE.md is `bloc_test` for cubits. Using `blocTest<CascadeCubit, CascadeState>()` would provide consistent patterns with the rest of the codebase and automatic cubit disposal.

- **lib/games/cascade/view/widgets/cascade_board_widget.dart:528-552** -- `_GridPainter` name is broader than its behavior
  - Suggestion: The `_GridPainter` only paints background colors for the top row (drop slots and edge columns). The name suggests it paints the entire grid. Consider renaming to `_DropSlotBackgroundPainter` for clarity.

- **lib/games/cascade/cubit/cascade_cubit.dart:223-228** -- `skipAnimation` method is a trivial wrapper
  - Suggestion: `skipAnimation()` just calls `completeDrop()`. While it provides semantic clarity at the call site, it is a one-line delegation. Consider whether the separate method is worth maintaining, or if `completeDrop()` could be called directly from the view's tap handler.

- **lib/games/cascade/view/widgets/ (multiple files)** -- Direct widget file imports within the widgets directory
  - Suggestion: `ball_tray.dart`, `bin_widget.dart`, and `cascade_board_widget.dart` import `ball_widget.dart` directly rather than through the `widgets.dart` barrel. The existing Chromix game follows the same pattern, so this appears to be an acceptable codebase convention for sibling widget imports. Low priority to change.

---

### Simplicity Assessment

- **Lines that could be removed**: ~5-10 (nullable return type path in `_deserializeState`, `skipAnimation` wrapper method)
- **Unnecessary abstractions**: None identified. The layer separation (models/logic/cubit/view) is justified and matches existing games.
- **YAGNI violations**: None significant. The wall-bounce animation, lever-impact animation, and pre-drop state snapshots all serve clear purposes.
- **Complexity verdict**: Already minimal. The architecture is right-sized for the feature. The main widget (`CascadeBoardWidget`) is large but its complexity is inherent to the animation requirements, not over-engineering.

---

### Testing Assessment

- **New code with tests**: Partial. Models (4 files), logic (3 files), and cubit (1 file) have good coverage. Missing tests for: `CascadeBoardWidget`, `CascadeResultsOverlay`, `BallTray`, `CascadeGame`, `CascadePage`.
- **Test quality**: Meaningful. Tests cover state transitions, edge cases (wall bounces, win detection, wrong assignments), value equality, serialization round-trips, determinism, and guard conditions (actions ignored in wrong status). The cubit test for `reset` properly verifies pre-drop state restoration.
- **State management test coverage**: Good. 11 cubit tests covering init, assignment, swap, unassign, flip, drop, completeDrop, reset, status guards, and persistence. Minor gap: session restoration from persisted state and explicit win-path verification (tests rely on generated puzzles which may not produce a win for the given seed).
- **UI component test coverage**: Partial. `BallWidget`, `BinWidget`, `LeverWidget`, and `CascadeInstructionsDialog` have tests. Missing: `CascadeBoardWidget`, `CascadeResultsOverlay`, `BallTray`, `CascadePage`.
- **Test count**: 12 test files with 62 passing tests. Comparable to Signal (11 files) and Chromix (15 files), but missing results overlay and game definition tests that other games have.
