# Test Quality Review

**Branch**: `plan/guess-the-number`
**Date**: 2026-04-02
**Reviewer**: Claude (automated)
**Stack**: Flutter, flutter_bloc, bloc_test, mocktail, very_good_analysis

---

## Coverage Summary

- **Test run**: Pass (121/121 tests green)
- **Test files**: 18 test files covering 18 of 25 testable source files
- **Missing test files**: 7 widget/view files have no corresponding tests

### Files With Tests (18/25)

| Source File | Test File | Status |
|---|---|---|
| `lib/app/app.dart` | `test/app/app_test.dart` | Covered |
| `lib/app/app_bloc_observer.dart` | `test/app/app_bloc_observer_test.dart` | Covered |
| `lib/app/routes/routes.dart` | `test/app/routes_test.dart` | Covered |
| `lib/core/daily_seed/daily_seed.dart` | `test/core/daily_seed/daily_seed_test.dart` | Covered |
| `lib/core/game_registry/game_registry.dart` | `test/core/game_registry/game_registry_test.dart` | Covered |
| `lib/core/storage/game_storage_repository.dart` | `test/core/storage/game_storage_repository_test.dart` | Covered |
| `lib/core/storage/streak_data.dart` | `test/core/storage/streak_data_test.dart` | Covered |
| `lib/core/theme/app_theme.dart` | `test/core/theme/app_theme_test.dart` | Covered |
| `lib/home/cubit/home_cubit.dart` | `test/home/cubit/home_cubit_test.dart` | Covered |
| `lib/home/view/home_page.dart` | `test/home/view/home_page_test.dart` | Covered |
| `lib/home/view/widgets/game_tile.dart` | `test/home/view/game_tile_test.dart` | Covered |
| `lib/games/guess_the_number/cubit/game_cubit.dart` | `test/games/guess_the_number/cubit/game_cubit_test.dart` | Covered |
| `lib/games/guess_the_number/guess_the_number_game.dart` | `test/games/guess_the_number/guess_the_number_game_test.dart` | Covered |
| `lib/games/guess_the_number/logic/prime_checker.dart` | `test/games/guess_the_number/logic/prime_checker_test.dart` | Covered |
| `lib/games/guess_the_number/logic/question_evaluator.dart` | `test/games/guess_the_number/logic/question_evaluator_test.dart` | Covered |
| `lib/games/guess_the_number/logic/score_calculator.dart` | `test/games/guess_the_number/logic/score_calculator_test.dart` | Covered |
| `lib/games/guess_the_number/models/cell_state.dart` | `test/games/guess_the_number/models/cell_state_test.dart` | Covered |
| `lib/games/guess_the_number/models/question_type.dart` | `test/games/guess_the_number/models/question_type_test.dart` | Covered |

### Missing Test Files (7)

| Source File | Issue |
|---|---|
| `lib/games/guess_the_number/view/game_page.dart` | No corresponding test -- contains BlocProvider creation, timer lifecycle, and widget composition |
| `lib/games/guess_the_number/view/widgets/card_tray.dart` | No corresponding test -- renders all 8 question type cards, used/available states |
| `lib/games/guess_the_number/view/widgets/digit_picker.dart` | No corresponding test -- interactive widget with selection state |
| `lib/games/guess_the_number/view/widgets/game_header.dart` | No corresponding test -- displays timer, question count, remaining cells |
| `lib/games/guess_the_number/view/widgets/number_grid.dart` | No corresponding test -- core game interaction widget |
| `lib/games/guess_the_number/view/widgets/question_card.dart` | No corresponding test -- complex staged card with param slots, digit picker |
| `lib/games/guess_the_number/view/widgets/results_overlay.dart` | No corresponding test -- win/loss overlay with score breakdown |
| `lib/games/guess_the_number/view/widgets/score_bar.dart` | No corresponding test -- score progress bar |

**Note**: `score_bar.dart` is listed as a separate missing file, bringing the true total of untested widget files to 8. However, one of the source files (`widgets.dart`) is a barrel export and does not need its own test, so the net missing count is 7 meaningful widget files.

---

## State Management Test Quality

### `test/home/cubit/home_cubit_test.dart` -- Pass

- Uses `bloc_test` with `blocTest<HomeCubit, HomeState>` correctly
- Tests initial state, loading/loaded/error emission sequences
- Uses `mocktail` for `GameDefinition` mock
- Includes `HomeState` value equality and `copyWith` tests
- Uses `setUp` with `SharedPreferences.setMockInitialValues` for clean isolation
- Good descriptive test names: "emits [loading, loaded] with game entries"

### `test/games/guess_the_number/cubit/game_cubit_test.dart` -- Pass (with suggestions)

- Comprehensive: 22 tests covering selectQuestion, cancelQuestion, highlightCell, lockParam, confirmQuestion, tick, post-win guards
- Proper use of `bloc_test` throughout
- Uses `seed` to set up non-initial states (good pattern)
- Tests boundary conditions: assert on out-of-range target, win detection, loss via tick, loss via question cost
- Uses `verify` callback for complex post-action assertions
- Injectable `Random` for shotgun determinism -- excellent testability design

**Suggestions**:
- The `onesDigitIs` test at line 328-345 uses `highlightCell(4)` (number 5) but `onesDigitIs` is a digit-picker question (uses `setDigitParam`), not a grid-picker. The test still passes because `lockParam` sets `firstParam` to 5 and the evaluator works with that value, but this does not exercise the intended user flow for digit-picker questions. A test using `setDigitParam(5)` would be more representative of real usage.
- No test for `editParam` method -- the re-pick flow for two-param questions or changing a locked param is untested.
- No test for `setDigitParam` -- the digit picker input path is untested at the cubit level.
- No test for `cancelQuestion` when no question is staged (early return guard).

---

## Repository / Service Test Quality

### `test/core/storage/game_storage_repository_test.dart` -- Pass

- Tests getStreak default return, stored data retrieval, saveStreak persistence
- Tests isolation between game IDs
- Tests null lastCompletedDate path
- Uses `SharedPreferences.setMockInitialValues({})` correctly

### `test/games/guess_the_number/guess_the_number_game_test.dart` -- Pass

- Tests all `GameDefinition` properties
- Tests `getDailyStatus` for no-data, matching-date, and different-day scenarios
- Uses real `SharedPreferences` mock -- appropriate for this integration-style test

---

## Data Model Test Quality

### `test/core/storage/streak_data_test.dart` -- Pass

- Value equality, defaults, `recordCompletion` covering: new streak, consecutive day, gap reset, best-streak update, idempotent same-day
- Well-structured with `group('recordCompletion', ...)`

### `test/games/guess_the_number/models/cell_state_test.dart` -- Pass (minor note)

- Only verifies enum has 4 values -- minimal but acceptable for a simple enum with no logic

### `test/games/guess_the_number/models/question_type_test.dart` -- Pass

- Tests count, repeatability, paramCount classification, label/description presence
- Good coverage of the enum's enhanced properties

---

## Logic / Pure Function Test Quality

### `test/core/daily_seed/daily_seed_test.dart` -- Pass

- Determinism, different-dates divergence, time-component ignoring, UTC conversion
- Includes a pinned regression value test (line 47-53) -- excellent for detecting algorithm drift

### `test/games/guess_the_number/logic/prime_checker_test.dart` -- Pass

- Tests 1 (not prime), 2 (prime), known primes across range, known composites
- Covers boundaries well

### `test/games/guess_the_number/logic/question_evaluator_test.dart` -- Pass

- Tests all 8 question types with meaningful assertions on elimination counts and answer text
- Shotgun tests use seed-scanning to force HIT and MISS scenarios
- Tests that already-eliminated cells are skipped
- Tests target is never eliminated by shotgun across 20 seeds

### `test/games/guess_the_number/logic/score_calculator_test.dart` -- Pass

- Tests perfect game, typical game, clamping, zero-input, time penalty delta, max-time boundary, max-questions boundary
- Derives expected values from the formula and verifies them -- good documentation-by-test

---

## UI Component Test Quality

### `test/app/app_test.dart` -- Pass

- Renders MaterialApp, verifies title text
- Uses real dependencies (not mocked) via SharedPreferences mock -- acceptable for a thin root widget

### `test/app/app_bloc_observer_test.dart` -- Pass

- Tests instantiation, onChange/onError do not throw
- Uses `_FakeBloc` -- appropriate

### `test/app/routes_test.dart` -- Pass (minor note)

- Verifies router creation and that game routes are included
- Does not verify navigation behavior (e.g., navigating to `/` renders HomePage) -- acceptable since navigation is integration-level

### `test/home/view/home_page_test.dart` -- Pass

- Uses `MockCubit<HomeState>` with `_HomeViewTestWrapper` to test the BlocBuilder logic without the provider-creating HomePage
- Tests all 4 states: initial, loading, error, loaded-empty, loaded-with-games
- Follows VGV pattern: mock the cubit, pump with BlocProvider.value

### `test/home/view/game_tile_test.dart` -- Pass

- Tests name, description, icon rendering
- Tests both not-started and completed status badge icons
- Tests streak display: plural, singular, hidden at zero
- Wraps in `MaterialApp` + `Scaffold` correctly

---

## Anti-Patterns Found

### 1. [Important] `game_cubit_test.dart:328` -- onesDigitIs test uses grid selection instead of digit picker

- **Issue**: The test for `onesDigitIs` uses `highlightCell(4)` + `lockParam()` to set the parameter. However, `onesDigitIs` has `usesDigitPicker: true` and the real UI calls `setDigitParam(digit)` instead. The test exercises a code path that real users cannot reach for this question type.
- **Fix**: Replace `highlightCell(4)` + `lockParam()` with `setDigitParam(5)` to test the actual user flow.

### 2. [Important] Missing tests for `setDigitParam` and `editParam` methods on GameCubit

- **Issue**: `GameCubit.setDigitParam()` and `GameCubit.editParam()` have no dedicated tests. These are distinct input paths that affect state transitions differently from the grid-based lockParam flow.
- **Fix**: Add blocTest cases for:
  - `setDigitParam` sets firstParam and transitions to readyToConfirm
  - `setDigitParam` is a no-op when no question is staged
  - `editParam` marks a param for re-editing
  - `editParam` is a no-op when not in readyToConfirm

### 3. [Suggestion] `cell_state_test.dart` -- Minimal enum test adds little value

- **Issue**: The only test checks `CellState.values.hasLength(4)` and contains all values. If a new value is added, the test fails on the count -- but adding a value is intentional, not a regression. This test verifies the enum definition, not behavior.
- **Fix**: Consider removing this file or replacing it with tests that verify behavior tied to CellState (e.g., the color mapping in grid painters, if those were extracted). Alternatively, keep as a lightweight smoke test but acknowledge its limited value.

### 4. [Suggestion] `game_registry_test.dart:74-79` -- DailyGameStatus enum test is low value

- **Issue**: Similar to CellState -- testing that an enum has the expected number of values provides minimal regression protection.
- **Fix**: Same as above -- keep if desired but recognize it as documentation, not regression protection.

---

## Missing Test Coverage -- Detailed

### Critical: No widget tests for any Guess the Number game UI

The entire `lib/games/guess_the_number/view/` directory (1 page + 7 widgets) has zero test coverage. This is the most significant gap. These widgets contain non-trivial rendering logic:

1. **`game_page.dart`** -- Creates `GameCubit`, starts/stops `Timer`, composes all sub-widgets. Should test:
   - BlocProvider creation with correct target number
   - Timer starts on mount, stops on win/loss
   - All sub-widgets are rendered in the correct layout

2. **`card_tray.dart`** -- Renders 8 question type cards. Should test:
   - All 8 cards are rendered
   - Used cards appear grayed out (opacity 0.35) and are not tappable
   - Tapping an available card calls onSelect with the correct QuestionType
   - Repeatable card (equals) shows infinity icon

3. **`digit_picker.dart`** -- Row of 0-9 buttons. Should test:
   - 10 digit buttons are rendered
   - Tapping calls onDigitSelected with correct digit
   - Selected digit is visually distinguished

4. **`question_card.dart`** -- Complex card with param slots. Should test:
   - Renders label and description for the active question type
   - Play button is disabled when canConfirm is false
   - Play button calls onConfirm
   - Cancel button calls onCancel
   - Digit picker appears for usesDigitPicker questions
   - Param slots show locked values

5. **`results_overlay.dart`** -- Win/loss overlay. Should test:
   - Win state shows "You found it!", score, star rating, breakdown rows
   - Loss state shows "Time's up!", score-reached-zero message
   - "Back to Hub" button navigates to "/"

6. **`game_header.dart`** -- Stats row. Should test:
   - Renders formatted time, question count, remaining count
   - Shows lastResult feedback when present
   - Hides lastResult when null

7. **`number_grid.dart`** -- Due to CustomPaint usage, golden/visual tests may be needed, but at minimum should test:
   - `NumberGrid.visualPosition` and `NumberGrid.dataIndex` static methods (pure logic, easily unit-testable)
   - Gesture callbacks (onCellHighlighted, onCellSelected) fire correctly

8. **`score_bar.dart`** -- Progress bar. Should test:
   - Renders current score text
   - Progress bar fraction is correct
   - Color changes at thresholds (green/yellow/red)

---

## Pattern Compliance

| Pattern | Status | Notes |
|---|---|---|
| bloc_test for cubits | Pass | Both HomeCubit and GameCubit use blocTest correctly |
| mocktail for mocks | Pass | All mocks use mocktail (MockCubit, Mock implements) |
| UI tests with MaterialApp wrapper | Pass | All widget tests wrap in MaterialApp |
| Seeded initial states | Pass | game_cubit_test uses seed() for non-initial states |
| setUp/tearDown | Pass | Shared setup in setUp, cubit.close() in tearDown |
| Group organization | Pass | All tests use group() for logical organization |
| MockCubit for UI tests | Pass | home_page_test uses MockCubit pattern correctly |

---

## Recommendations

1. **[Critical] Add widget tests for all 7 untested game widgets.** This is a hard requirement by VGV standards -- every UI component must have tests covering all rendered states. Start with `results_overlay.dart` and `question_card.dart` as they have the most user-facing logic. The `number_grid.dart` static methods (`visualPosition`, `dataIndex`) should be extracted into unit tests at minimum.

2. **[Important] Add tests for `setDigitParam` and `editParam` on GameCubit.** These are public API methods with distinct state transitions that are currently untested. The onesDigitIs flow in production uses `setDigitParam`, not `lockParam`, so there is a real gap in the interaction contract.

3. **[Important] Fix the `onesDigitIs` cubit test to use `setDigitParam` instead of grid selection.** The current test passes coincidentally but exercises an impossible user path for digit-picker questions.

4. **[Suggestion] Add `GameState.copyWith` tests.** The `copyWith` method uses nullable function wrappers (`int? Function()?`) which is a pattern prone to subtle bugs. Testing that `copyWith(activeQuestionType: () => null)` actually sets it to null (vs. preserving the old value) would catch regressions in the wrapper logic.

5. **[Suggestion] Extract `NumberGrid.visualPosition` and `NumberGrid.dataIndex` static method tests into their own test file.** These are pure functions that can be unit-tested without widget infrastructure.

---

## Verdict

**Needs work before merging.** The state management, logic, repository, and data model layers have strong, well-structured tests that follow VGV conventions. However, the complete absence of widget tests for the entire Guess the Number game UI (7 widgets, 0 tests) is a blocking gap. Two cubit methods (`setDigitParam`, `editParam`) also lack test coverage.

**Fix 3 issues before merging:**
1. Add widget tests for the 7 untested game view/widget files
2. Add cubit tests for `setDigitParam` and `editParam`
3. Fix the `onesDigitIs` test to use the correct input method
