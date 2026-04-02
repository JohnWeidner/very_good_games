---
title: "feat: add guess the number game"
type: feat
date: 2026-04-02
---

## ✨ feat: add guess the number game

## Overview

Build the first game module for Very Good Games — a deduction puzzle where players narrow down a hidden number (1–1024) on a 32x32 grid by asking strategic questions. Each question type can only be used once, forcing varied mathematical thinking. The game integrates with the hub shell via `GameDefinition` and supports daily mode with deterministic seeding.

## Problem Statement

The game hub shell is built but has no games registered. This is the first game that validates the entire architecture — `GameDefinition` contract, `DailySeed`, streak tracking, and the home screen tile lifecycle.

## Proposed Solution

### Game Design

**Grid**: A 32x32 grid of circles, each representing a number from 1 to 1024. Top row = 1–32, second row = 33–64, and so on. Row labels on the left edge show the first number of each row (1, 33, 65, ...). Individual cells do **not** display their number — instead, as the player slides their finger across the grid, the currently highlighted cell's number is displayed prominently above the grid.

**Cell states**:
- **Possible** (green circle) — number is still a candidate
- **Eliminated** (dimmed/gray circle) — ruled out by a question
- **Wrong guess** (red circle) — guessed with `=` and was incorrect
- **Target** (gold/highlighted) — the correct answer, revealed on win

**Interaction model**: The grid is the primary input mechanism. For questions that require a number (e.g., `< N`, `= N`), the player selects a cell on the grid by sliding their finger to it — the highlighted cell's number becomes the parameter. For questions that require a grid position (e.g., `hand grenade`), the player taps a cell to choose the center point.

**Question flow**:
1. Player taps a question type from a list/panel below the grid
2. The question type is selected and the grid enters "parameter selection" mode
3. Player slides finger on the grid — a cell is highlighted and its number is shown
4. Player lifts finger to confirm the selection
5. Grid updates: eliminated cells dim, remaining cells stay green
6. Used question type is marked as spent (grayed out in the list)

**Question types** (each usable once per game unless noted):

| Category | Type | Parameter | Description |
|---|---|---|---|
| Comparison | `< N` | Number (grid cell) | Is the target less than N? |
| Comparison | `<= N` | Number (grid cell) | Is the target less than or equal to N? |
| Comparison | `> N` | Number (grid cell) | Is the target greater than N? |
| Comparison | `>= N` | Number (grid cell) | Is the target greater than or equal to N? |
| Comparison | `between (excl)` | Two numbers | Is the target between X and Y (exclusive)? |
| Comparison | `between (incl)` | Two numbers | Is the target between X and Y (inclusive)? |
| Math | `is odd` | None | Is the target odd? |
| Math | `is even` | None | Is the target even? |
| Math | `is divisible by N` | Number (grid cell) | Is the target divisible by N? |
| Math | `is prime` | None | Is the target prime? |
| Guess | `= N` | Number (grid cell) | Guess the exact number *(repeatable)* |
| Special | `shotgun` | None | Eliminates 20 random cells from remaining possibilities |
| Special | `hand grenade` | Grid cell | Eliminates 20 closest remaining cells to the chosen cell |

**`between` questions**: Require two parameters. After selecting the question type, the player picks the first bound on the grid, then the second bound. Both bounds are displayed during selection.

**No-parameter questions** (`is odd`, `is even`, `is prime`, `shotgun`): Apply immediately upon selection — no grid interaction needed.

**Wrong `=` guess**: The guessed cell turns red, counts as +1 question for scoring. No game over — player can keep guessing.

**Win condition**: Player uses `=` on the correct number. The target cell turns gold, timer stops, score is calculated.

**Scoring formula**: `score = max(0, 1000 - (questions * 50) - (seconds * 2))`
- A perfect game (1 question, 0 seconds) = 950 points
- A typical game (~10 questions, ~60 seconds) = 380 points
- Score cannot go below 0

**Daily mode**: Target number is derived from `DailySeed.forDate(today)` via `(seed % 1024) + 1`. All players get the same target on the same UTC day.

### Architecture

The game lives in its own feature module under `lib/games/guess_the_number/`:

```
lib/games/guess_the_number/
├── guess_the_number_game.dart         # GameDefinition implementation
├── models/
│   ├── models.dart                    # Barrel
│   ├── question_type.dart             # Question type enum + logic
│   ├── game_state_data.dart           # Serializable game state for persistence
│   └── cell_state.dart                # Cell state enum (possible, eliminated, wrongGuess, target)
├── logic/
│   ├── logic.dart                     # Barrel
│   ├── question_evaluator.dart        # Applies a question to the grid, returns updated cells
│   ├── prime_checker.dart             # Efficient prime check for 1-1024
│   └── score_calculator.dart          # Scoring formula
├── cubit/
│   ├── game_cubit.dart                # Game state management
│   └── game_state.dart                # Cubit state (part file)
└── view/
    ├── view.dart                      # Barrel
    ├── game_page.dart                 # Top-level page (creates cubit)
    └── widgets/
        ├── number_grid.dart           # 32x32 grid of circles with touch interaction
        ├── question_panel.dart        # List of available question types
        ├── game_header.dart           # Timer, question count, highlighted number display
        └── results_overlay.dart       # Win screen with score + stats
```

**Test structure mirrors `lib/`:**

```
test/games/guess_the_number/
├── guess_the_number_game_test.dart
├── models/
│   ├── question_type_test.dart
│   ├── game_state_data_test.dart
│   └── cell_state_test.dart
├── logic/
│   ├── question_evaluator_test.dart
│   ├── prime_checker_test.dart
│   └── score_calculator_test.dart
├── cubit/
│   └── game_cubit_test.dart
└── view/
    ├── game_page_test.dart
    ├── number_grid_test.dart
    ├── question_panel_test.dart
    ├── game_header_test.dart
    └── results_overlay_test.dart
```

## Technical Approach

### Implementation Phases

#### Phase 1: Models + Pure Logic (no Flutter, no state)

Build the data layer and game logic as pure Dart — fully testable without widget tests.

- [ ] `CellState` enum in `lib/games/guess_the_number/models/cell_state.dart`
  - Values: `possible`, `eliminated`, `wrongGuess`, `target`
- [ ] `QuestionType` enum in `lib/games/guess_the_number/models/question_type.dart`
  - All 13 question types with metadata (label, category, requiresParameter, requiresTwoParameters, isRepeatable)
- [ ] `GameStateData` in `lib/games/guess_the_number/models/game_state_data.dart`
  - Serializable model: `targetNumber`, `cells` (List<CellState> of length 1024), `usedQuestionTypes` (Set<QuestionType>), `questionCount`, `elapsedSeconds`, `isComplete`
  - `toJson()` and `fromJson()` for persistence
- [ ] `PrimeChecker` in `lib/games/guess_the_number/logic/prime_checker.dart`
  - Precomputed set of primes from 1–1024 (there are 172 of them)
  - `static bool isPrime(int n)` — O(1) lookup
- [ ] `QuestionEvaluator` in `lib/games/guess_the_number/logic/question_evaluator.dart`
  - `static List<CellState> apply(QuestionType type, int targetNumber, List<CellState> currentCells, {int? param1, int? param2, Random? random})`
  - For each question type, marks cells as `eliminated` or leaves them as `possible` based on whether the number satisfies the condition relative to the target
  - `shotgun`: uses `Random` (injectable for testing) to pick 20 remaining `possible` cells to eliminate (excluding the target)
  - `hand grenade`: finds 20 closest remaining `possible` cells to param1 (by Euclidean grid distance), eliminates them (excluding the target)
- [ ] `ScoreCalculator` in `lib/games/guess_the_number/logic/score_calculator.dart`
  - `static int calculate({required int questions, required int seconds})`
  - Formula: `max(0, 1000 - (questions * 50) - (seconds * 2))`
- [ ] Unit tests for all of the above
  - `PrimeChecker`: known primes, known composites, edge cases (1 is not prime, 2 is prime)
  - `QuestionEvaluator`: test each question type individually, verify correct cells are eliminated
  - `ScoreCalculator`: boundary cases (0 questions, high values, negative clamp)
  - `GameStateData`: JSON round-trip serialization
  - `QuestionType`: metadata correctness

#### Phase 2: State Management (GameCubit)

Wire the pure logic into a Cubit that manages the full game lifecycle.

- [ ] `GameCubit` in `lib/games/guess_the_number/cubit/game_cubit.dart`
  - Constructor takes `targetNumber`, optional `GameStateData` for restore, `GameStorageRepository`
  - `startGame()` — initializes 1024 cells as `possible`, starts timer
  - `selectQuestion(QuestionType type)` — sets the active question, enters parameter selection mode
  - `cancelQuestion()` — exits parameter selection without applying
  - `confirmQuestion({int? param1, int? param2})` — applies the question via `QuestionEvaluator`, updates cells, increments question count, marks question type as used
  - `makeGuess(int number)` — applies `= N`, checks for win
  - `tick()` — increments elapsed time (driven by a Timer in the view)
  - `saveSession()` — persists `GameStateData` to `GameStorageRepository`
  - `dispose` — saves session on close
- [ ] `GameState` in `lib/games/guess_the_number/cubit/game_state.dart`
  - `status`: `playing`, `selectingParameter`, `selectingSecondParameter`, `won`
  - `cells`: `List<CellState>` (1024 entries)
  - `usedQuestionTypes`: `Set<QuestionType>`
  - `activeQuestionType`: `QuestionType?` (when selecting parameter)
  - `firstParam`: `int?` (for `between` — first bound selected, waiting for second)
  - `highlightedCell`: `int?` (the cell currently under the player's finger)
  - `questionCount`: `int`
  - `elapsedSeconds`: `int`
  - `score`: `int?` (null until won)
  - `remainingCount`: `int` (computed — number of `possible` cells)
- [ ] Session persistence via `GameStorageRepository`
  - Store game state as JSON string under key `guess_the_number_session`
  - On game start, check for existing session for today's date — if found, restore it
  - On completion, clear session and notify shell (so streak updates)
- [ ] Unit tests with `bloc_test`
  - Initial state
  - `startGame` → cells initialized
  - `selectQuestion` → enters parameter mode
  - `confirmQuestion` for each question type → correct cells eliminated
  - `makeGuess` wrong → cell turns red, question count increments
  - `makeGuess` correct → status becomes `won`, score calculated
  - Session save/restore round-trip
  - Cannot reuse a spent question type

#### Phase 3: UI Widgets

Build the visual layer, connecting to `GameCubit`.

- [ ] `NumberGrid` widget in `lib/games/guess_the_number/view/widgets/number_grid.dart`
  - 32x32 grid of circles using `CustomPaint` or `GridView`
  - Row labels on the left: 1, 33, 65, 97, ... 993
  - Cell colors: green (possible), gray (eliminated), red (wrong guess), gold (target/win)
  - Colorblind support: use both color and opacity/pattern to distinguish states
  - Touch interaction: `GestureDetector` with `onPanUpdate` — maps touch position to cell index, emits highlighted cell to cubit
  - On finger lift (`onPanEnd`/`onTapUp`): confirms selection if in parameter selection mode
- [ ] `GameHeader` widget in `lib/games/guess_the_number/view/widgets/game_header.dart`
  - Shows: timer (MM:SS), question count, remaining cell count
  - When a cell is highlighted: prominently displays the cell's number (large text)
  - When in parameter selection: shows instruction text (e.g., "Select a number for < N")
- [ ] `QuestionPanel` widget in `lib/games/guess_the_number/view/widgets/question_panel.dart`
  - Scrollable horizontal list or categorized vertical list of question type chips/buttons
  - Used types are grayed out and disabled
  - Active type is highlighted
  - Categories: Comparison, Math, Guess, Special
  - Tapping a no-parameter question (`is odd`, `is even`, `is prime`, `shotgun`) applies it immediately
  - Tapping a parameter question enters selection mode
- [ ] `ResultsOverlay` widget in `lib/games/guess_the_number/view/widgets/results_overlay.dart`
  - Displayed over the grid on win
  - Shows: score, questions used, time elapsed, target number
  - "Back to Hub" button that navigates back
- [ ] `GamePage` in `lib/games/guess_the_number/view/game_page.dart`
  - Creates `GameCubit`, provides it via `BlocProvider`
  - Layout: `GameHeader` on top, `NumberGrid` in the center (expanded), `QuestionPanel` at the bottom
  - Manages the game timer (periodic timer that calls `cubit.tick()` every second)
  - `WillPopScope`/`PopScope` — saves session on back navigation
- [ ] Widget tests
  - `NumberGrid`: renders 1024 circles, row labels visible, cell colors match state
  - `GameHeader`: displays timer, question count, highlighted number
  - `QuestionPanel`: renders all question types, disables used ones
  - `ResultsOverlay`: displays score and stats
  - `GamePage`: integration — cubit provided, layout structure correct

#### Phase 4: Shell Integration

Wire the game into the hub so it appears on the home screen.

- [ ] `GuessTheNumberGame` in `lib/games/guess_the_number/guess_the_number_game.dart`
  - Implements `GameDefinition`
  - `id`: `'guess_the_number'`
  - `name`: `'Guess the Number'`
  - `description`: `'Narrow down 1-1024 using strategic questions'`
  - `icon`: `Icons.grid_on` (or similar)
  - `routePath`: `'/games/guess-the-number'`
  - `routes`: `GoRoute` pointing to `GamePage`
  - `getDailyStatus(date)`: checks `GameStorageRepository` for today's completion
- [ ] Register in `main.dart`
  - Add `GuessTheNumberGame` to the `GameRegistry` games list
  - Pass `GameStorageRepository` to the game definition
- [ ] Update shell streak tracking
  - On game completion, `GameCubit` saves completion status to storage
  - Shell's `HomeCubit.loadGames()` picks it up via `getDailyStatus()`
- [ ] Integration tests
  - `GuessTheNumberGame` implements all `GameDefinition` fields
  - `getDailyStatus` returns `completed` after a game is won
  - `getDailyStatus` returns `notStarted` on a fresh day

## Acceptance Criteria

### Functional Requirements

- [ ] 32x32 grid of circles renders with correct number mapping (row 1 = 1–32, row 2 = 33–64, etc.)
- [ ] Row labels show the first number of each row on the left edge
- [ ] Sliding finger across grid highlights one cell and displays its number prominently
- [ ] Each of the 13 question types can be selected and applied correctly
- [ ] Question types (except `=`) can only be used once per game
- [ ] `between` questions accept two parameters via sequential grid selections
- [ ] No-parameter questions (`is odd`, `is even`, `is prime`, `shotgun`) apply immediately
- [ ] Eliminated cells dim to gray, wrong guesses turn red, correct answer turns gold
- [ ] Timer counts up from 0, displayed as MM:SS
- [ ] Scoring formula: `max(0, 1000 - (questions * 50) - (seconds * 2))`
- [ ] Results overlay shows score, time, and question count on win
- [ ] Daily mode uses `DailySeed.forDate()` to derive target: `(seed % 1024) + 1`
- [ ] Game session persists across app kills (save/restore from `shared_preferences`)
- [ ] Game appears on home screen tile with correct status (not started / completed)
- [ ] Completing the game updates the shell's streak tracking
- [ ] `hand grenade` eliminates 20 closest remaining cells to the chosen cell (Euclidean distance)
- [ ] `shotgun` eliminates 20 random remaining cells (never the target)

### Non-Functional Requirements

- [ ] Grid renders smoothly at 60fps (1024 circles) — prefer `CustomPaint` if `GridView` is too slow
- [ ] Cell state colors are distinguishable for colorblind users (use opacity + shape cues, not just color)
- [ ] Touch response feels immediate — no perceptible delay between finger movement and cell highlight

### Quality Gates

- [ ] All logic classes (QuestionEvaluator, PrimeChecker, ScoreCalculator) have unit tests
- [ ] GameCubit has bloc_test coverage for every event/state transition
- [ ] All widgets have widget tests covering rendered states
- [ ] `flutter analyze` passes with zero issues
- [ ] All tests pass

## Dependencies & Prerequisites

- **Game hub shell** (committed at `d7c1908`) — provides `GameDefinition`, `DailySeed`, `GameStorageRepository`, routing, home screen
- **No new packages required** — all dependencies (flutter_bloc, go_router, equatable, shared_preferences) are already in pubspec.yaml
- **Session storage extension** — `GameStorageRepository` needs new methods for arbitrary JSON session state (or the game stores directly via `SharedPreferences`)

## Risk Analysis & Mitigation

| Risk | Impact | Mitigation |
|---|---|---|
| 1024-circle grid performance | High — laggy grid ruins the game feel | Use `CustomPaint` with a single canvas draw pass instead of 1024 individual widgets |
| Touch accuracy on small cells | Medium — cells are ~10px on phone | Large highlighted-number display above grid reduces need for precise cell selection; finger drag snaps to nearest cell |
| `between` two-parameter UX confusion | Medium — players may not understand the two-step flow | Clear instruction text in `GameHeader` during selection; cancel button to abort |
| Prime number calculation | Low | Precomputed set — no runtime computation |
| Session JSON schema evolution | Low — v1 only | Simple `fromJson` with defaults for missing fields |

## Future Considerations

- **Nostr result sharing** — After winning, generate a shareable Nostr note with score and grid journey visualization
- **Practice mode** — Random (non-daily) target for unlimited play
- **Difficulty settings** — Smaller grids (16x16), more/fewer question types
- **Animation** — Cells animate when eliminated (fade, shrink, or ripple effect)
- **Sound effects** — Audio feedback on elimination, wrong guess, and win
- **Leaderboard** — Compare daily scores with other players via Nostr

## References & Research

### Internal References

- Brainstorm: [docs/brainstorm/2026-04-02-daily-games-hub-brainstorm-doc.md](docs/brainstorm/2026-04-02-daily-games-hub-brainstorm-doc.md)
- Game hub shell plan: [docs/plan/2026-04-02-feat-game-hub-shell-plan.md](docs/plan/2026-04-02-feat-game-hub-shell-plan.md)
- `GameDefinition` contract: [lib/core/game_registry/game_definition.dart](lib/core/game_registry/game_definition.dart)
- `DailySeed` utility: [lib/core/daily_seed/daily_seed.dart](lib/core/daily_seed/daily_seed.dart)
- `GameStorageRepository`: [lib/core/storage/game_storage_repository.dart](lib/core/storage/game_storage_repository.dart)
- Registration point: [lib/main.dart:17](lib/main.dart#L17) — `GameRegistry(games: [])`
