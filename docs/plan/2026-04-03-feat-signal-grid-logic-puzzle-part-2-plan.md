---
title: "feat(signal): add grid UI, game page, and hub registration"
type: feat
date: 2026-04-03
---

## feat(signal): add grid UI, game page, and hub registration

## Overview

Build the Flutter UI layer for the Signal game and wire it into the app hub. After this PR merges, Signal is fully playable: visible on the home screen, navigable, interactive, with results overlay, streak tracking, and Nostr sharing.

## Problem Statement / Motivation

Part 1 created the pure-Dart logic layer. This PR adds the visual experience — the grid with drag-to-paint interaction, signal path visualization, live tower feedback, and the results overlay.

## Proposed Solution

### Directory Structure

```
lib/games/signal/
├── signal_game.dart              # GameDefinition implementation
├── view/
│   ├── view.dart                 # barrel
│   ├── signal_page.dart          # Top-level page (BlocProviders, timer, lifecycle)
│   └── widgets/
│       ├── widgets.dart          # barrel
│       ├── signal_grid.dart      # Grid widget: cell rendering, signal paths, tap/drag gestures
│       ├── signal_cell.dart      # Individual cell: empty/wall/tower with indicator
│       ├── signal_results_overlay.dart  # Results on win
│       └── instructions_dialog.dart    # How-to-play modal
└── theme/
    └── signal_colors.dart        # Game-specific color palette
```

Note: signal path overlay, tower indicator, and move counter are folded into `signal_grid.dart` and `signal_cell.dart` rather than separate widgets, matching the density of the existing game's widget structure.

### Tasks

#### Game Definition (`lib/games/signal/signal_game.dart`)

- [ ] `SignalGame extends GameDefinition`:
  - `id`: `'signal'`
  - `name`: `'Signal'`
  - `description`: `'Block signals with walls in a daily logic puzzle'`
  - `icon`: `Icons.cell_tower`
  - `routePath`: `'/games/signal'`
  - `routes`: `GoRoute` with builder that creates `SignalPage` with daily seed
  - `getDailyStatus(date)`: check `GameStorageRepository` for today's completion
- [ ] Register `SignalGame` in `GameRegistry` in `main.dart`

#### Game Page (`lib/games/signal/view/signal_page.dart`)

- [ ] `SignalPage` — top-level `StatelessWidget` composing `MultiBlocProvider`:
  - `SignalCubit` — created with daily seed (puzzle generation happens in cubit constructor, per Part 1)
  - `ResultSharingCubit` — same pattern as Guess the Number
  - `CommunityStatsCubit` — same pattern as Guess the Number
- [ ] `_SignalView` — `StatefulWidget` managing:
  - First-play instructions check (`SharedPreferences` key `signal_seen_instructions`)
  - On win: persist streak via `GameStorageRepository`, fetch community stats via `CommunityStatsCubit.fetchStats('signal:$date')`

#### Grid Widget (`lib/games/signal/view/widgets/signal_grid.dart`)

- [ ] Renders the puzzle grid using `CustomPaint` or `GridView`
- [ ] **Cell rendering**: empty cells (light background), wall cells (dark/filled), tower cells (numbered circle with live signal count indicator)
- [ ] **Signal path visualization**: always-visible colored highlights extending from each tower in 4 cardinal directions, stopping at walls/edges. Rendered as part of the grid paint, not a separate overlay widget.
- [ ] **Tower indicator** (inline): shows `current/target` count on each tower, color-coded:
  - Green: satisfied (count == target)
  - Red: over-satisfied (count > target, conflict)
  - Default: under-satisfied (count < target)
  - Must be distinguishable without color alone (use icons or text styling for accessibility)
- [ ] **Move counter**: displayed in game chrome (AppBar or below grid), showing current move count
- [ ] **Gesture handling**:
  - `GestureDetector` with `onTapUp` for single-cell toggle
  - `onPanStart`, `onPanUpdate`, `onPanEnd` for drag-to-paint
  - Convert pixel coordinates to grid row/col
  - Delegate to cubit: `toggleCell`, `startDrag`, `continueDrag`, `endDrag`
  - Grid should be in a non-scrollable area to avoid gesture conflicts

#### Cell Widget (`lib/games/signal/view/widgets/signal_cell.dart`)

- [ ] Renders a single cell based on its `Cell` type (empty, wall, tower)
- [ ] Tower cells show the target number prominently and the live signal count smaller (e.g., "3/4")
- [ ] Accessibility: tower cells should have semantic labels for screen readers describing type, target, and current count

#### Results Overlay (`lib/games/signal/view/widgets/signal_results_overlay.dart`)

- [ ] Displayed when `SignalState.status == won`
- [ ] Shows: score, stars (via `ScoreCalculator.stars`), move count, streak info
- [ ] Community stats section (same `_CommunityStatsSection` pattern as Guess the Number — reads from `CommunityStatsCubit`)
- [ ] Share button using existing `ResultSharingCubit` pattern:
  - Calls `ResultSharingCubit.share()` with Signal-specific data
  - Builds Signal Nostr event via `EventBuilder.buildSignalResult` (added in Part 3, or use existing single-game pattern temporarily)
  - If Part 3 hasn't merged yet, wire sharing with a Signal-specific `EventBuilder` method added in this PR (to be cleaned up when Part 3 lands)
- [ ] "Back to Hub" button navigating to `'/'`

#### Instructions Dialog (`lib/games/signal/view/widgets/instructions_dialog.dart`)

- [ ] Static how-to-play modal with:
  - Simple diagram showing a tower, walls, and signal rays
  - Explanation of the goal (satisfy all tower constraints)
  - Tap and drag interaction description
  - Scoring explanation
- [ ] Shown on first play, accessible via AppBar info button
- [ ] Matches existing `InstructionsDialog` pattern from Guess the Number

#### Theme (`lib/games/signal/theme/signal_colors.dart`)

- [ ] Game-specific color constants: signal ray color, tower satisfied/conflict/unsatisfied colors, wall color, empty cell color
- [ ] Imported directly (no barrel), matching existing Guess the Number theme pattern

#### Tests

- [ ] Widget tests for `SignalGrid` — renders correct cell count for 5x5 and 6x6, tap toggles cell, drag paints/erases
- [ ] Widget tests for `SignalCell` — renders empty, wall, tower states correctly
- [ ] Widget tests for `SignalResultsOverlay` — shows score, stars, move count, share button states
- [ ] Widget tests for `InstructionsDialog` — renders and dismisses
- [ ] Tests for `SignalGame` — routes, daily status
- [ ] All tests mirror `lib/` structure under `test/games/signal/`

## Technical Considerations

### Drag Gesture vs. Scroll Conflicts

The grid must be placed in a non-scrollable container. If the page needs scrolling for smaller screens, wrap only the non-grid chrome in a scroll view and keep the grid fixed.

### Signal Path Rendering Performance

Signal paths are recomputed from `SignalState.towerSignals` on each build. For a 6x6 grid with ~7 towers, that is ~28 ray segments — trivial for `CustomPaint`. No performance concern.

### Nostr Sharing Compatibility

If Part 3 (Nostr generalization) merges first, use the generalized `share()` API. If not, add a temporary `EventBuilder.buildSignalResult` method in this PR that parallels the existing `buildGuessTheNumberResult`. Part 3 will clean up the duplication.

## Acceptance Criteria

- [ ] Signal tile appears on home screen with correct name, description, icon
- [ ] Tile shows daily status badge (not started / completed) and streak count
- [ ] Tapping tile navigates to Signal game page
- [ ] Grid renders 5x5 or 6x6 based on daily seed
- [ ] Tap toggles individual cells between empty and wall
- [ ] Drag paints or erases based on first cell touched; tower cells skipped
- [ ] Signal paths always visible as colored highlights from towers
- [ ] Tower indicators show live signal count with color feedback (green/red/default)
- [ ] Conflict feedback is accessible without relying solely on color
- [ ] Move counter updates on every cell state change
- [ ] Win triggers results overlay with score, stars, move count
- [ ] Streak persists on win
- [ ] Community stats display after win
- [ ] Share to Nostr works (with Signal-specific event)
- [ ] Instructions dialog on first play, accessible via info button
- [ ] All widget tests pass with `very_good_analysis` v7.0.0
- [ ] Existing Guess the Number tests unaffected

## Dependencies

- **Part 1** must merge first: [2026-04-03-feat-signal-grid-logic-puzzle-part-1-plan.md](docs/plan/2026-04-03-feat-signal-grid-logic-puzzle-part-1-plan.md)
- Part 3 (Nostr generalization) is optional — can merge before or after this PR.

## References

- Existing game page pattern: [game_page.dart](lib/games/guess_the_number/view/game_page.dart)
- Existing results overlay: [results_overlay.dart](lib/games/guess_the_number/view/widgets/results_overlay.dart)
- Existing instructions dialog: [instructions_dialog.dart](lib/games/guess_the_number/view/widgets/instructions_dialog.dart)
- Game definition pattern: [guess_the_number_game.dart](lib/games/guess_the_number/guess_the_number_game.dart)
- Game registration: [game_definition.dart](lib/core/game_registry/game_definition.dart)
- Event builder: [event_builder.dart](lib/nostr/sharing/event_builder.dart)
- Brainstorm: [2026-04-03-signal-puzzle-game-brainstorm-doc.md](docs/brainstorm/2026-04-03-signal-puzzle-game-brainstorm-doc.md)
