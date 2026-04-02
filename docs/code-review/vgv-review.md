## VGV Code Review

### Summary

This PR adds the first game module -- Guess the Number -- to the Very Good Games hub. The implementation is well-structured with clean layer separation (models, logic, cubit, view), immutable state via Equatable, and solid unit test coverage for all business logic. The architecture properly follows the `GameDefinition` contract established by the hub shell. However, there are several issues that need attention before merge: the game does not persist completion to the streak system (so the hub tile never updates), there are no widget tests for any of the seven new view widgets, the plan document and implementation have notable divergences (grid size, scoring, question count), and there is dead code supporting two-parameter questions that no question type currently uses. The code is clean, passes analysis with zero issues, and all 121 tests pass. Overall assessment: **needs work** -- the critical streak integration gap and missing widget tests should be addressed before merging.

### Pass 1: Regressions & Breaking Changes

**Changed signatures**: The committed `main.dart` on this branch had an empty `GameRegistry(games: [])`. The uncommitted local change adds `GuessTheNumberGame` to the registry and imports it. This is the correct integration approach and does not break the existing hub shell tests.

**Deleted code**: No existing code was deleted. The original scaffold `MainApp` was already replaced by the hub shell commit.

**Test coverage**: All existing tests from the hub shell commit continue to pass (50 hub tests + 71 game tests = 121 total, all green).

**Dependencies**: No new packages were added. The game module uses only the existing dependencies (flutter_bloc, equatable, go_router, shared_preferences).

### Critical -- Must Fix Before Merge

**1. [lib/games/guess_the_number/cubit/game_cubit.dart:182-256] -- Game completion never persists to streak storage**

The `GameCubit.confirmQuestion()` method detects a win and sets `GameStatus.won`, but it never calls `GameStorageRepository.saveStreak()` to record the completion. This means:
- The home screen tile will always show "not started" even after winning.
- The streak counter never increments.
- The `getDailyStatus()` method on `GuessTheNumberGame` will always return `notStarted`.

This breaks the core integration contract between the game module and the hub shell.

- Why: The entire point of `GameDefinition.getDailyStatus()` and `StreakData` is to track completion across sessions. Without persisting the win, the hub tile, streak display, and daily status are all broken.
- Fix: Inject `GameStorageRepository` into `GameCubit` (or handle it at the `GamePage` level via a `BlocListener`). On win, call:
  ```dart
  final streak = storageRepository.getStreak('guess_the_number');
  final updated = streak.recordCompletion(DateTime.now().toUtc());
  await storageRepository.saveStreak('guess_the_number', updated);
  ```
  A `BlocListener` on `GamePage` that watches for `GameStatus.won` and persists the streak would keep the cubit free of repository dependencies, which is a reasonable pattern.

**2. [test/games/guess_the_number/view/] -- No widget tests for any game view component**

The plan document lists widget tests as a quality gate. Seven new widgets were added (`GamePage`, `NumberGrid`, `CardTray`, `DigitPicker`, `GameHeader`, `QuestionCard`, `ResultsOverlay`, `ScoreBar`) with zero widget tests. The test directory has no `view/` folder at all.

- Why: VGV standards require widget tests for all presentation components. These widgets contain non-trivial rendering logic (CustomPaint with 400 circles, overlay state, zoom lens, gesture handling). Without tests, regressions in the UI layer go undetected. The plan's quality gates explicitly require "All widgets have widget tests covering rendered states."
- Fix: Add widget tests for at minimum:
  - `GamePage` -- verifies cubit is provided, layout structure renders.
  - `CardTray` -- renders all question types, disables used ones, fires `onSelect`.
  - `ScoreBar` -- renders correct score, color changes at thresholds.
  - `ResultsOverlay` -- renders win vs. loss state, shows score breakdown.
  - `GameHeader` -- displays timer, question count, remaining count, last result.
  - `QuestionCard` -- renders param slots, confirm/cancel buttons, digit picker for `onesDigitIs`.

**3. [lib/games/guess_the_number/view/game_page.dart:19-20] -- Target number is computed in the build method, creating a new target on every rebuild**

```dart
Widget build(BuildContext context) {
  final seed = DailySeed.today();
  final target = (seed % 400) + 1;
```

`DailySeed.today()` calls `DateTime.now().toUtc()`. If the app is open at midnight UTC, the seed changes and `build()` would produce a different target. More practically, if `GamePage` is rebuilt (e.g., parent widget rebuilds, theme change, orientation change), `DailySeed.today()` is called again. While the result is deterministic for the same day, computing it inside `build` is fragile and violates the principle that `build` should be pure with respect to external state.

- Why: `build()` can be called multiple times. The `BlocProvider.create` callback only runs once, so the cubit gets the target from the first build, but this is relying on framework behavior rather than being explicit. If this widget were ever changed to not use `BlocProvider` (e.g., extracted differently), the target could change mid-game.
- Fix: Move seed computation to `main.dart` or the `GameDefinition`, and pass the target number through the route or as a constructor parameter:
  ```dart
  class GamePage extends StatelessWidget {
    const GamePage({required this.targetNumber, super.key});
    final int targetNumber;
    // ...
  }
  ```
  Then in `GuessTheNumberGame.routes`:
  ```dart
  GoRoute(
    path: routePath,
    builder: (context, state) {
      final seed = DailySeed.today();
      final target = (seed % 400) + 1;
      return GamePage(targetNumber: target);
    },
  ),
  ```
  This is still computed on navigation, but at least it is outside `build()` of the stateless widget.

### Important -- Should Fix

**4. [lib/games/guess_the_number/cubit/game_cubit.dart, game_state.dart] -- Dead code for two-parameter questions**

The cubit has full support for two-parameter questions:
- `GameStatus.selectingSecondParam` status enum value
- `secondParam` field in `GameState`
- `lockParam()` handles the `selectingSecondParam` branch (lines 125-131)
- `editParam()` method for re-editing param 1 or 2
- `_twoParamInstruction` getter in `QuestionCard`
- `_ParamSlotRow` renders "from"/"to" slots for two-param questions

However, no `QuestionType` currently has `paramCount == 2`. The `question_type_test.dart` explicitly verifies: `'no two-param types exist'`.

The plan originally included `between (excl)` and `between (incl)` as two-param questions, but they were cut from the implementation. The scaffolding for them remains.

- Why: YAGNI. This is dead code that adds complexity to `GameState`, `lockParam()`, and `QuestionCard` without being exercisable. It also cannot be tested meaningfully since no question type triggers it. If two-param questions are added later, the code can be written then -- it is not complex enough to justify keeping around.
- Fix: Remove `GameStatus.selectingSecondParam`, `secondParam`, `editingParam`, the second-param branch in `lockParam()`, `editParam()`, the two-param UI in `QuestionCard`, and the `_twoParamInstruction` getter. This simplifies the state machine significantly.

**5. [lib/games/guess_the_number/view/widgets/question_card.dart:39] -- Force-unwrap of `activeQuestionType` without null guard**

```dart
final type = state.activeQuestionType!;
```

`QuestionCard` is only shown when `isSelecting` is true, so `activeQuestionType` should never be null in practice. However, the `!` operator is a crash risk if the widget is ever rendered in an unexpected state. The build method directly force-unwraps without any safety check.

- Why: VGV enforces explicit null handling. A force-unwrap with no comment or assertion is a potential crash.
- Fix: Either add an `assert` with a descriptive message, or use an early return:
  ```dart
  final type = state.activeQuestionType;
  if (type == null) return const SizedBox.shrink();
  ```

**6. [lib/games/guess_the_number/view/widgets/card_tray.dart:135, question_card.dart:203] -- Duplicated `_colorForCategory` method**

The `_colorForCategory` static method is defined identically in both `_TrayCard` (card_tray.dart:135) and `QuestionCard` (question_card.dart:203). Both map `QuestionCategory` to the same four color values.

- Why: Duplicated logic that will diverge when one is updated and the other is forgotten.
- Fix: Extract to a shared location, either as a method on `QuestionCategory` via an extension, or as a utility in the models/widgets barrel:
  ```dart
  extension QuestionCategoryColor on QuestionCategory {
    Color get color => switch (this) {
      QuestionCategory.comparison => const Color(0xFF1565C0),
      QuestionCategory.math => const Color(0xFF7B1FA2),
      QuestionCategory.guess => const Color(0xFFE65100),
      QuestionCategory.special => const Color(0xFFC62828),
    };
  }
  ```

**7. [lib/games/guess_the_number/view/widgets/number_grid.dart:378, number_grid.dart:453] -- Duplicated `_colorForState` method**

Same issue: `_ZoomLensPainter._colorForState` and `_GridPainter._colorForState` are identical implementations mapping `CellState` to `Color`. Both are private to their respective painters.

- Why: Same four colors, same mapping, defined twice in the same file. Will diverge.
- Fix: Extract to a top-level private function or a `CellState` extension in this file:
  ```dart
  Color _colorForCellState(CellState state) => switch (state) { ... };
  ```

**8. [lib/games/guess_the_number/view/widgets/number_grid.dart] -- Hardcoded colors throughout all painters**

Colors like `Color(0xFF4CAF50)`, `Color(0xFFBDBDBD)`, `Color(0xFFE53935)`, `Color(0xFFFFD600)`, `Color(0xFF1565C0)` are hardcoded in multiple places across `_GridPainter`, `_ZoomLensPainter`, `_RowLabelPainter`, `QuestionCard`, `CardTray`, `ScoreBar`, and `ResultsOverlay`. None of these use the app's `ThemeData` or `ColorScheme`.

- Why: Hardcoded colors bypass the theme system, making it impossible to support dark mode or theme changes. They also make the color palette hard to maintain -- the same green (`0xFF4CAF50`) appears in at least four places.
- Fix: At minimum, define game-specific color constants in a single location (e.g., `lib/games/guess_the_number/theme/game_colors.dart`). Ideally, derive them from the `ColorScheme` via a `ThemeExtension`. This is not blocking but should be addressed before adding dark mode support.

**9. [lib/games/guess_the_number/cubit/game_cubit.dart:335-337 (onesDigitIs test)] -- Test uses grid cell selection for a digit-picker question type**

The cubit test for `onesDigitIs` uses `highlightCell(4)` and `lockParam()` to set the parameter to the number 5 (cell index 4 = number 5). But `onesDigitIs` has `usesDigitPicker: true`, meaning the UI uses `DigitPicker` and calls `setDigitParam(digit)` instead of the grid selection flow. The parameter should be a raw digit (0-9), not a grid cell number.

In the test, the intent is to ask "ends in 5?" but the mechanism is wrong -- it goes through the grid path rather than the digit-picker path. The test still passes because `firstParam` ends up as `5` either way, but it tests the wrong interaction path.

- Why: The test does not match how the UI actually uses this question type. If `lockParam` behavior changes for digit-picker questions, this test would still pass even though the real flow is broken.
- Fix: Use `setDigitParam` in the test:
  ```dart
  cubit
    ..selectQuestion(QuestionType.onesDigitIs)
    ..setDigitParam(5)
    ..confirmQuestion();
  ```

**10. [docs/plan/2026-04-02-feat-guess-the-number-game-plan.md] -- Plan document is stale and diverges significantly from implementation**

The plan specifies:
- 32x32 grid (1024 cells) -- implementation uses 20x20 (400 cells)
- Scoring: `max(0, 1000 - ...)` -- implementation uses `max(0, 600 - ...)`
- 13 question types -- implementation has 8
- `GameStateData` with JSON serialization -- not implemented (no session persistence)
- `between (excl)` and `between (incl)` -- not implemented
- `<= N`, `> N`, `>= N`, `is even` -- not implemented
- Session save/restore -- not implemented
- `shotgun` eliminates 20 -- implementation eliminates 50
- `hand grenade` excludes target -- implementation correctly excludes target

The uncommitted changes to this file are not visible in the diff, but the plan as committed does not match the shipped code.

- Why: Stale documentation misleads future developers and makes it unclear what was intentionally descoped vs. accidentally missed.
- Fix: Update the plan to reflect the actual implementation (20x20 grid, 400 cells, 8 question types, 600-point budget, no session persistence). Mark descoped items explicitly.

### Suggestions -- Nice to Have

**11. [lib/games/guess_the_number/view/game_page.dart:42-44] -- Timer starts immediately, even before the first question**

The `Timer.periodic` starts in `initState`, but `GameCubit.tick()` is a no-op until `timerStarted` is true (set after the first question). This means the timer fires every second for the entire session, even when it has no effect.

- Suggestion: Start the timer lazily via a `BlocListener` that watches for `timerStarted` transitioning to `true`, or use a `Ticker` from `SingleTickerProviderStateMixin` for more idiomatic Flutter animation-style timing.

**12. [lib/games/guess_the_number/view/widgets/number_grid.dart:52-67] -- Static utility methods on `NumberGrid` widget**

`NumberGrid.visualPosition()` and `NumberGrid.dataIndex()` are coordinate conversion utilities that are used by both the widget and the zoom lens painter. They are static methods on a `StatefulWidget`, which is an unusual location for utility logic.

- Suggestion: Extract to a separate `GridLayout` utility class or make them top-level functions in the file. This improves discoverability and allows the painters to use them without depending on the widget class.

**13. [lib/games/guess_the_number/view/widgets/number_grid.dart:209-222] -- Overlay entry management could leak**

The `_showLens` method creates and inserts an `OverlayEntry` on every touch move. While `_removeLens` is called first, rapid touch events could theoretically race. The overlay is also not automatically removed if the widget is removed from the tree mid-drag (though `dispose` handles this).

- Suggestion: Consider using `OverlayPortal` (Flutter 3.10+) instead of manual `OverlayEntry` management. It is declarative and automatically handles lifecycle.

**14. [lib/games/guess_the_number/logic/question_evaluator.dart:47-48] -- Force-unwrap of `param1!` in closures**

Several question type handlers use `param1!` inside closures (e.g., `test: (n) => n < param1!`). If `apply()` is ever called without the required parameter, this crashes at runtime.

- Suggestion: Add validation at the top of `apply()`:
  ```dart
  assert(
    type.paramCount == 0 || param1 != null,
    '$type requires param1',
  );
  ```

**15. [lib/games/guess_the_number/view/widgets/results_overlay.dart:162-167] -- Star rating thresholds exceed maximum possible score**

The `_StarRating` widget awards 3 stars for score >= 800, but with a 600-point starting budget, the maximum possible score is 550 (1 question, 0 seconds). Three stars are unreachable.

- Suggestion: Adjust thresholds to match the 600-point budget. For example: 3 stars >= 400, 2 stars >= 250, 1 star for any completion.

**16. [lib/games/guess_the_number/cubit/game_state.dart:107-147] -- copyWith uses nullable function wrappers for nullable fields**

The `copyWith` pattern uses `int? Function()? firstParam` to distinguish between "not provided" and "set to null." This is a well-known Dart pattern for nullable copyWith fields, but it is verbose and non-obvious to readers unfamiliar with it.

- Suggestion: Consider adding a brief doc comment on the `copyWith` method explaining the pattern, or use a sentinel value approach. This is a minor readability concern -- the pattern is correct and widely used.

### Simplicity Assessment

- **Lines that could be removed**: Approximately 80-100 lines related to two-parameter question support (`selectingSecondParam`, `secondParam`, `editingParam`, two-param UI in `QuestionCard`, `editParam()` method).
- **Unnecessary abstractions**: None. The layer separation (models/logic/cubit/view) is appropriate for the complexity.
- **YAGNI violations**: Two-parameter question scaffolding (no question type uses it). Session persistence infrastructure mentioned in the plan but not implemented (this is fine -- it was descoped, just needs documentation).
- **Complexity verdict**: Minor tweaks needed. The core architecture is right-sized. Removing the two-param dead code would meaningfully simplify the state machine.

### Testing Assessment

- **New code with tests**: Partial. Logic layer (PrimeChecker, QuestionEvaluator, ScoreCalculator) and cubit (GameCubit) have thorough tests. Models (CellState, QuestionType) have metadata tests. GameDefinition integration (GuessTheNumberGame) has tests. Missing: all widget/view tests.
- **Test quality**: Meaningful. Tests cover happy paths, edge cases (out-of-range targets, already-eliminated cells), failure states (loss via time, loss via question cost), and behavioral invariants (target never eliminated, repeatable vs. non-repeatable). The `bloc_test` usage follows VGV conventions with proper `seed`, `act`, `expect`, and `verify` patterns.
- **State management test coverage**: Complete for the cubit. All status transitions, guard conditions (post-win, post-loss), and game mechanics are tested. 27 cubit tests covering selectQuestion, cancelQuestion, highlightCell, lockParam, confirmQuestion, tick, and post-win guards.
- **UI component test coverage**: Missing entirely. Zero widget tests for 7+ new widgets containing non-trivial rendering logic (CustomPaint, OverlayEntry, GestureDetector, Dismissible).
