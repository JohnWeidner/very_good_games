---
title: "feat(chromix): add core models, color logic, puzzle generator, and solver"
type: feat
date: 2026-04-07
---

## feat(chromix): add core models, color logic, puzzle generator, and solver

## Overview

Create the pure-Dart foundation for the Chromix color-mixing puzzle game: color model, cell types, grid, mixing rules, backtracking solver with uniqueness verification, deterministic puzzle generator, and score calculator. This PR creates `lib/games/chromix/models/` and `lib/games/chromix/logic/` — everything is unit-testable with zero Flutter dependency.

After this PR merges, all game logic is ready for the cubit and UI layer (Part 2) to consume.

## Problem Statement / Motivation

The hub has two daily games (Guess the Number, Signal). Chromix adds a visual/creative color-mixing puzzle that complements existing games. This PR builds the logic core — color mixing rules, puzzle generation, solver, and scoring — that the state management and UI will consume.

## Proposed Solution

### Directory Structure

```
lib/games/chromix/
├── models/
│   ├── models.dart               # barrel
│   ├── chromix_color.dart        # ChromixColor enum (6 colors + isPrimary/isSecondary)
│   ├── chromix_cell.dart         # Sealed class: EmptyCell, ColorCell, BlockerCell
│   ├── chromix_grid.dart         # 4x4 grid model with color distribution
│   └── move_record.dart          # Undo stack entry (cellIndex + previousCell)
├── logic/
│   ├── logic.dart                # barrel
│   ├── color_mixer.dart          # RYB mixing rules
│   ├── puzzle_solver.dart        # Backtracking solver — uniqueness + optimal moves
│   ├── puzzle_generator.dart     # Deterministic generation from seed
│   └── score_calculator.dart     # Raw score + star rating
```

### Design Decisions (from review)

Several simplifications were applied based on technical review:

- **Single `ChromixColor` enum** instead of separate `PrimaryColor`/`SecondaryColor` enums + union. Six values with `isPrimary`/`isSecondary` getters. Simpler map keys, no type gymnastics.
- **Three-variant sealed `ChromixCell`** (`EmptyCell`, `ColorCell`, `BlockerCell`) instead of four. Locked status derived from `color.isSecondary`. Matches Signal's three-variant complexity.
- **No `ColorTarget` class** — target stored as `Map<ChromixColor, int>` directly. Equality checked via `mapEquals` or Equatable list comparison.
- **Score calculator as top-level functions** instead of a class — `score(int moves, int undos)` returns `moves + undos`, `stars(int score, int optimal)` returns 1–3. Too trivial for a class.

### Tasks

#### Models (`lib/games/chromix/models/`)

- [ ] `ChromixColor` enum — 6 values: `red`, `yellow`, `blue`, `orange`, `green`, `purple`. Getters: `isPrimary` (R/Y/B), `isSecondary` (O/G/P). Must work as `Map` keys with proper equality (enums have this built-in) — `chromix_color.dart`
- [ ] `ChromixCell` — sealed class with three variants — `chromix_cell.dart`:
  - `EmptyCell` — unfilled cell, can receive a primary
  - `ColorCell(ChromixColor color, {bool isPreFilled = false})` — holds a color. Locked if `color.isSecondary`. Pre-filled primaries can be layered on. All immutable with `==`/`hashCode` overrides
  - `BlockerCell` — black blocker, locked, excluded from color distribution
- [ ] `ChromixGrid` — 4x4 grid of `ChromixCell` in flat row-major list — `chromix_grid.dart`:
  - `cellAt(int row, int col)`, `setCell(int row, int col, ChromixCell cell)`
  - `colorDistribution` → `Map<ChromixColor, int>` counting colors of all `ColorCell`s (excludes `EmptyCell` and `BlockerCell`)
  - `isFullyFilled` → true when no `EmptyCell` exists among non-blocker cells AND no `ColorCell` with a primary color that is not pre-filled exists that hasn't been layered. Actually simpler: true when every non-blocker cell is a `ColorCell`
  - `nonBlockerCount` → number of cells that are not `BlockerCell`
  - Immutable with Equatable
- [ ] `MoveRecord` — undo stack entry: `int cellIndex` + `ChromixCell previousCell`. Stores the full previous cell state for clean reversal. Immutable with Equatable — `move_record.dart`
- [ ] `models.dart` barrel file — exports all model files alphabetically

#### Logic (`lib/games/chromix/logic/`)

- [ ] `ColorMixer` — static method `mix(ChromixColor a, ChromixColor b)` → `ChromixColor?` — `color_mixer.dart`:
  - `red + yellow → orange`, `red + blue → purple`, `yellow + blue → green` (and reverses)
  - Returns `null` for same-color pairs or if either input is secondary
  - Pure function, no state
- [ ] `PuzzleSolver` — backtracking solver for uniqueness verification — `puzzle_solver.dart`:
  - Takes a `ChromixGrid` (with pre-filled cells and empty cells) and a target `Map<ChromixColor, int>`
  - Decision tree: for each empty cell, try placing each of 3 primaries. For each pre-filled primary cell that is layerable, try layering each of the 2 other primaries OR leaving it as-is
  - Prunes branches early when any color count exceeds the target
  - Returns: `({bool isUnique, int optimalMoves})` — `isUnique` is true if exactly one assignment matches the target; `optimalMoves` is the minimum placements for that unique solution
  - **Important test case**: boards with multiple valid solutions must be correctly rejected
- [ ] `PuzzleGenerator` — deterministic from seed — `puzzle_generator.dart`:
  - `static ({ChromixGrid puzzle, Map<ChromixColor, int> target, int optimalMoves}) generate(int seed)`
  - Algorithm (build-then-peel-back):
    1. `Random(seed.abs())` for all randomness
    2. Place 1–4 black blockers at random positions
    3. Fill remaining cells with a valid complete color arrangement (primaries + secondaries following mixing rules, ensuring the board is reachable through legal moves)
    4. Compute the target distribution from this complete board
    5. Select 5–9 cells to keep as pre-filled (mix of primaries, secondaries, blockers)
    6. Remove remaining cells (revert secondaries to a constituent primary or to empty)
    7. Run `PuzzleSolver` to verify unique solution
    8. If not unique, increment seed by 1 and retry (max 10 retries, then use last valid attempt)
  - Same seed always produces same puzzle (determinism is critical)
- [ ] Score functions (top-level in `score_calculator.dart`):
  - `int chromixScore(int moves, int undos)` → `moves + undos`
  - `int chromixStars(int score, int optimalMoves)` → 3 if `score <= optimalMoves`, 2 if `score <= optimalMoves + 3`, else 1
- [ ] `logic.dart` barrel file

#### Serialization Helpers

The cubit (Part 2) will need to serialize `ChromixCell` for session persistence. To keep serialization co-located with models:

- [ ] Add `toJson()` on `ChromixCell` variants and a static `ChromixCell.fromJson(Map<String, dynamic>)` factory — `chromix_cell.dart`:
  - `EmptyCell` → `{'type': 'empty'}`
  - `ColorCell` → `{'type': 'color', 'color': color.name, 'isPreFilled': isPreFilled}`
  - `BlockerCell` → `{'type': 'blocker'}`
- [ ] Add `toJson()` on `MoveRecord` and a `MoveRecord.fromJson()` factory — `move_record.dart`:
  - `{'cellIndex': cellIndex, 'previousCell': previousCell.toJson()}`

#### Tests

- [ ] Unit tests for `ChromixColor` — `isPrimary`/`isSecondary` for all 6 values
- [ ] Unit tests for `ChromixCell` — equality, `isPreFilled` behavior, `ColorCell` locked derivation
- [ ] Unit tests for `ChromixGrid` — `cellAt`, `setCell`, `colorDistribution` (various board states), `isFullyFilled`, `nonBlockerCount`
- [ ] Unit tests for `MoveRecord` — equality, round-trip serialization
- [ ] Unit tests for `ColorMixer` — all 6 valid mixing pairs, same-color returns null, secondary inputs return null
- [ ] Unit tests for `PuzzleSolver`:
  - Board with unique solution → `isUnique: true`, correct `optimalMoves`
  - Board with multiple solutions → `isUnique: false`
  - Board with no solution → `isUnique: false`
  - Pre-filled primary layering decisions are explored
- [ ] Unit tests for `PuzzleGenerator`:
  - **Determinism**: same seed produces identical puzzle across runs
  - Generated puzzles always have unique solutions
  - Pre-filled count is within 5–9 range
  - Blocker count is within 1–4 range
  - Target distribution matches non-blocker cell count
- [ ] Unit tests for score functions — boundary values, optimal score, star thresholds
- [ ] Serialization round-trip tests for `ChromixCell.toJson/fromJson` and `MoveRecord.toJson/fromJson`
- [ ] All tests mirror `lib/` structure under `test/games/chromix/`

## Technical Considerations

### Solver Search Space

For a 4x4 grid with ~7–11 decision cells, each having 3 possible states (primaries for empty cells, 2 other primaries + leave-as-is for layerable pre-filled cells), worst case is ~3^11 ≈ 177K states. With pruning (early termination when any color count exceeds target), this should complete in under 50ms on the main thread. No `compute()` isolate needed.

### Generator Strategy

The "build-then-peel-back" approach is standard for constraint-satisfaction puzzle generation. Key insight: the complete solution defines the target, and peeling back cells creates the puzzle. The solver then verifies that the peeled-back puzzle has exactly one way to reach that target.

### Mixing Rule Clarity

RYB subtractive mixing (paint model): Red+Yellow=Orange, Red+Blue=Purple, Yellow+Blue=Green. Only primaries can be mixed. Mixing the same color is a no-op. Mixing a secondary with anything is not allowed (secondaries are locked).

## Acceptance Criteria

- [ ] `ChromixColor` enum has 6 values with correct `isPrimary`/`isSecondary`
- [ ] `ChromixCell` sealed class has 3 variants with proper equality
- [ ] `ChromixGrid.colorDistribution` correctly counts colors excluding blockers and empty cells
- [ ] `ChromixGrid.isFullyFilled` returns true only when all non-blocker cells are `ColorCell`
- [ ] `ColorMixer.mix()` correctly implements all 3 RYB mixing pairs and returns null for invalid inputs
- [ ] `PuzzleSolver` verifies uniqueness — rejects boards with 0 or 2+ solutions
- [ ] `PuzzleSolver` returns correct optimal move count for the unique solution
- [ ] `PuzzleGenerator.generate(seed)` is fully deterministic
- [ ] Generated puzzles always have unique solutions verified by the solver
- [ ] Score = `moves + undos`, stars use optimal + 3 thresholds
- [ ] `ChromixCell` and `MoveRecord` serialize/deserialize without data loss
- [ ] All tests pass with `very_good_analysis` v7.0.0

## Dependencies

- None — this is the first PR in the sequence.

## References

- Signal cell model pattern: [cell.dart](lib/games/signal/models/cell.dart)
- Signal grid model: [grid.dart](lib/games/signal/models/grid.dart)
- Signal puzzle generator + solver: [puzzle_generator.dart](lib/games/signal/logic/puzzle_generator.dart)
- Signal score calculator: [score_calculator.dart](lib/games/signal/logic/score_calculator.dart)
- Daily seed: [daily_seed.dart](lib/core/daily_seed/daily_seed.dart)
- Brainstorm: [2026-04-07-chromix-game-brainstorm-doc.md](docs/brainstorm/2026-04-07-chromix-game-brainstorm-doc.md)
- Parent plan: [2026-04-07-feat-chromix-color-mixing-puzzle-plan.md](docs/plan/2026-04-07-feat-chromix-color-mixing-puzzle-plan.md)
