---
title: "feat: add Signal grid logic puzzle game"
type: feat
date: 2026-04-03
---

> **Note:** This plan has been split into parts. See the `-part-1`, `-part-2`, and `-part-3` files in this directory.

## feat: add Signal grid logic puzzle game

## Overview

Add a second daily game to the hub: **Signal**, a grid-based logic puzzle where players place walls to control how far numbered towers broadcast. Each tower displays a number indicating exactly how many cells its signal should reach in four cardinal directions. Signals travel in straight lines until hitting a wall or grid edge. The player wins when every tower's constraint is satisfied simultaneously.

The game follows all existing patterns — `GameDefinition` registration, `DailySeed`, `flutter_bloc` (Cubit), `GameStorageRepository` for streaks, and Nostr result sharing. This is also the trigger to generalize `EventBuilder` and `ResultSharingCubit` for multi-game support.

## Problem Statement / Motivation

The app currently has one game (Guess the Number). A daily puzzle hub needs variety to drive repeat engagement. Signal adds a visual/spatial puzzle that complements the number-logic style of the existing game, is language-independent, and targets under 3 minutes of play time.

## Proposed Solution

### Architecture

```
lib/games/signal/
├── signal_game.dart              # GameDefinition implementation
├── models/
│   ├── models.dart               # barrel
│   ├── cell.dart                 # Cell enum: empty, wall, tower(number)
│   ├── grid.dart                 # Grid model (2D cells + tower positions)
│   └── signal_result.dart        # Completed game result data
├── logic/
│   ├── logic.dart                # barrel
│   ├── puzzle_generator.dart     # Deterministic puzzle generation from seed
│   ├── signal_calculator.dart    # Compute signal reach for each tower
│   └── score_calculator.dart     # Move count → score conversion
├── cubit/
│   ├── signal_cubit.dart         # Game state management
│   └── signal_state.dart         # State: grid, moveCount, status, etc.
├── view/
│   ├── view.dart                 # barrel
│   ├── signal_page.dart          # Top-level page (BlocProviders)
│   └── widgets/
│       ├── widgets.dart          # barrel
│       ├── signal_grid.dart      # Grid widget with tower/wall/empty cells
│       ├── signal_cell.dart      # Individual cell rendering
│       ├── tower_indicator.dart  # Tower number + current/target count
│       ├── signal_path_overlay.dart  # Visual signal ray rendering
│       ├── move_counter.dart     # Displays current move count
│       ├── signal_results_overlay.dart  # Results on win
│       └── instructions_dialog.dart    # How-to-play modal
└── theme/
    └── signal_colors.dart        # Game-specific color palette
```

### Implementation Phases

#### Phase 1: Core Models and Puzzle Logic

Foundation layer — pure Dart, no Flutter dependency. Fully testable in isolation.

- [ ] `Cell` type — enum/sealed class representing empty, wall, tower(number) — `lib/games/signal/models/cell.dart`
- [ ] `Grid` model — 2D grid of cells, tower positions, grid size (5 or 6) — `lib/games/signal/models/grid.dart`
- [ ] `SignalCalculator` — given a grid, compute the signal reach (number of cells hit) for each tower in 4 cardinal directions, stopping at walls/edges — `lib/games/signal/logic/signal_calculator.dart`
- [ ] `PuzzleGenerator` — deterministic puzzle generation from a daily seed:
  1. Use seed to determine grid size: `seed.abs() % 3 == 0` → 6x6, else 5x5 (roughly 1/3 chance of 6x6)
  2. Generate a valid solution (grid with walls placed)
  3. Place towers at strategic positions with their target signal counts derived from the solution
  4. Remove all walls to create the player-facing puzzle
  5. Verify the puzzle has a unique solution via backtracking solver
  6. File: `lib/games/signal/logic/puzzle_generator.dart`
- [ ] `ScoreCalculator` — converts move count to a score. Formula: `max(0, budget - (moveCount - optimalMoves) * penalty)` where `budget = 500`, `penalty = 25`, and `optimalMoves` is the number of walls in the solution. Star thresholds: 3 stars = optimal, 2 stars = optimal + 1-3, 1 star = optimal + 4+. — `lib/games/signal/logic/score_calculator.dart`
- [ ] `SignalResult` — completed game data (moveCount, score, stars, gridSize, optimalMoves) — `lib/games/signal/models/signal_result.dart`
- [ ] Unit tests for all models and logic

#### Phase 2: State Management (Cubit)

- [ ] `SignalState` — immutable state holding: grid, moveCount, status (playing/won), highlightedCells, dragMode, tower signal counts — `lib/games/signal/cubit/signal_state.dart`
- [ ] `SignalCubit` — manages game flow:
  - `toggleCell(row, col)` — tap to toggle a single cell between empty/wall; increments move count
  - `startDrag(row, col)` — begins drag; first cell determines mode (paint if empty, erase if wall); skips tower cells
  - `continueDrag(row, col)` — extends drag to additional cells in the current mode; each affected cell increments move count
  - `endDrag()` — finalizes drag gesture
  - After each state change, recalculate signal reach for all towers via `SignalCalculator`
  - Win detection: all towers satisfied → emit won status
  - File: `lib/games/signal/cubit/signal_cubit.dart`
- [ ] State persistence — save/load grid state to `SharedPreferences` keyed by `signal_state_YYYY-MM-DD`:
  - Save after every move (debounced or on each emit)
  - Load on cubit creation; if saved state exists for today, restore it
  - Clear on win or when the date changes
  - Add methods to `GameStorageRepository`: `saveSignalState(String date, String json)`, `loadSignalState(String date)`, `clearSignalState(String date)`
- [ ] Unit tests with `bloc_test` for all cubit behaviors

#### Phase 3: Grid UI and Interaction

- [ ] `SignalGrid` — `GestureDetector` + `CustomPaint` (or `GridView`) rendering the puzzle grid — `lib/games/signal/view/widgets/signal_grid.dart`
  - Handle tap (toggle) and pan (drag-to-paint) gestures
  - Convert pixel coordinates to grid row/col
  - Pass gestures to cubit: `toggleCell`, `startDrag`, `continueDrag`, `endDrag`
- [ ] `SignalCell` — renders individual cells: empty (light), wall (dark/filled), tower (numbered circle) — `lib/games/signal/view/widgets/signal_cell.dart`
- [ ] `TowerIndicator` — shows tower number and live signal count (e.g., "3/4"), color-coded:
  - Green: count == target (satisfied)
  - Red: count > target (over-satisfied/conflict)
  - Default: count < target (not yet solved)
  - File: `lib/games/signal/view/widgets/tower_indicator.dart`
- [ ] `SignalPathOverlay` — renders signal rays as colored highlights extending from each tower in 4 directions, stopping at walls/edges. Always visible. — `lib/games/signal/view/widgets/signal_path_overlay.dart`
- [ ] `MoveCounter` — displays current move count — `lib/games/signal/view/widgets/move_counter.dart`
- [ ] `InstructionsDialog` — static how-to-play modal with a simple diagram showing a tower, walls, and signal rays. Shown on first play, accessible via AppBar info button. — `lib/games/signal/view/widgets/instructions_dialog.dart`
- [ ] Widget tests for grid, cell, and overlay rendering

#### Phase 4: Game Registration and Page Wiring

- [ ] `SignalGame extends GameDefinition` — id: `signal`, name: "Signal", description: "Block signals with walls in a daily logic puzzle", icon: `Icons.cell_tower`, routePath: `/games/signal` — `lib/games/signal/signal_game.dart`
  - Route builder: create `SignalPage` with daily seed, load persisted state if available
  - `getDailyStatus`: check `GameStorageRepository` for today's completion
- [ ] `SignalPage` — top-level page composing `MultiBlocProvider` with `SignalCubit`, `ResultSharingCubit`, `CommunityStatsCubit` — `lib/games/signal/view/signal_page.dart`
- [ ] Register `SignalGame` in `GameRegistry` in `main.dart`
- [ ] `SignalResultsOverlay` — results on win: score, stars, move count breakdown (optimal vs. actual), streak, community stats, share button, "Back to Hub" — `lib/games/signal/view/widgets/signal_results_overlay.dart`
- [ ] Integration: persist streak on win, fetch community stats on win

#### Phase 5: Generalize Nostr Sharing for Multi-Game Support

The `EventBuilder` and `ResultSharingCubit` are currently hardcoded to Guess the Number. This phase generalizes them.

- [ ] Generalize `EventBuilder` — add `buildSignalResult` method with Signal-specific event:
  - d-tag: `signal:YYYY-MM-DD`
  - Tags: `['t', 'vgg']`, `['t', 'signal']`, `['L', 'games.vgg.score']`, `['l', 'score-N', 'games.vgg.score']`, `['l', 'moves-N', 'games.vgg.score']`, `['l', 'grid-NxN', 'games.vgg.score']`
  - Content: human-readable summary with score, moves, grid size, stars
  - File: `lib/nostr/sharing/event_builder.dart`
- [ ] Generalize `ResultSharingCubit.share()` — accept a game-specific event builder callback or a `GameResult` abstraction so the cubit doesn't need to know about each game's data shape
- [ ] Update `CommunityStatsRepository` to query by game-specific d-tag prefix (`signal:` vs `guess-the-number:`)
- [ ] Update existing Guess the Number integration to use the generalized flow (no behavior change, just plumbing)
- [ ] Tests for all generalized code

## Technical Considerations

### Puzzle Generation Algorithm

The generator is the most complex piece. Approach:

1. **Build a random valid solution**: seed a `Random`, place walls randomly on empty cells (avoiding tower positions) until a valid configuration is reached
2. **Place towers**: for each wall-free cell adjacent to interesting signal paths, place a tower with its signal count as the target
3. **Validate uniqueness**: run a backtracking solver on the puzzle (with walls removed). If multiple solutions exist, regenerate
4. **Performance**: generation must complete in under 100ms. For 5x5 (25 cells) and 6x6 (36 cells), the search space is small enough for brute-force backtracking

Alternative: "dig" approach — start with a fully walled grid, remove walls one at a time while maintaining unique solvability. This often produces better puzzles (fewer walls needed, more elegant solutions).

The generator should be a pure function: `Grid generate(int seed)` — fully deterministic, no side effects.

### State Persistence

New pattern for the codebase. Extend `GameStorageRepository` with JSON-based save/load for grid state. Key format: `signal_state_YYYY-MM-DD`. Store as a JSON string containing the cell states and move count. Clear when:
- The puzzle is solved (replace with completion marker)
- A new day begins (stale state from yesterday)

### Drag Gesture Handling

The drag-to-paint interaction requires careful gesture handling:
- Use `GestureDetector.onPanStart`, `onPanUpdate`, `onPanEnd`
- Convert global coordinates to grid row/col on each update
- Track which cells have been visited during the current drag to avoid re-toggling
- First cell touched sets the drag mode (paint or erase)
- Tower cells are skipped during drag

### Scoring

- **Budget**: 500 points
- **Penalty**: 25 points per extra move beyond optimal
- **Optimal moves**: equal to the number of walls in the solution (known at generation time, embedded in the puzzle data)
- **Stars**: 3 = 0 extra moves (perfect), 2 = 1-3 extra, 1 = 4+ extra
- **No lose condition**: player always finishes, score reflects efficiency

## Acceptance Criteria

### Functional Requirements

- [ ] Daily deterministic puzzle: all players see the same grid on the same day
- [ ] Grid size is 5x5 or 6x6, determined by daily seed (~1/3 chance of 6x6)
- [ ] Towers display target number and live signal count with color feedback
- [ ] Signal paths are always visible as colored highlights
- [ ] Tap toggles individual cells; drag paints/erases based on first cell
- [ ] Tower cells cannot be modified (wall cannot be placed on a tower)
- [ ] Move count increments on every cell state change
- [ ] Win detected when all towers are simultaneously satisfied
- [ ] Results overlay shows score, stars, move breakdown, streak, community stats, share button
- [ ] Nostr sharing works with Signal-specific event schema
- [ ] Community stats display for Signal (player count, avg score)
- [ ] Puzzle state persists across app restarts (resumes where player left off)
- [ ] State clears on win or when the date changes
- [ ] Instructions dialog on first play, accessible via AppBar info button
- [ ] Game registered in hub; tile shows daily status and streak
- [ ] Generated puzzles are always solvable with a unique solution

### Non-Functional Requirements

- [ ] Puzzle generation completes in under 100ms
- [ ] Grid interaction is smooth at 60fps (no jank during drag)
- [ ] Signal path recalculation is instant (<16ms) after each move

### Quality Gates

- [ ] Unit tests for all models, logic, and cubit
- [ ] Widget tests for grid, cells, overlays, and dialogs
- [ ] Tests mirror `lib/` structure 1:1 under `test/`
- [ ] All tests pass with `very_good_analysis` v7.0.0 lint rules
- [ ] Existing Guess the Number tests still pass after Nostr generalization

## Dependencies & Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Puzzle generation produces unsolvable or multi-solution puzzles | Broken game day | Backtracking solver validates every puzzle; seed-based regression tests for known dates |
| Generation is too slow for complex 6x6 grids | Bad first-load UX | Profile early; fall back to pre-computed lookup if needed |
| Drag gesture conflicts with scroll or system gestures | Frustrating interaction | Contain grid in a non-scrollable area; test on physical devices |
| Nostr generalization breaks existing Guess the Number sharing | Regression | Keep existing `buildGuessTheNumberResult` working; add Signal alongside |
| State persistence JSON schema changes between versions | Corrupted saved state | Treat load failures gracefully — discard and start fresh |

## References & Research

### Internal References

- Game registration pattern: [game_definition.dart](lib/core/game_registry/game_definition.dart)
- Existing game implementation: [guess_the_number_game.dart](lib/games/guess_the_number/guess_the_number_game.dart)
- Cubit pattern: [game_cubit.dart](lib/games/guess_the_number/cubit/game_cubit.dart)
- Daily seed: [daily_seed.dart](lib/core/daily_seed/daily_seed.dart)
- Event builder (to generalize): [event_builder.dart](lib/nostr/sharing/event_builder.dart)
- Result sharing cubit (to generalize): [result_sharing_cubit.dart](lib/nostr/sharing/cubit/result_sharing_cubit.dart)
- Storage repository (to extend): [game_storage_repository.dart](lib/core/storage/game_storage_repository.dart)
- Results overlay pattern: [results_overlay.dart](lib/games/guess_the_number/view/widgets/results_overlay.dart)
- Game page pattern: [game_page.dart](lib/games/guess_the_number/view/game_page.dart)

### Related Work

- Brainstorm document: [2026-04-03-signal-puzzle-game-brainstorm-doc.md](docs/brainstorm/2026-04-03-signal-puzzle-game-brainstorm-doc.md)
- Akari (Light Up) puzzle — similar mechanic of light propagation with numbered constraints
