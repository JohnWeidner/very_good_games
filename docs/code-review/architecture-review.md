# Architecture Review: Guess the Number Game

**Branch**: `plan/guess-the-number`
**Date**: 2026-04-02
**Reviewer**: Architecture Review Agent
**Scope**: All files changed from `main` plus uncommitted/untracked files

---

## Architecture Review

### Layer Separation

**Layers identified**:
- **Core** (`lib/core/`): Shared infrastructure — daily seed, game registry, storage, theme
- **Home** (`lib/home/`): Presentation layer for the hub screen (cubit + views)
- **Games** (`lib/games/guess_the_number/`): Self-contained game module with cubit, logic, models, and views
- **App** (`lib/app/`): Application shell — routing, bloc observer, root widget

**Import scan results**:

| File | Imports | Status |
|------|---------|--------|
| `lib/main.dart` | `app/*`, `core/*`, `games/guess_the_number/guess_the_number_game.dart` | Clean |
| `lib/app/app.dart` | `core/*` | Clean |
| `lib/app/routes/routes.dart` | `core/*`, `home/view/home_page.dart` | Clean |
| `lib/home/cubit/home_cubit.dart` | `core/*` | Clean |
| `lib/home/view/home_page.dart` | `core/*`, `home/cubit/*`, `home/view/widgets/*` | Clean |
| `lib/home/view/widgets/game_tile.dart` | `core/*`, `home/cubit/*` | Clean |
| `lib/games/guess_the_number/guess_the_number_game.dart` | `core/*`, own `view/game_page.dart` | Clean |
| `lib/games/guess_the_number/cubit/game_cubit.dart` | own `logic/*`, own `models/*` | Clean |
| `lib/games/guess_the_number/view/game_page.dart` | `core/*`, own `cubit/*`, own `view/widgets/*` | Clean |
| `lib/games/guess_the_number/view/widgets/card_tray.dart` | own `models/*` | Clean |
| `lib/games/guess_the_number/view/widgets/digit_picker.dart` | (none beyond Flutter) | Clean |
| `lib/games/guess_the_number/view/widgets/game_header.dart` | own `cubit/*` | Clean |
| `lib/games/guess_the_number/view/widgets/number_grid.dart` | own `models/*` | Clean |
| `lib/games/guess_the_number/view/widgets/question_card.dart` | own `cubit/*`, own `models/*`, own `view/widgets/digit_picker.dart` | Clean |
| `lib/games/guess_the_number/view/widgets/results_overlay.dart` | own `cubit/*` | Clean |
| `lib/games/guess_the_number/view/widgets/score_bar.dart` | own `logic/*` | See [I-1] |
| `lib/games/guess_the_number/logic/question_evaluator.dart` | own `logic/prime_checker.dart`, own `models/*` | Clean |
| `lib/games/guess_the_number/logic/score_calculator.dart` | (none beyond `dart:math`) | Clean |

- **Violations found: 0** (strict cross-module violations)
- **Observations: 1** (see [I-1] below)

All cross-module imports flow in the correct direction: `main` wires everything together, `app` depends on `core`, `home` depends on `core`, each game depends on `core` and its own internal subpackages. No game depends on another game. No core module depends on presentation.

---

### State Management Assessment

#### HomeCubit

**Verdict**: Correct

- Descriptive naming following VGV convention (`HomeCubit`, `HomeState`, `HomeStatus`)
- State is immutable with `copyWith` and `Equatable`
- Business logic (loading game statuses, reading streaks) is in the cubit, not the view
- Data access goes through `GameRegistry` and `GameStorageRepository`
- `BlocProvider` creation in `HomePage.build()` with proper `context.read` for dependencies
- Lifecycle management: `WidgetsBindingObserver` used correctly in the `_HomeView` `StatefulWidget` to refresh on app resume

#### GameCubit

**Verdict**: Correct, with one important observation

- Descriptive naming (`GameCubit`, `GameState`, `GameStatus`)
- State is immutable with `copyWith` using closure-based nullable field pattern — this is the correct VGV pattern for distinguishing "not provided" from "set to null"
- All business logic lives in the cubit: question selection, parameter locking, question confirmation, scoring, win/loss detection, timer ticking
- No direct data access from UI — the cubit encapsulates all game logic
- `QuestionEvaluator` and `ScoreCalculator` are pure static utility classes called from the cubit, keeping the cubit as the orchestrator

**[I-2] GameCubit does not persist completion to GameStorageRepository**: When the player wins, the cubit emits `GameStatus.won` but never calls `storageRepository.saveStreak()`. The `GamePage` does not have access to the `GameStorageRepository`, so streak data is never persisted after a win. This means the home screen will always show `DailyGameStatus.notStarted` and streaks will never increment. This is a functional gap that also represents an architectural question: either the cubit should receive the repository (preferred — keeps side effects in the state management layer), or a `BlocListener` in the view should trigger the save (acceptable but less clean).

**[S-1] GameState has many fields (14 props)**: While each field is justified by the game mechanics, the state class is large. Consider whether grouping related fields into sub-objects (e.g., a `StagedQuestion` value object holding `activeQuestionType`, `firstParam`, `secondParam`, `editingParam`) would improve readability. This is a suggestion, not a violation — the current flat structure works and all fields participate in equality.

---

### Dependency Direction

**Direction violations: 0**

The dependency graph flows strictly one way:

```
main.dart (composition root)
  |
  +---> app/ (shell)
  |       |---> core/ (infrastructure)
  |       +---> home/ (presentation)
  |
  +---> core/ (infrastructure)
  |       |---> game_registry/ (contracts)
  |       |---> storage/ (persistence)
  |       |---> daily_seed/ (utility)
  |       +---> theme/ (UI config)
  |
  +---> home/ (presentation)
  |       +---> core/ (reads registry + storage)
  |
  +---> games/guess_the_number/ (game module)
          |---> core/ (reads daily_seed, storage, game_definition)
          |---> cubit/ ---> logic/, models/
          +---> view/ ---> cubit/, models/
```

- No circular dependencies detected
- No presentation-to-data shortcuts
- Game module depends on `core` for shared contracts (`GameDefinition`, `GameStorageRepository`, `DailySeed`) and keeps all game-specific code internal
- `GameDefinition` serves as the contract between the hub shell and game modules — clean abstraction boundary

---

### Package Structure

This is a single-package Flutter app (not a multi-package monorepo), so package-level checks apply to the module/directory structure.

#### `lib/core/`
- [x] Barrel file (`core.dart`) exports all public APIs
- [x] Clear responsibility: shared infrastructure
- [x] No UI dependencies (except `flutter/widgets.dart` for `IconData` in `GameDefinition`)
- [x] Tests exist for all core modules (`daily_seed`, `game_registry`, `storage`, `streak_data`, `theme`)

#### `lib/home/`
- [x] Barrel file (`home.dart`) exports cubit and views
- [x] Clear responsibility: hub screen presentation
- [x] Tests exist for cubit, home page, and game tile

#### `lib/games/guess_the_number/`
- [x] Entry point (`guess_the_number_game.dart`) implements `GameDefinition`
- [x] Clean internal structure: `cubit/`, `logic/`, `models/`, `view/widgets/`
- [x] Barrel files at each level (`logic.dart`, `models.dart`, `view.dart`, `widgets.dart`)
- [x] Tests exist for cubit, logic (3 files), models (2 files), and game definition
- **[I-3] No view/widget tests**: The `test/games/guess_the_number/view/` directory is empty. There are 7 widget files (`card_tray.dart`, `digit_picker.dart`, `game_header.dart`, `number_grid.dart`, `question_card.dart`, `results_overlay.dart`, `score_bar.dart`) and the `game_page.dart` with no corresponding tests. VGV standards expect widget tests for all public widgets.

#### `lib/app/`
- [x] Tests exist for `app_test.dart`, `app_bloc_observer_test.dart`, `routes_test.dart`
- [x] Clean responsibility: app shell and routing

---

### Detailed Findings

#### [I-1] View widget imports logic layer directly

**File**: `lib/games/guess_the_number/view/widgets/score_bar.dart:2`
**Severity**: Important

`ScoreBar` imports `logic/logic.dart` to access `ScoreCalculator.startingBudget`. While this is within the same game module (not a cross-module violation), it breaks the internal layering convention where views should depend on the cubit/state, not the logic layer directly.

**Recommendation**: Expose `startingBudget` through `GameState` (e.g., a static const or getter) so the view only depends on the state, not the logic internals. Alternatively, pass `maxScore` as a constructor parameter to `ScoreBar`.

#### [I-2] No streak persistence on game completion

**File**: `lib/games/guess_the_number/cubit/game_cubit.dart` and `lib/games/guess_the_number/view/game_page.dart`
**Severity**: Important (functional gap with architectural implications)

When the player wins, `GameCubit.confirmQuestion()` emits `GameStatus.won` but never persists the result. The `GamePage` creates `GameCubit` without a `GameStorageRepository`, so there is no path for saving streak data. The `GuessTheNumberGame.getDailyStatus()` reads from storage, but nothing writes to it after a win.

**Recommendation**: Inject `GameStorageRepository` into `GameCubit` and call `saveStreak()` when the game is won. This keeps side effects in the state management layer, consistent with VGV patterns.

#### [I-3] Missing widget tests for the game view layer

**Directory**: `test/games/guess_the_number/view/` (empty)
**Severity**: Important

Seven widget files and the game page have no tests. The cubit and logic layers are well-tested, but the view layer has zero coverage. VGV standards require widget tests for all public widgets.

**Missing test files**:
- `test/games/guess_the_number/view/game_page_test.dart`
- `test/games/guess_the_number/view/widgets/card_tray_test.dart`
- `test/games/guess_the_number/view/widgets/digit_picker_test.dart`
- `test/games/guess_the_number/view/widgets/game_header_test.dart`
- `test/games/guess_the_number/view/widgets/number_grid_test.dart`
- `test/games/guess_the_number/view/widgets/question_card_test.dart`
- `test/games/guess_the_number/view/widgets/results_overlay_test.dart`
- `test/games/guess_the_number/view/widgets/score_bar_test.dart`

#### [S-1] GameState field count

**File**: `lib/games/guess_the_number/cubit/game_state.dart`
**Severity**: Suggestion

`GameState` has 14 fields. Consider grouping staging-related fields (`activeQuestionType`, `firstParam`, `secondParam`, `editingParam`, `highlightedCell`) into a `StagedQuestion` value object to reduce cognitive load.

#### [S-2] Hardcoded colors in widget painters

**Files**: `lib/games/guess_the_number/view/widgets/number_grid.dart`, `card_tray.dart`, `question_card.dart`
**Severity**: Suggestion

Several widgets use hardcoded `Color` constants (e.g., `Color(0xFF4CAF50)`, `Color(0xFF1565C0)`) rather than referencing the app theme. The `_colorForState` method appears in both `_GridPainter` and `_ZoomLensPainter` with identical implementations. Consider:
1. Extracting a shared color mapping (e.g., `CellStateColors` or an extension on `CellState`)
2. Similarly, `_colorForCategory` is duplicated between `CardTray` and `QuestionCard`

#### [S-3] Star rating thresholds use impossible values

**File**: `lib/games/guess_the_number/view/widgets/results_overlay.dart:162-166`
**Severity**: Suggestion

`_StarRating` awards 3 stars for `score >= 800`, but `ScoreCalculator.startingBudget` is 600. The maximum possible score is 600 (0 questions, 0 seconds), so 3 stars is impossible. The thresholds should be recalibrated against the actual budget.

---

### Verdict

**Architecture is sound. Fix 3 important issues before merging.**

The codebase demonstrates clean layer separation, correct use of flutter_bloc with immutable state and the VGV closure-based `copyWith` pattern, proper dependency direction, and a well-designed game registry abstraction. The modular structure under `lib/games/` will scale cleanly as new games are added.

**Summary of required actions**:
1. **[I-1]** Remove direct logic-layer import from `ScoreBar` widget — pass the value through state or constructor
2. **[I-2]** Wire `GameStorageRepository` into `GameCubit` to persist streak on win — this is a functional gap
3. **[I-3]** Add widget tests for all 8 view files in the guess_the_number game module
