---
title: "feat: add Chromix color-mixing puzzle game"
type: feat
date: 2026-04-07
---

## feat: add Chromix color-mixing puzzle game

> **Note:** This plan has been split into parts. See the `-part-1` and `-part-2` files in this directory.

## Overview

Add a third daily game to the hub: **Chromix**, a color-mixing grid puzzle where players place primary colors (Red, Yellow, Blue) on a 4x4 board to match a target color distribution. The board starts with pre-filled cells — primaries (layerable), secondaries (locked), and black blockers (locked). Players create secondary colors (Orange, Green, Purple) by layering one primary onto another. The goal is to make the board's color ratio match a target color bar using as few moves (placements + undos) as possible.

The game follows all existing patterns: `GameDefinition`, `DailySeed`, `flutter_bloc` (Cubit), `GameStorageRepository`, and shared Nostr result-sharing UI.

## Problem Statement / Motivation

The hub has two games (Guess the Number, Signal). Chromix adds a visual/creative puzzle that complements the spatial logic of Signal and the deduction of Guess the Number. The RYB color-mixing mechanic is intuitive, language-independent, and distinctive enough to stand on its own. The 4x4 grid targets under 5 minutes of play time.

## Proposed Solution

### Interaction Model

**Color palette**: A horizontal row of three tappable color buttons (Red, Yellow, Blue) displayed below the grid. The selected color is highlighted with a border/ring. Default selection: Red (first in row).

**Placing**: Tap an empty cell to place the selected primary. Tap a cell containing a *different* primary (player-placed or pre-filled) to layer, creating a secondary (locked). Tapping a cell that already contains the *same* primary as selected is a **no-op** (no move counted). Tapping a locked cell (secondary, black blocker) is a no-op.

**Undo**: Tap the undo button to reverse the last action. Layered cells revert to their original primary (still layerable). Filled empty cells revert to empty. Each undo increments the undo counter. Move count is **not** decremented on undo — moves and undos are tracked separately. Undo stack is empty initially and after all moves have been undone.

**No redo** in v1. Making a new move after undoing clears any conceptual redo stack (there isn't one).

### Win Condition

The board's color distribution among **non-blocker cells** must exactly match the target counts. Every non-blocker cell must be filled (no empty cells remaining). Black blockers are excluded from the distribution. The target specifies exact counts of each color present (e.g., 3 Red, 2 Orange, 4 Blue, 1 Green, etc. across 12 non-blocker cells on a board with 4 blockers).

### Scoring

- **Raw score** = total placements + total undos (lower is better)
- No points transformation (unlike Signal's 500-budget system)
- **3 stars** = score <= optimal move count (zero undos, minimum placements)
- **2 stars** = score <= optimal + 3
- **1 star** = puzzle completed (any score)
- The optimal move count is determined by the solver as the minimum placements needed for the unique solution

### Target Display

Two color bars shown above the grid:
- **Target bar**: the goal distribution (static)
- **Current bar**: the board's live color distribution (updates on every move)

Both use proportional colored segments. This gives the player real-time feedback without needing to mentally count board colors.

### Returning to a Completed Puzzle

Show the results overlay immediately (score, stars, share button, community stats). A "View Puzzle" button reveals the solved board in read-only state. This is consistent with the hub showing a "completed" badge.

### Architecture

```
lib/games/chromix/
├── chromix_game.dart               # GameDefinition implementation
├── models/
│   ├── models.dart                 # barrel
│   ├── chromix_cell.dart           # Cell sealed class (empty, primary, secondary, blocker)
│   ├── chromix_color.dart          # PrimaryColor enum (red, yellow, blue), SecondaryColor enum, ChromixColor union
│   ├── chromix_grid.dart           # Grid model (4x4, flat cell list, setCell, colorDistribution)
│   ├── color_target.dart           # Target color counts
│   └── move_record.dart            # Undo stack entry (cellIndex, previousCell)
├── logic/
│   ├── logic.dart                  # barrel
│   ├── color_mixer.dart            # RYB mixing rules (primary + primary → secondary)
│   ├── puzzle_generator.dart       # Deterministic generation from seed + solver verification
│   ├── puzzle_solver.dart          # Backtracking solver — verifies unique solution, finds optimal moves
│   └── score_calculator.dart       # Raw score + star rating
├── cubit/
│   ├── chromix_cubit.dart          # Game state management (place, undo, win detection)
│   └── chromix_state.dart          # State: grid, target, moveCount, undoCount, moveHistory, status
├── view/
│   ├── view.dart                   # barrel
│   ├── chromix_page.dart           # Top-level page (BlocProviders)
│   └── widgets/
│       ├── widgets.dart            # barrel
│       ├── chromix_grid.dart       # Grid widget rendering 4x4 colored cells
│       ├── chromix_cell.dart       # Individual cell (color fill + letter label for accessibility)
│       ├── color_palette.dart      # R/Y/B selector row
│       ├── color_bar.dart          # Proportional color bar (reused for target + current)
│       ├── chromix_results_overlay.dart  # Results on win
│       └── instructions_dialog.dart     # How-to-play modal
└── theme/
    └── chromix_colors.dart         # Game-specific color palette (R, Y, B, O, G, P, black, empty)
```

### Implementation Phases

#### Phase 1: Core Models and Color Logic

Foundation layer — pure Dart, no Flutter dependency. Fully testable in isolation.

- [ ] `PrimaryColor` enum (`red`, `yellow`, `blue`) and `SecondaryColor` enum (`orange`, `green`, `purple`) — `lib/games/chromix/models/chromix_color.dart`
- [ ] `ColorMixer` — pure static function: `SecondaryColor mix(PrimaryColor a, PrimaryColor b)`. Defines the 3 RYB mixing rules. Returns `null` for same-color pairs — `lib/games/chromix/logic/color_mixer.dart`
- [ ] `ChromixCell` sealed class — `EmptyCell`, `PrimaryCell(color, isPreFilled)`, `SecondaryCell(color, isPreFilled)`, `BlockerCell`. All immutable with Equatable — `lib/games/chromix/models/chromix_cell.dart`
- [ ] `ChromixGrid` — 4x4 grid of `ChromixCell`, `cellAt(row, col)`, `setCell(row, col, cell)`, `colorDistribution` (returns `Map<ChromixColor, int>` counting non-blocker filled cells), `isFullyFilled` (all non-blocker cells have a color) — `lib/games/chromix/models/chromix_grid.dart`
- [ ] `ColorTarget` — target color counts as `Map<ChromixColor, int>`, with `matches(Map<ChromixColor, int> current)` — `lib/games/chromix/models/color_target.dart`
- [ ] `MoveRecord` — `cellIndex` + `previousCell` (the cell state before the move) — `lib/games/chromix/models/move_record.dart`
- [ ] Unit tests for all models and color mixer

#### Phase 2: Puzzle Generation and Solver

- [ ] `PuzzleSolver` — backtracking solver that:
  1. Takes a grid with pre-filled cells and empty cells
  2. Tries assigning primaries to empty cells and evaluating mixing on layerable primaries
  3. Verifies exactly one assignment produces the target distribution
  4. Returns the optimal move count (minimum placements)
  - File: `lib/games/chromix/logic/puzzle_solver.dart`
- [ ] `PuzzleGenerator` — deterministic from seed:
  1. Use `Random(seed.abs())` for all randomness
  2. Place 1–4 black blockers at random positions
  3. Build a random valid solution (fill remaining cells with primaries/secondaries following mixing rules)
  4. Derive the target distribution from the solution
  5. Remove player-placeable cells to create the puzzle (keep 5–9 pre-filled cells)
  6. Run `PuzzleSolver` to verify unique solution
  7. If not unique or generation fails, advance seed by 1 and retry (bounded retries)
  - File: `lib/games/chromix/logic/puzzle_generator.dart`
  - Returns: `({ChromixGrid puzzle, ColorTarget target, int optimalMoves})`
- [ ] `ChromixScoreCalculator` — `score(int moves, int undos) → int` returns `moves + undos`. `stars(int score, int optimal) → int` applies threshold logic — `lib/games/chromix/logic/score_calculator.dart`
- [ ] Unit tests: solver correctness, generator determinism (same seed = same puzzle), score/star calculations

#### Phase 3: State Management (Cubit)

- [ ] `ChromixState` — immutable state: `grid`, `target`, `moveCount`, `undoCount`, `moveHistory` (List<MoveRecord>), `selectedColor` (PrimaryColor), `status` (loading/playing/won), `score`, `optimalMoves` — `lib/games/chromix/cubit/chromix_state.dart`
- [ ] `ChromixCubit`:
  - `selectColor(PrimaryColor)` — updates selected color
  - `placeColor(int row, int col)` — places selected color on empty cell, or layers on primary cell. Validates: not locked, not same color. Pushes `MoveRecord` to history. Increments `moveCount`. Checks win.
  - `undo()` — pops last `MoveRecord`, restores previous cell state, increments `undoCount`. No-op if history empty.
  - Win detection: `grid.isFullyFilled && target.matches(grid.colorDistribution)`
  - On win: compute score, emit won state, clear session, persist streak
  - On every move/undo (while playing): persist session
  - File: `lib/games/chromix/cubit/chromix_cubit.dart`
- [ ] Puzzle generation: run on main thread first (4x4 is small). Add `compute()` isolate only if profiling shows jank.
- [ ] State persistence — session key: `chromix_state_YYYY-MM-DD`. Persist: cell states, moveCount, undoCount, moveHistory, selectedColor. Restore on cubit creation. Clear on win.
- [ ] Unit tests with `bloc_test` for all cubit behaviors (place, layer, undo, win, persistence restore)

#### Phase 4: UI — Grid, Palette, and Color Bars

- [ ] `ChromixColors` — theme constants for all 6 colors + black + empty — `lib/games/chromix/theme/chromix_colors.dart`
- [ ] `ChromixCell` widget — renders cell color fill with a **letter label** (R, Y, B, O, G, P) for accessibility. Pre-filled cells have a subtle dot/marker. Locked cells have a lock icon or reduced opacity border — `lib/games/chromix/view/widgets/chromix_cell.dart`
- [ ] `ChromixGrid` widget — 4x4 `GridView` of `ChromixCell` widgets. Tap handler calls `cubit.placeColor(row, col)` — `lib/games/chromix/view/widgets/chromix_grid.dart`
- [ ] `ColorPalette` widget — horizontal row of 3 primary color buttons. Selected color has a highlight ring. Tap calls `cubit.selectColor(color)` — `lib/games/chromix/view/widgets/color_palette.dart`
- [ ] `ColorBar` widget — proportional horizontal bar of colored segments. Takes a `Map<ChromixColor, int>`. Used for both target and current bars — `lib/games/chromix/view/widgets/color_bar.dart`
- [ ] `InstructionsDialog` — explains RYB mixing, placing, layering, undo, and goal. Simple diagram showing mixing examples (R+Y=O, R+B=P, Y+B=G) — `lib/games/chromix/view/widgets/instructions_dialog.dart`
- [ ] Widget tests for grid, cell, palette, color bar, and instructions dialog

#### Phase 5: Page Wiring and Game Registration

- [ ] `ChromixPage` — top-level `MultiBlocProvider` page with `ChromixCubit`, `ResultSharingCubit`, `CommunityStatsCubit`, `LeaderboardCubit`, `ProfileCubit`. Shows loading indicator during generation — `lib/games/chromix/view/chromix_page.dart`
- [ ] Layout: AppBar ("Chromix") → target bar + current bar → grid → color palette + undo button + move/undo counters → results overlay on win
- [ ] `ChromixResultsOverlay` — score, stars (`StarRating`), move/undo breakdown, share button (`ShareResultButton`), community stats (`CommunityStatsSection`), leaderboard, "View Puzzle" / "Back to Hub" — `lib/games/chromix/view/widgets/chromix_results_overlay.dart`
- [ ] First-visit instructions dialog via `GameStorageRepository.hasSeenInstructions('chromix')`
- [ ] Debug shuffle button gated by `kDebugMode`
- [ ] `ChromixGame extends GameDefinition` — id: `chromix`, name: "Chromix", description: "Mix colors to match the target in a daily puzzle", icon: `Icons.palette`, routePath: `/games/chromix` — `lib/games/chromix/chromix_game.dart`
- [ ] Register `ChromixGame` in `GameRegistry` in `main.dart`
- [ ] `EventBuilder.buildChromixResult()` — d-tag: `chromix:YYYY-MM-DD`, tags: `['t', 'vgg']`, `['t', 'chromix']`, score/stars/moves labels. Content: `Chromix #{puzzleNumber} {starEmoji} — {score} moves` (stats only, no board spoiler)
- [ ] Puzzle number: days since a fixed epoch (e.g., 2026-04-07 = day 1)
- [ ] Integration tests / widget tests for page composition

## Technical Considerations

### Cell Model Complexity

Chromix cells are more complex than Signal's (empty/wall/tower). The `ChromixCell` sealed class has four variants, and `PrimaryCell` carries both a color and an `isPreFilled` flag that determines whether it can be layered on *again* after an undo. The undo system must restore the exact previous cell state — including `isPreFilled` — which is why `MoveRecord` stores the full `previousCell` rather than just a delta.

### Undo Stack and Persistence

This is **new infrastructure** not present in Signal or Guess the Number. The move history must be serialized with the session. Each `MoveRecord` is small (cell index + cell type enum + color enum), so serialization is straightforward. The undo stack is capped implicitly by board size (max ~16 entries for a 4x4 grid, though repeated place/undo cycles could grow it). Consider a reasonable cap (e.g., 100) to prevent unbounded growth in edge cases.

### Puzzle Generator Strategy

The generator must produce puzzles where:
1. Exactly one assignment of primaries to empty cells + layering decisions yields the target distribution
2. The puzzle is solvable (the target is achievable from the initial board)
3. Pre-filled cells include a mix of primaries, secondaries, and blockers for variety

Recommended approach: **build a complete solution first, then peel back**:
1. Fill a 4x4 grid with a valid color arrangement (primaries + secondaries following mixing rules)
2. Place 1–4 random blockers
3. Compute the target distribution from this complete board
4. Remove a subset of cells (making them empty or reverting secondaries to their constituent primary) to create the puzzle
5. Verify uniqueness with the solver; retry with advanced seed if not unique

### Solver Search Space

For a 4x4 grid with ~7–11 empty/layerable cells, each having 3–4 possible states (3 primaries for empty cells, potentially "leave as-is" or "layer with one of 2 other primaries" for pre-filled primaries), the worst case is roughly 4^11 ≈ 4M states. With pruning (early termination when a color count exceeds the target), this should be fast on the main thread. Profile before adding `compute()`.

### Accessibility

All cells include a letter label (R, Y, B, O, G, P) in addition to color fill, ensuring the game is playable by color-blind users. The color palette buttons also have text labels.

## Acceptance Criteria

### Functional Requirements

- [ ] Daily deterministic puzzle: same seed → same board for all players
- [ ] 4x4 grid with pre-filled primaries (layerable), pre-filled secondaries (locked), and black blockers (locked)
- [ ] Player selects a primary color from a 3-button palette, then taps cells to place
- [ ] Layering a different primary on a primary cell creates the correct secondary (RYB rules)
- [ ] Tapping a locked cell or placing the same color on a cell is a no-op
- [ ] Undo reverses the last action (layered → original primary, placed → empty). Undo count tracked separately
- [ ] Target color bar and live current color bar shown above the grid
- [ ] Win when all non-blocker cells are filled and color distribution exactly matches target
- [ ] Score = moves + undos (lower is better). Stars: 3 = optimal, 2 = optimal+3, 1 = completed
- [ ] Results overlay: score, stars, move/undo breakdown, share, community stats, leaderboard
- [ ] Nostr sharing: stats only, no board spoiler
- [ ] Puzzle state persists across app restarts (including undo history)
- [ ] Returning to completed puzzle shows results overlay immediately
- [ ] Instructions dialog on first play; accessible via AppBar info button
- [ ] Game registered in hub with daily status badge and streak

### Non-Functional Requirements

- [ ] Puzzle generation completes in under 200ms on main thread
- [ ] Grid interaction is smooth at 60fps
- [ ] Cell letter labels for accessibility (color-blind support)

### Quality Gates

- [ ] Unit tests for all models, logic (mixer, generator, solver, score), and cubit
- [ ] Widget tests for grid, cell, palette, color bar, overlays, and dialogs
- [ ] Tests mirror `lib/` structure 1:1 under `test/`
- [ ] All tests pass with `very_good_analysis` v7.0.0 lint rules
- [ ] Existing Signal and Guess the Number tests still pass

## Dependencies & Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Solver cannot verify uniqueness for all seeds | Some days have multiple solutions (ambiguous optimal) | Retry with advanced seed (bounded); tune pre-filled count to constrain solutions |
| Generation is too slow for complex board configurations | Bad first-load UX | Profile early; main thread first, `compute()` isolate as fallback |
| Undo stack persistence adds serialization complexity | Session restore bugs | Keep `MoveRecord` minimal (index + cell); test round-trip serialization |
| RYB mixing rules confuse players unfamiliar with paint mixing | Engagement drop-off | Instructions dialog with clear mixing examples; letter labels on cells |
| 4x4 grid is too small for interesting puzzles | Puzzles feel trivial | Generator tuning: vary pre-filled count (5–9), blocker count (1–4), and target complexity |
| Color-blind users cannot distinguish cells | Accessibility failure | Letter labels on all cells and palette buttons |

## Success Metrics

- Players complete the daily Chromix puzzle (completion rate target: 80%+)
- Average session time under 5 minutes
- 3-star rate around 20–30% (achievable with effort)
- Nostr sharing rate comparable to existing games

## References & Research

### Internal References

- Game registration pattern: [game_definition.dart](lib/core/game_registry/game_definition.dart)
- Signal game (closest pattern): [signal_game.dart](lib/games/signal/signal_game.dart)
- Signal models (sealed Cell class): [cell.dart](lib/games/signal/models/cell.dart)
- Signal grid model: [grid.dart](lib/games/signal/models/grid.dart)
- Signal puzzle generator + solver: [puzzle_generator.dart](lib/games/signal/logic/puzzle_generator.dart)
- Signal cubit (state persistence pattern): [signal_cubit.dart](lib/games/signal/cubit/signal_cubit.dart)
- Signal page (MultiBlocProvider wiring): [signal_page.dart](lib/games/signal/view/signal_page.dart)
- Score calculator pattern: [score_calculator.dart](lib/games/signal/logic/score_calculator.dart)
- Event builder (add new method): [event_builder.dart](lib/nostr/sharing/event_builder.dart)
- Daily seed: [daily_seed.dart](lib/core/daily_seed/daily_seed.dart)
- Date key utility: [date_key.dart](lib/core/daily_seed/date_key.dart)
- Storage repository: [game_storage_repository.dart](lib/core/storage/game_storage_repository.dart)

### Related Work

- Brainstorm document: [2026-04-07-chromix-game-brainstorm-doc.md](docs/brainstorm/2026-04-07-chromix-game-brainstorm-doc.md)
- I Love Hue — color-sorting puzzle with similar visual appeal
- RYB color wheel — subtractive color mixing model used in art education
