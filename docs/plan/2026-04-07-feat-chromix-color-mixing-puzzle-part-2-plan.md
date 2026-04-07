---
title: "feat(chromix): add cubit, UI widgets, page wiring, and game registration"
type: feat
date: 2026-04-07
---

## feat(chromix): add cubit, UI widgets, page wiring, and game registration

## Overview

Build the state management, Flutter UI, and game registration for Chromix on top of the Part 1 foundation (models + logic). After this PR merges, Chromix is fully playable from the hub: players can select colors, place them on the grid, undo moves, match the target color bar, see results, and share to Nostr.

## Problem Statement / Motivation

Part 1 established all pure-Dart game logic. This PR wires it into the app: cubit for state management with undo and session persistence, visual widgets for the grid/palette/color bars, game registration in the hub, and Nostr sharing integration.

## Proposed Solution

### Directory Structure

```
lib/games/chromix/
├── chromix_game.dart               # GameDefinition implementation
├── cubit/
│   ├── cubit.dart                  # barrel
│   ├── chromix_cubit.dart          # Game state management
│   └── chromix_state.dart          # part of chromix_cubit.dart
├── view/
│   ├── view.dart                   # barrel
│   ├── chromix_page.dart           # Top-level page (BlocProviders)
│   └── widgets/
│       ├── widgets.dart            # barrel
│       ├── chromix_grid.dart       # 4x4 grid widget
│       ├── chromix_cell_widget.dart # Individual cell rendering
│       ├── color_palette.dart      # R/Y/B selector row
│       ├── color_bar.dart          # Proportional color bar
│       ├── chromix_results_overlay.dart  # Results on win
│       └── instructions_dialog.dart     # How-to-play modal
└── theme/
    ├── theme.dart                  # barrel
    └── chromix_colors.dart         # Game-specific color palette
```

### Tasks

#### State Management (`lib/games/chromix/cubit/`)

- [ ] `ChromixState` (using `part of 'chromix_cubit.dart'` convention) — `chromix_state.dart`:
  - `ChromixGrid grid` — current board state
  - `Map<ChromixColor, int> target` — target color distribution
  - `int moveCount` — total placements (never decremented on undo)
  - `int undoCount` — total undo presses
  - `List<MoveRecord> moveHistory` — undo stack
  - `ChromixColor selectedColor` — currently selected primary (default: `ChromixColor.red`)
  - `ChromixStatus status` — enum: `loading`, `playing`, `won`
  - `int? score` — computed on win (moves + undos)
  - `int optimalMoves` — from generator, for star calculation
  - Computed getters: `currentDistribution` (delegates to `grid.colorDistribution`), `int stars` (from score functions)
  - `copyWith` with `int? Function()? score` wrapper for nullable field
  - Equatable props
  - `ChromixState.loading()` factory for initial state
- [ ] `ChromixCubit` — `chromix_cubit.dart`:
  - Constructor takes `dailySeed`, `dateKey`, optional `GameStorageRepository`
  - `_initialize()`: generate puzzle (main thread), check for persisted session, emit playing state
  - `selectColor(ChromixColor color)` — updates selected color (must be primary, else no-op)
  - `placeColor(int row, int col)` — core action:
    1. Validate: status is `playing`, target cell accepts placement
    2. If cell is `EmptyCell`: place `ColorCell(selectedColor)`, push `MoveRecord`, increment `moveCount`
    3. If cell is `ColorCell` with a primary color different from selected: mix via `ColorMixer.mix()`, replace with `ColorCell(secondaryColor)`, push `MoveRecord`, increment `moveCount`
    4. Same color or locked cell: no-op
    5. Check win: `grid.isFullyFilled && mapEquals(grid.colorDistribution, target)`
    6. On win: compute score, emit won state, clear session, persist streak
    7. On non-win: persist session
  - `undo()` — pop last `MoveRecord`, restore `previousCell` at `cellIndex`, increment `undoCount`. No-op if history empty. Persist session.
  - `resetWithSeed(int seed)` — debug only, generates new puzzle
  - Session persistence:
    - Key: `chromix_state_{dateKey}`
    - Serialize: grid cells (via `ChromixCell.toJson`), moveCount, undoCount, moveHistory (via `MoveRecord.toJson`), selectedColor
    - Deserialize on init: validate cell count matches grid, discard corrupted data
    - Clear on win
- [ ] `cubit.dart` barrel file
- [ ] Unit tests with `bloc_test`:
  - `selectColor` changes selected color
  - `placeColor` on empty cell: places primary, increments moveCount
  - `placeColor` on primary cell with different color: creates secondary, increments moveCount
  - `placeColor` same color: no-op, moveCount unchanged
  - `placeColor` on locked cell: no-op
  - `undo` reverts last move, increments undoCount, moveCount unchanged
  - `undo` on empty history: no-op
  - Win detection: all non-blockers filled and distribution matches target
  - Session persistence: save and restore round-trip (including moveHistory)
  - Corrupted session: gracefully discards and starts fresh

#### Theme (`lib/games/chromix/theme/`)

- [ ] `ChromixColors` — static color constants for all game colors — `chromix_colors.dart`:
  - Red, Yellow, Blue (primaries)
  - Orange, Green, Purple (secondaries)
  - Black (blocker), light gray (empty cell)
  - Selected color highlight ring color
  - Colors should be accessible — sufficient contrast against white/dark backgrounds
- [ ] `theme.dart` barrel file

#### UI Widgets (`lib/games/chromix/view/widgets/`)

- [ ] `ChromixCellWidget` — renders a single cell — `chromix_cell_widget.dart`:
  - `ColorCell`: filled rectangle with the cell's color + **letter label** (R, Y, B, O, G, P) for accessibility
  - Pre-filled cells: subtle dot or inset border to distinguish from player-placed
  - `BlockerCell`: black fill with no label
  - `EmptyCell`: light gray fill
  - Tap handler calls `cubit.placeColor(row, col)`
- [ ] `ChromixGrid` — 4x4 `GridView` of `ChromixCellWidget`s — `chromix_grid.dart`:
  - `BlocBuilder<ChromixCubit, ChromixState>` rebuilds on grid changes
  - Aspect ratio 1:1 for square cells
- [ ] `ColorPalette` — horizontal row of 3 primary color buttons — `color_palette.dart`:
  - Each button shows the color fill + label (Red, Yellow, Blue)
  - Selected color has a highlight ring/border
  - Tap calls `cubit.selectColor(color)`
  - `BlocSelector` on `selectedColor` for efficient rebuilds
- [ ] `ColorBar` — proportional horizontal bar of colored segments — `color_bar.dart`:
  - Takes `Map<ChromixColor, int>` and renders proportional segments
  - Reusable: used for both target (static) and current (live-updating) bars
  - Empty segments for colors with count 0 (not rendered)
  - Segments labeled with count numbers inside if space allows
- [ ] `ChromixInstructionsDialog` — how-to-play modal — `instructions_dialog.dart`:
  - Explains: RYB mixing rules with visual examples (R+Y=O, R+B=P, Y+B=G)
  - Explains: select a color, tap to place, layer to mix, undo, match the target bar
  - "Got it!" dismiss button
  - Static `show(BuildContext context)` method
- [ ] `ChromixResultsOverlay` — results on win — `chromix_results_overlay.dart`:
  - Score display (moves + undos breakdown: "12 total — 10 moves, 2 undos")
  - `StarRating` widget (shared)
  - `ShareResultButton` (shared) — triggers `ResultSharingCubit`
  - `CommunityStatsSection` (shared)
  - Leaderboard section
  - "View Puzzle" button → hides overlay, shows solved board read-only
  - "Back to Hub" button → `context.go('/')`
- [ ] `widgets.dart` barrel file
- [ ] Widget tests for all widgets:
  - `ChromixCellWidget`: renders correct color, letter label, handles taps
  - `ChromixGrid`: renders 16 cells, tap forwarding
  - `ColorPalette`: 3 buttons, selection highlight, tap forwarding
  - `ColorBar`: proportional rendering for various distributions
  - `ChromixResultsOverlay`: displays score, stars, action buttons
  - `ChromixInstructionsDialog`: displays and dismisses

#### Page Wiring (`lib/games/chromix/view/`)

- [ ] `ChromixPage` — top-level page — `chromix_page.dart`:
  - `MultiBlocProvider` with:
    - `ChromixCubit(dailySeed, dateKey, storageRepository)`
    - `ResultSharingCubit(identityRepository, publishRepository)`
    - `CommunityStatsCubit(statsRepository)`
    - `LeaderboardCubit(statsRepository, identityRepository)`
    - `ProfileCubit(profileRepository, identityRepository)`
  - Body layout (in `_ChromixView` StatefulWidget):
    - AppBar: title "Chromix", debug shuffle button (`kDebugMode`), info button (instructions)
    - `ResultSharingListener` wrapping the body (snackbar on share success/failure)
    - Target `ColorBar` labeled "Target"
    - Current `ColorBar` labeled "Current" (updates live via `BlocBuilder`)
    - `ChromixGrid` (expanded)
    - `ColorPalette`
    - Undo button + move/undo counters ("10 moves · 2 undos")
    - On win: `Stack` with `ChromixResultsOverlay` (toggleable via "View Puzzle" / "Results" FAB, same pattern as Signal)
  - First-visit instructions: `GameStorageRepository.hasSeenInstructions('chromix')` → `ChromixInstructionsDialog.show()` → `markInstructionsSeen('chromix')`
  - On win listener: persist streak, fetch community stats for `chromix:{dateKey}`
- [ ] `view.dart` barrel file

#### Game Registration

- [ ] `ChromixGame extends GameDefinition` — `chromix_game.dart`:
  - `id`: `'chromix'`
  - `name`: `'Chromix'`
  - `description`: `'Mix colors to match the target in a daily puzzle'`
  - `icon`: `Icons.palette`
  - `routePath`: `'/games/chromix'`
  - Route builder: create `ChromixPage` with `DailySeed.today()` as `dailySeed`
- [ ] Register `ChromixGame` in `GameRegistry` in `main.dart`

#### Nostr Sharing

- [ ] `EventBuilder.buildChromixResult()` in `lib/nostr/sharing/event_builder.dart`:
  - d-tag: `chromix:YYYY-MM-DD`
  - Tags: `['t', 'vgg']`, `['t', 'chromix']`, `['L', 'games.vgg.score']`, `['l', 'score-N', 'games.vgg.score']`, `['l', 'stars-N', 'games.vgg.score']`, `['l', 'moves-N', 'games.vgg.score']`, `['l', 'undos-N', 'games.vgg.score']`
  - Content: `🎨 Very Good Games — Chromix\n🎯 {stars} Stars · ⭐{starEmoji}\n🧩 {score} total ({moves} moves, {undos} undos)\n\n{date}`
  - Puzzle number: days since 2026-04-07 (launch epoch) + 1
- [ ] Tests for `buildChromixResult` — verify tags, content format, d-tag

## Technical Considerations

### Undo Stack Persistence

The move history is serialized as a JSON array of `MoveRecord.toJson()` objects. Each entry is ~50 bytes. On a 4x4 grid, even heavy undo usage produces a small payload. No cap needed — the natural bound is that players solve or quit before history grows large.

### Session Restore Flow

On cubit creation: generate puzzle from seed (deterministic) → check `GameStorageRepository.getSession(key)` → if found, deserialize cells + moveCount + undoCount + moveHistory + selectedColor → validate cell count matches → emit restored state. If deserialization fails, discard and start fresh. Same pattern as `SignalCubit._initialize`.

### Returning to Completed Puzzle

Session is cleared on win. On return, no session found → cubit generates the puzzle and emits `playing` state. But the hub shows "completed" via streak check. The page should check streak status and, if completed today, immediately show the results overlay. Implementation: check `getDailyStatus()` in the view's `initState`, and if completed, set `_showResults = true` with a pre-computed "you already completed this" state.

**Simpler alternative**: persist a minimal completion record (score, stars, moves, undos) alongside the streak, and restore from that. This avoids re-generating the puzzle just to show the overlay.

### Content String for Nostr Sharing

The score is `moves + undos`, so the sharing content explicitly breaks it down: "12 total (10 moves, 2 undos)" rather than misleadingly calling the composite number "moves."

## Acceptance Criteria

### Functional Requirements

- [ ] Player can select Red, Yellow, or Blue from the color palette
- [ ] Tapping an empty cell places the selected primary
- [ ] Tapping a primary cell with a different primary creates the correct secondary (RYB)
- [ ] Tapping a same-color or locked cell is a no-op
- [ ] Undo reverses the last action; undoCount increments; moveCount unchanged
- [ ] Target and current color bars displayed above the grid, current updates live
- [ ] Win detected when all non-blockers filled and distribution matches target
- [ ] Results overlay shows score breakdown ("X total — Y moves, Z undos"), stars, share, community stats
- [ ] Nostr sharing with correct content format and tags
- [ ] Session persists across app restarts (including undo history and selected color)
- [ ] Returning to a completed puzzle shows results overlay
- [ ] Instructions dialog on first play; accessible via AppBar info button
- [ ] Game tile appears on hub with daily status badge and streak
- [ ] Debug shuffle button gated by `kDebugMode`
- [ ] Cell letter labels (R, Y, B, O, G, P) for color-blind accessibility

### Non-Functional Requirements

- [ ] Grid interaction smooth at 60fps
- [ ] Color bar updates within a single frame after each move

### Quality Gates

- [ ] Unit tests for cubit (all actions, win detection, persistence round-trip)
- [ ] Widget tests for all view components
- [ ] Tests mirror `lib/` structure 1:1 under `test/`
- [ ] All tests pass with `very_good_analysis` v7.0.0
- [ ] Existing Signal and Guess the Number tests still pass

## Dependencies

- **Part 1 must merge first**: [2026-04-07-feat-chromix-color-mixing-puzzle-part-1-plan.md](docs/plan/2026-04-07-feat-chromix-color-mixing-puzzle-part-1-plan.md) — provides all models and logic this PR consumes.

## References

- Signal cubit pattern: [signal_cubit.dart](lib/games/signal/cubit/signal_cubit.dart)
- Signal state pattern: [signal_state.dart](lib/games/signal/cubit/signal_state.dart)
- Signal page (MultiBlocProvider wiring): [signal_page.dart](lib/games/signal/view/signal_page.dart)
- Signal results overlay: [signal_results_overlay.dart](lib/games/signal/view/widgets/signal_results_overlay.dart)
- Signal game definition: [signal_game.dart](lib/games/signal/signal_game.dart)
- Event builder (add new method): [event_builder.dart](lib/nostr/sharing/event_builder.dart)
- Game registry in main: [main.dart](lib/main.dart)
- Storage repository: [game_storage_repository.dart](lib/core/storage/game_storage_repository.dart)
- Brainstorm: [2026-04-07-chromix-game-brainstorm-doc.md](docs/brainstorm/2026-04-07-chromix-game-brainstorm-doc.md)
- Parent plan: [2026-04-07-feat-chromix-color-mixing-puzzle-plan.md](docs/plan/2026-04-07-feat-chromix-color-mixing-puzzle-plan.md)
