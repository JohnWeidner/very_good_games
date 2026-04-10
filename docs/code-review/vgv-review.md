## VGV Code Review -- Cascade Ball-Routing Puzzle

### Summary

The Cascade ball-routing puzzle is a well-architected game module that closely follows VGV conventions. Layer separation is clean: pure logic in `logic/`, immutable Equatable models in `models/`, a Cubit with part-of state file in `cubit/`, and presentation in `view/`. The module integrates correctly with shared infrastructure (GameDefinition, GameStorageRepository, WinCelebration, Nostr sharing widgets, utcDateKey). Static analysis reports zero issues under `very_good_analysis` v7.0.0, and all 76 tests pass.

Previous review findings for the mounted guard on the animation status listener, the `cast<BallId>()` safety issue, and the `_SlotBackgroundPainter` rename have all been addressed. The remaining concerns are concentrated in two areas: test coverage gaps for three key widgets and the `CascadeBoardWidget` at 739 lines, which combines animation physics, interpolation math, and rendering in a single file. No architectural rethink is needed. **Verdict: needs minor work before merge.**

---

### Critical -- Must Fix Before Merge

No critical issues found. The previous critical items (mounted guard race condition and deleted Chromix test) have been resolved.

---

### Important -- Should Fix

- **Missing test: `test/games/cascade/view/widgets/cascade_board_widget_test.dart`** -- No test for the most complex widget (739 lines)
  - Why: `CascadeBoardWidget` is the most complex widget in the entire Cascade game. It handles drop animation orchestration, drag target slots, lever rendering across multiple game states, ball path interpolation with gravity easing, wall bounces, bin bounces, and landed ball positioning. At 739 lines with 16+ methods, this is the widget most likely to regress. Other games in this repo have grid widget tests. Zero test coverage on this widget is a significant gap.
  - Fix: Add `cascade_board_widget_test.dart` with a `MockCascadeCubit` (using `mocktail`). Key tests: (1) renders levers in configuring state, (2) renders drop slots with assigned balls, (3) renders bins with expected ball labels from binOrder, (4) renders landed balls in won/failed state, (5) starts animation when status transitions to dropping. This does not need to test the animation math -- that can be tested separately if extracted.

- **Missing test: `test/games/cascade/view/widgets/cascade_results_overlay_test.dart`** -- No test for results overlay
  - Why: The other games in this repo (Chromix, Signal) all have results overlay tests. This overlay renders score, attempts, stars, the share button, community stats, and the leaderboard section. It also calls `EventBuilder.buildCascadeResult` on share. Without tests, regressions in scoring display or share integration would go unnoticed.
  - Fix: Add `cascade_results_overlay_test.dart` following the pattern in `chromix_results_overlay_test.dart`. Mock `ResultSharingCubit`, `CommunityStatsCubit`, `LeaderboardCubit`, and `ProfileCubit`. Verify it renders score text, attempt count, star rating, share button, and the "Back to Hub" / "View Puzzle" buttons.

- **Missing test: `test/games/cascade/view/cascade_page_test.dart`** -- No integration test for the page
  - Why: `CascadePage` is the top-level page that wires together MultiBlocProvider with 5 cubits. It contains the `_CascadeView` stateful widget with instruction-showing logic, streak persistence, community stats fetching, and win celebration orchestration. No test verifies that these dependencies are wired correctly or that the page renders without errors when given a valid seed.
  - Fix: Add a `cascade_page_test.dart` that pumps `CascadePage` within a `RepositoryProvider` context providing mocked dependencies. Verify it renders the loading indicator initially and transitions to the board after initialization.

- **lib/games/cascade/view/widgets/cascade_board_widget.dart** -- 739-line god widget combining animation physics, interpolation, and rendering
  - Why: This single file contains: (1) drop animation orchestration with binary search for ball start times, (2) gravity easing with velocity halving at lever impacts, (3) quadratic solver for physics timing, (4) ball path interpolation with wall bounces, bin bounces, and deflection arcs, (5) lever direction computation during animation, (6) all rendering methods for grid, slots, levers, bins, animated balls, and landed balls, (7) a custom painter. This exceeds the 500-line guideline for a single widget and mixes pure math with UI rendering.
  - Fix: Extract the animation interpolation logic into a pure utility class in `logic/` (e.g., `ball_path_interpolator.dart`). This would contain `_interpolatedPosition`, `_gravityEase`, `_solveQuadraticTime`, `_landedXNudge`, and the ball start time calculation. These are pure functions that take data in and return coordinates -- they have no dependency on Flutter widgets. This extraction would: (a) reduce `CascadeBoardWidget` to ~400 lines, (b) enable direct unit testing of the interpolation math without a widget test harness, (c) separate concerns between "what to draw" and "where to draw it."

- **lib/games/cascade/cubit/cascade_cubit.dart:63-64** -- `on Object` catch is overly broad
  - Why: The deserialization error handler catches `Object`, which suppresses every possible exception and error. While the comment explains the intent (corrupted data fallback), this masks programming errors during development. If a key name changes in `_deserializeState`, the typo would silently fall through rather than surfacing. The CLAUDE.md notes only one pre-existing `avoid_catching_errors` for a `StateError` in the identity cubit -- this is a second instance.
  - Fix: Either narrow the catch to expected failure types (`on FormatException` + `on TypeError` + `on RangeError`) or add debug logging so deserialization failures are visible during development:
    ```dart
    on Object catch (e) {
      assert(() {
        debugPrint('Cascade session restore failed: $e');
        return true;
      }());
      unawaited(
        storage.saveSession('$_storagePrefix$dateKey', null),
      );
    }
    ```

- **lib/games/cascade/cubit/cascade_cubit.dart:37-39** -- Mutable `_preDropBoard` and `_preDropSlots` fields lose data on app restart
  - Why: The pre-drop board and slot snapshots are stored as mutable instance fields on the cubit. They are used by `reset()` to restore the user's configuration after a failed drop. However, these fields are not persisted. If the app is backgrounded during the `failed` state and the cubit is recreated from the persisted session, both fields are `null`. The `reset()` method falls back to `state.board.resetLevers(state.initialLevers)` and `defaultSlotAssignments`, discarding the user's lever flips and ball arrangement. This is a silent data loss bug.
  - Fix: Include `preDropLevers` and `preDropSlots` in the persisted session data, or move them into `CascadeState` as optional fields so they survive serialization.

- **lib/games/cascade/view/cascade_page.dart** -- Deep imports bypass barrel files
  - Why: The page imports 6 files from `nostr/` using deep paths (e.g., `nostr/sharing/cubit/result_sharing_cubit.dart`, `nostr/stats/cubit/community_stats_cubit.dart`, `nostr/stats/repository/community_stats_repository.dart`). Barrel files exist for both modules (`sharing/sharing.dart` and `stats/stats.dart`) that export all of these. The CLAUDE.md convention states: "use barrel files; never import across layer boundaries." This is consistent across all games in the repo (other games also use deep imports), but it is still a deviation from the stated convention.
  - Fix: Replace deep imports with barrel imports:
    ```dart
    import 'package:very_good_games/nostr/sharing/sharing.dart';
    import 'package:very_good_games/nostr/stats/stats.dart';
    ```
    Apply the same fix to `cascade_results_overlay.dart` which also uses deep imports.

- **test/games/cascade/cubit/cascade_cubit_test.dart** -- Uses raw `test()` blocks instead of `bloc_test`
  - Why: The project convention per CLAUDE.md is `bloc_test` for cubits. The cubit tests use raw `test()` blocks with manual lifecycle management (`await cubit.close()`). While the tests are well-written and thorough, they are inconsistent with the codebase convention. Using `blocTest<CascadeCubit, CascadeState>()` would provide automatic cubit disposal, declarative `act`/`expect`/`verify` blocks, and consistency with the test patterns used elsewhere in the project.
  - Fix: Migrate the cubit tests to use `blocTest`. The async initialization pattern (waiting for the cubit to leave loading state) can be handled with `setUp` and `seed` parameters.

---

### Suggestions -- Nice to Have

- **lib/games/cascade/logic/puzzle_generator.dart:27-28** -- Fallback puzzle may not have a unique solution
  - Suggestion: The `bestFallback` might have multiple solutions, and `_generateFallback` at line 175 uses a hardcoded lever arrangement without verifying uniqueness. This means some daily seeds could produce puzzles with more than one winning configuration. Consider adding an assertion or debug log when the fallback path is taken, so it can be monitored.

- **lib/games/cascade/cubit/cascade_cubit.dart:226-228** -- `_deserializeState` return type is `CascadeState?` but never returns null
  - Suggestion: The method body always constructs and returns a `CascadeState`. If deserialization fails, it throws (caught by the `on Object` handler above). The nullable return type suggests a soft failure mode that does not exist. Consider changing the return type to `CascadeState` (non-nullable) and removing the null check at the call site, or adding an explicit `return null` path for partial/incomplete data.

- **lib/games/cascade/cubit/cascade_cubit.dart:191-194** -- `skipAnimation` is a one-line delegation
  - Suggestion: `skipAnimation()` just calls `completeDrop()`. It exists for semantic clarity at the call site (the view calls `skipAnimation` when the user taps during the animation). This is fine as-is for readability, but be aware it adds a method to the public API surface that duplicates another. If the skip behavior ever needs to differ from complete (e.g., fast-forward animation rather than instant resolve), this separation will be valuable.

- **lib/games/cascade/view/widgets/cascade_board_widget.dart:131-196** -- `_gravityEase` method is complex and lacks unit test coverage
  - Suggestion: The gravity easing function at 65 lines is a physics simulation that computes piecewise quadratic motion with velocity halving at lever impacts. It involves binary search, boundary arrays, and a quadratic solver. This kind of pure math is ideal for direct unit testing. Even without extracting it to a separate class, consider testing it via a helper that instantiates the state and calls the method with known inputs, or extract it as a static function that takes its inputs as parameters.

- **lib/games/cascade/models/cascade_board.dart and drop_result.dart** -- Direct sibling imports instead of barrel file
  - Suggestion: `cascade_board.dart` imports `lever.dart` directly and `drop_result.dart` imports `ball.dart` directly, rather than using the `models.dart` barrel file. The CLAUDE.md convention says to use barrel files. This is low priority since these are intra-directory sibling imports and the pattern is common in the codebase, but converting them would be consistent with the stated convention.

- **lib/games/cascade/view/widgets/cascade_results_overlay.dart:79** -- `utcDateKey()` called at render time
  - Suggestion: Line 79 calls `utcDateKey()` inline within the build method for the `LeaderboardSection` dTag. This will produce a fresh date key each time the widget rebuilds. If the widget rebuilds after midnight UTC, the leaderboard dTag would change. Since the `dateKey` is already computed and passed through the `_CascadeView`, consider threading it into the overlay as a parameter instead of computing it fresh.

---

### Simplicity Assessment

- **Lines that could be removed**: ~5 (nullable return type path in `_deserializeState`, trivial `skipAnimation` delegation)
- **Unnecessary abstractions**: None identified. The layer separation (models/logic/cubit/view/theme) is justified and mirrors the pattern of existing games in the repo.
- **YAGNI violations**: None significant. The wall-bounce animation, lever-impact animation, bin bounces, and pre-drop state snapshots all serve the game's core user experience. No speculative extensibility points.
- **Complexity verdict**: Minor tweaks needed. The `CascadeBoardWidget` at 739 lines is the primary complexity concern. The animation interpolation math (~200 lines) is pure computation that would benefit from extraction to the logic layer. The remaining code is right-sized for the feature.

---

### Testing Assessment

- **New code with tests**: Partial. Models (4 test files: ball, cascade_board, drop_result, lever), logic (3 test files: ball_simulator, puzzle_generator, score_calculator), cubit (1 test file), and game definition (1 test file) have good coverage. Missing tests for: `CascadeBoardWidget`, `CascadeResultsOverlay`, `CascadePage`.
- **Test quality**: Meaningful. The 76 tests cover state transitions, edge cases (wall bounces, sequential ball drops, win detection, wrong assignments), value equality, serialization round-trips, determinism verification across 20 seeds, guard conditions (actions ignored in wrong status), persistence, session restoration, corrupted session handling, and a brute-force win-path verification.
- **State management test coverage**: Good. 12 cubit tests covering: initial loading state, transition to configuring, ball assignment/swap, unassign, lever flip, drop guard (requires all assigned), drop transition, completeDrop on failure, completeDrop on win with score, reset to pre-drop state, status guards, session persistence, session restoration, corrupted session handling. One minor gap: restoring from a "won" status session is tested implicitly via the status mapping but not with an explicit assertion on score.
- **UI component test coverage**: Partial. Tested: `BallWidget` (2 tests), `BinWidget` (3 tests), `LeverWidget` (2 tests), `BallTray` (4 tests), `CascadeInstructionsDialog` (1 test), `CascadeGame` (6 tests). Missing: `CascadeBoardWidget` (0 tests -- most complex widget), `CascadeResultsOverlay` (0 tests), `CascadePage` (0 tests).
- **Test count**: 14 test files with 76 passing tests. The test-to-source ratio is solid for models and logic but gaps exist in the view layer where the most complex rendering and integration logic lives.
