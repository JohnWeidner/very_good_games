# Code Simplicity Review

**Branch**: `plan/guess-the-number`
**Date**: 2026-04-02
**Scope**: All files changed from `main` plus uncommitted game module (`lib/games/guess_the_number/`, `test/games/guess_the_number/`)
**Total LOC**: ~3,107 (lib) + ~1,792 (test) = ~4,899

---

## Simplification Analysis

### Core Purpose

Build a daily "Guess the Number" puzzle game as the first game module in a Flutter hub app. The game presents a 20x20 grid of 400 numbers, lets the player ask strategic questions to eliminate candidates, and scores based on questions asked and time taken. It integrates with an existing game hub shell via `GameDefinition`, `DailySeed`, and streak tracking.

### Unnecessary Complexity Found

#### 1. [Important] Two-param question infrastructure is dead code

**Files**: `lib/games/guess_the_number/cubit/game_cubit.dart` (lines 106-153), `lib/games/guess_the_number/cubit/game_state.dart` (lines 64-69, 115-116, 138-140), `lib/games/guess_the_number/view/widgets/question_card.dart` (lines 155-201)

The plan originally called for 13 question types including `between (excl)` and `between (incl)` which require two parameters. The implementation was scoped down to 8 question types, none of which use two parameters. However, the full two-parameter infrastructure remains:

- `GameState.secondParam` field
- `GameState.editingParam` field
- `GameStatus.selectingSecondParam` enum value
- `lockParam()` branch for `selectingSecondParam`
- `lockParam()` branch for re-picking when `editingParam` is set
- `editParam()` method on the cubit
- `_twoParamInstruction` getter in `QuestionCard`
- The entire two-param `_ParamSlotRow` branch in `_buildParamArea`
- The "to" separator label rendering logic in `_ParamSlotRow`

The `QuestionType` test file (`test/games/guess_the_number/models/question_type_test.dart` line 41-43) explicitly asserts that no two-param types exist: `expect(twoParam, isEmpty)`. This confirms the feature is not needed today.

**Estimated LOC reduction**: ~60 lines in lib, ~10 in tests

---

#### 2. [Important] Duplicate `_colorForCategory` helper defined in two widgets

**Files**: `lib/games/guess_the_number/view/widgets/card_tray.dart` (lines 135-142), `lib/games/guess_the_number/view/widgets/question_card.dart` (lines 203-210)

The same static method mapping `QuestionCategory` to a `Color` is copy-pasted across two files. If the palette changes, both must be updated. This should either live on the `QuestionCategory` enum itself as an extension method or be extracted into a shared helper.

**Estimated LOC reduction**: ~8 lines (net, after extraction)

---

#### 3. [Important] Duplicate `_colorForState` helper defined in two painters

**Files**: `lib/games/guess_the_number/view/widgets/number_grid.dart` (lines 378-385 and lines 453-459)

`_ZoomLensPainter._colorForState` and `_GridPainter._colorForState` are identical switch expressions. Extract to a single top-level function or `CellState` extension.

**Estimated LOC reduction**: ~7 lines

---

#### 4. [Suggestion] `QuestionCategory` enum is only used for card coloring

**File**: `lib/games/guess_the_number/models/question_type.dart` (lines 1-14)

`QuestionCategory` adds an indirection layer. Each `QuestionType` has a `category` field, and the only consumers are the two `_colorForCategory` helpers. The color could be a property directly on `QuestionType` instead, removing the enum entirely. This is a minor simplification and a matter of style -- the current approach is reasonable if more category-based behavior is planned.

**Estimated LOC reduction**: ~15 lines

---

#### 5. [Suggestion] `GameState.copyWith` uses nullable-function pattern for 7 fields

**File**: `lib/games/guess_the_number/cubit/game_state.dart` (lines 107-147)

The `() => value` wrapper pattern for nullable fields (e.g., `activeQuestionType`, `highlightedCell`, `firstParam`, `secondParam`, `editingParam`, `score`, `lastResult`) is correct for distinguishing "set to null" from "keep current value." However, with 14 parameters total, the `copyWith` method is dense. Two of those nullable-function parameters (`secondParam`, `editingParam`) support the unused two-param feature and can be removed immediately. The remaining pattern is a known Dart idiom and is fine.

**Estimated LOC reduction**: ~6 lines (from removing secondParam and editingParam)

---

#### 6. [Suggestion] `_StarRating` score thresholds may be unreachable

**File**: `lib/games/guess_the_number/view/widgets/results_overlay.dart` (lines 162-163)

The `_StarRating` widget awards 3 stars for scores >= 800. However, `ScoreCalculator.startingBudget` is 600, meaning the maximum possible score is 600 (0 questions, 0 seconds) and a realistic best is 550 (1 question, 0 seconds). A score of 800 is impossible. This means every win shows exactly 2 stars (if score >= 500) or 1 star, and the 3-star tier is dead code.

This appears to be a leftover from the plan which originally specified a 1000-point budget (with a later suggestion to bump to 1050). The budget was reduced to 600 during implementation but the star thresholds were not adjusted.

**Impact**: Not a crash, but it is misleading -- players can never earn 3 stars. Thresholds should be recalibrated to the 600-point budget (e.g., 3 stars >= 450, 2 stars >= 300, 1 star for any completion).

---

#### 7. [Suggestion] Plan-vs-implementation drift: grid is 20x20 / 400, plan says 32x32 / 1024

**Files**: Plan doc (`docs/plan/2026-04-02-feat-guess-the-number-game-plan.md`), all game code

The plan specifies a 32x32 grid with 1024 numbers, but the implementation uses a 20x20 grid with 400 numbers. The scoring formula also changed from `1000 - 50q - 2s` to `600 - 50q - 2s`. The plan document should be updated to match what was actually built, or a note added explaining the deviation.

This is a documentation issue, not a code issue. Leaving the plan out of sync makes it confusing for anyone reading the plan before the code.

---

#### 8. [Suggestion] Duplicate time-formatting logic in `GameHeader` and `ResultsOverlay`

**Files**: `lib/games/guess_the_number/view/widgets/game_header.dart` (lines 18-20), `lib/games/guess_the_number/view/widgets/results_overlay.dart` (lines 17-19)

The `MM:SS` formatting code is duplicated. Could be a small helper function or extension on `int`. Low priority since it is only 3 lines each.

**Estimated LOC reduction**: ~3 lines

---

### Code to Remove

| Location | Reason | Est. LOC |
|---|---|---|
| `game_state.dart`: `secondParam`, `editingParam` fields + copyWith + props | Unused two-param support | ~20 |
| `game_cubit.dart`: `selectingSecondParam` handling in `lockParam()` | Unused two-param support | ~10 |
| `game_cubit.dart`: `editParam()` method | Unused two-param support | ~5 |
| `game_state.dart`: `GameStatus.selectingSecondParam` | Unused two-param support | ~2 |
| `question_card.dart`: two-param branch in `_buildParamArea` | Unused two-param support | ~25 |
| `question_card.dart`: `_twoParamInstruction` getter | Unused two-param support | ~8 |
| **Total removable** | | **~70** |

### Simplification Recommendations

#### 1. Remove two-param infrastructure (Most impactful)

- **Current**: Full two-parameter question flow is implemented across cubit state, cubit methods, and UI. Zero question types use it.
- **Proposed**: Remove `secondParam`, `editingParam`, `selectingSecondParam`, `editParam()`, and the two-param UI branch. If two-param questions are added later, re-implement at that time.
- **Impact**: ~70 LOC removed. Reduces `GameState` from 14 props to 12. Simplifies `lockParam()` from 3 branches to 1. Removes an entire UI code path that cannot be reached.

#### 2. Extract duplicate color helpers

- **Current**: `_colorForCategory` is duplicated in `card_tray.dart` and `question_card.dart`. `_colorForState` is duplicated in two painters in `number_grid.dart`.
- **Proposed**: Add a `color` getter to `QuestionCategory` (or an extension). Add a top-level `colorForCellState` function in the models or a shared file.
- **Impact**: ~15 LOC removed. Single source of truth for game colors.

#### 3. Fix star rating thresholds

- **Current**: 3-star threshold is 800, but max score is 600.
- **Proposed**: Recalibrate to 600-point scale. Suggested: 3 stars >= 450 (9+ questions budget remaining), 2 stars >= 250, 1 star for any win.
- **Impact**: 2 lines changed. Makes the star display meaningful.

### YAGNI Violations

#### 1. Two-parameter question support (Important)

No current `QuestionType` has `paramCount == 2`. The test suite explicitly asserts this. Yet the codebase contains a complete two-parameter flow: state fields, cubit methods, status enum values, and UI rendering paths. This is a textbook YAGNI violation -- building for a hypothetical future requirement that may never arrive.

**What to do instead**: Delete the two-param code. If `between` questions are added in a future PR, implement the support at that time. The code will be simpler and the implementation can be tailored to the actual requirements.

#### 2. `QuestionCategory` enum (Minor)

The category enum exists primarily to color-code cards. It is a reasonable lightweight abstraction but adds a layer of indirection that is not strictly necessary. If no other category-based behavior is planned (e.g., filtering, collapsing), the color could live directly on `QuestionType`. However, this is a stylistic preference and the current approach is clean enough to keep.

### What Is Done Well

- **Clean separation of concerns**: Logic layer (`QuestionEvaluator`, `PrimeChecker`, `ScoreCalculator`) is pure Dart with no Flutter dependency. This makes it trivially testable.
- **Cubit design**: `GameCubit` manages a complex state machine cleanly. The guard clauses at the top of each method (`if (state.status == GameStatus.won) return;`) are clear and consistent.
- **`CustomPaint` for the grid**: Using a single canvas draw pass for 400 cells is the right performance choice. The zoom lens overlay is a nice UX touch.
- **Test coverage**: Logic and cubit are well-tested with meaningful assertions. The test for `QuestionEvaluator` covers every question type.
- **GameDefinition contract**: The abstraction is earned -- it enables the hub shell to discover and display games without knowing their internals.
- **Barrel files**: Consistent use of barrel exports keeps imports clean.
- **DailySeed with deterministic hash**: Pinned regression test (`expect(seed, equals(134668363))`) catches accidental algorithm changes.

### Final Assessment

**Total potential LOC reduction**: ~70 lines (~2.3% of lib code)
**Complexity score**: Low
**Recommended action**: Remove two-param dead code and fix star thresholds; the rest is already quite clean.

The codebase is well-structured and appropriately minimal for its scope. The main actionable finding is the two-parameter question infrastructure that was built ahead of need. The unreachable 3-star threshold is a minor bug worth fixing. Beyond those, the code is lean, well-tested, and follows good Flutter/bloc patterns.
