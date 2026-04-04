---
title: "feat(signal): add core models, puzzle logic, and state management"
type: feat
date: 2026-04-03
---

## feat(signal): add core models, puzzle logic, and state management

## Overview

Create the pure-Dart foundation for the Signal grid logic puzzle game: models, puzzle generation, signal calculation, scoring, and state management via Cubit. This PR creates the entire `lib/games/signal/` directory except for the `view/` and `theme/` layers. Everything is unit-testable with no Flutter UI dependency.

After this PR merges, all game logic is ready for the UI layer (Part 2) to consume.

## Problem Statement / Motivation

The app needs a second daily game to drive engagement. Signal is a grid-based logic puzzle where players place walls to control tower signal propagation. This PR builds the logic core that the UI will consume.

## Proposed Solution

### Directory Structure

```
lib/games/signal/
├── models/
│   ├── models.dart               # barrel
│   ├── cell.dart                 # Cell enum: empty, wall, tower(number)
│   └── grid.dart                 # Grid model (2D cells + tower positions)
├── logic/
│   ├── logic.dart                # barrel
│   ├── puzzle_generator.dart     # Deterministic puzzle generation from seed
│   ├── signal_calculator.dart    # Compute signal reach for each tower
│   └── score_calculator.dart     # Move count → score conversion
└── cubit/
    ├── signal_cubit.dart         # Game state management
    └── signal_state.dart         # part of signal_cubit.dart
```

### Tasks

#### Models (`lib/games/signal/models/`)

- [ ] `Cell` — sealed class or enum representing cell types: `empty`, `wall`, `tower(int targetCount)` — `cell.dart`
- [ ] `Grid` — immutable model holding a 2D list of `Cell`s, grid size (5 or 6), and convenience accessors for tower positions — `grid.dart`
- [ ] `models.dart` barrel file

#### Logic (`lib/games/signal/logic/`)

- [ ] `SignalCalculator` — given a `Grid`, compute the signal reach for each tower. For each tower, cast rays in 4 cardinal directions, counting empty cells until hitting a wall or grid edge. Returns a `Map<(int, int), int>` of tower position to current signal count — `signal_calculator.dart`
- [ ] `PuzzleGenerator` — deterministic puzzle generation from a daily seed — `puzzle_generator.dart`:
  1. Use seed to determine grid size: `seed.abs() % 3 == 0` → 6x6, else 5x5
  2. Seed a `Random` instance from the daily seed
  3. Generate a valid solution: place walls on the grid to create interesting signal constraints
  4. Place towers at strategic positions; set each tower's target count from the solution's signal reach values
  5. Remove all walls to create the player-facing puzzle
  6. Return the puzzle `Grid` plus the wall count from the solution (used for scoring)
  7. **No uniqueness solver for v1** — generating a valid, solvable puzzle is sufficient. Uniqueness validation can be added later if playtesting reveals it matters.
- [ ] `ScoreCalculator` — simple budget-minus-cost model matching the existing Guess the Number pattern — `score_calculator.dart`:
  - Formula: `max(0, 500 - moveCount * 20)`
  - Star thresholds: 3 stars >= 400, 2 stars >= 250, 1 star > 0
  - No `optimalMoves` dependency — score is a pure function of move count
  - Static methods: `calculate(int moveCount)` and `stars(int score)`
- [ ] `logic.dart` barrel file

#### State Management (`lib/games/signal/cubit/`)

- [ ] `SignalState` — immutable state (using `part of 'signal_cubit.dart'` convention matching existing game) — `signal_state.dart`:
  - `grid` — current `Grid` with player's wall placements
  - `moveCount` — total cell state changes (every toggle counts as +1)
  - `status` — enum: `playing`, `won`
  - `towerSignals` — `Map<(int, int), int>` current signal reach per tower (recomputed after each move)
  - `dragMode` — nullable enum: `paint`, `erase` (set during drag)
  - `dragVisitedCells` — `Set<(int, int)>` cells already modified in current drag (prevents re-toggling)
  - `score` — nullable int, computed on win
  - `solutionWallCount` — int, from puzzle generator (for display only, not scoring)
- [ ] `SignalCubit` — manages game flow — `signal_cubit.dart`:
  - Constructor takes daily seed; calls `PuzzleGenerator.generate(seed)` to create the puzzle. If persisted state exists for today, restores it.
  - `toggleCell(int row, int col)` — tap interaction: toggle empty↔wall on non-tower cells, increment moveCount, recalculate signals via `SignalCalculator`, check win condition
  - `startDrag(int row, int col)` — begins drag; first cell determines mode (paint if empty, erase if wall); applies to first cell; skips tower cells
  - `continueDrag(int row, int col)` — extends drag to additional cells in current mode; skips already-visited cells and tower cells; increments moveCount per affected cell
  - `endDrag()` — clears drag state, persists current grid state
  - Win detection: after each state change, check if all towers are satisfied (signal count == target for every tower)
  - On win: compute score via `ScoreCalculator`, emit `won` status, clear persisted state
- [ ] State persistence — extend `GameStorageRepository` with generic methods:
  - `saveGameState(String key, String json)` — saves JSON string to SharedPreferences
  - `loadGameState(String key)` — returns JSON string or null
  - `clearGameState(String key)` — removes the key
  - Key format for Signal: `signal_state_YYYY-MM-DD`
  - Save on `endDrag()` and `toggleCell()` (not on every emit during drag)
  - Load on cubit creation; restore if saved state exists for today's date
  - Clear on win or when date changes

#### Tests

- [ ] Unit tests for `Cell` and `Grid` models
- [ ] Unit tests for `SignalCalculator` — various grid configurations, edge cases (tower at grid edge, adjacent towers, empty grid)
- [ ] Unit tests for `PuzzleGenerator` — **determinism test is critical**: same seed must produce identical puzzle across runs. Test for both 5x5 and 6x6 generation. Verify all generated puzzles are solvable.
- [ ] Unit tests for `ScoreCalculator` — boundary values, zero score, star thresholds
- [ ] `bloc_test` for `SignalCubit` — all methods: toggleCell, startDrag/continueDrag/endDrag, win detection, state persistence load/save
- [ ] Unit tests for `GameStorageRepository` generic save/load/clear methods
- [ ] All tests mirror `lib/` structure under `test/games/signal/`

## Technical Considerations

### Puzzle Generation

The generator is a pure function: `(Grid puzzle, int solutionWallCount) generate(int seed)`. The "dig" approach (start with walls, remove while maintaining constraints) tends to produce better puzzles than random placement. The generator should aim for:
- 5x5: 3-5 towers, 4-8 walls in solution
- 6x6: 4-7 towers, 6-12 walls in solution

These ranges keep puzzles solvable in under 3 minutes.

### State Persistence

New generic methods on `GameStorageRepository` (not Signal-specific). The grid state serializes to JSON: cell types as a flat list, plus moveCount. Small payload (~200 bytes for 6x6).

## Acceptance Criteria

- [ ] `PuzzleGenerator.generate(seed)` is fully deterministic — same seed always produces same puzzle
- [ ] Grid size is 5x5 when `seed.abs() % 3 != 0`, 6x6 when `seed.abs() % 3 == 0`
- [ ] `SignalCalculator` correctly computes signal reach in 4 cardinal directions, stopping at walls and grid edges
- [ ] `ScoreCalculator` uses `max(0, 500 - moveCount * 20)` formula
- [ ] Cubit toggleCell increments moveCount and recalculates signals
- [ ] Cubit drag methods support paint/erase modes based on first cell
- [ ] Win detected when all towers' signal counts equal their targets
- [ ] State persists on toggleCell and endDrag, loads on cubit creation
- [ ] Persisted state clears on win or date change
- [ ] Generic `saveGameState`/`loadGameState`/`clearGameState` work for any game
- [ ] All tests pass with `very_good_analysis` v7.0.0

## Dependencies

- None — this is the first PR in the sequence.

## References

- Existing cubit pattern: [game_cubit.dart](lib/games/guess_the_number/cubit/game_cubit.dart)
- Existing state pattern: [game_state.dart](lib/games/guess_the_number/cubit/game_state.dart)
- Daily seed: [daily_seed.dart](lib/core/daily_seed/daily_seed.dart)
- Storage repository: [game_storage_repository.dart](lib/core/storage/game_storage_repository.dart)
- Existing score calculator: [score_calculator.dart](lib/games/guess_the_number/logic/score_calculator.dart)
- Brainstorm: [2026-04-03-signal-puzzle-game-brainstorm-doc.md](docs/brainstorm/2026-04-03-signal-puzzle-game-brainstorm-doc.md)
