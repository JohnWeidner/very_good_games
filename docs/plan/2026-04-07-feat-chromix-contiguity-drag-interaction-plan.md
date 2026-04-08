---
title: "feat: add contiguity constraint and drag interaction to Chromix"
type: feat
date: 2026-04-07
---

## feat: Add Contiguity Constraint and Drag Interaction to Chromix

## Overview

Redesign Chromix's interaction model and add a spatial contiguity constraint to increase puzzle difficulty. Players will drag colors from existing cells to adjacent cells instead of tap-to-place, and all cells of the same color must form a connected group (orthogonally adjacent) to win. This transforms Chromix from a pure color-count matching puzzle into a spatial reasoning challenge.

## Problem Statement / Motivation

Current Chromix puzzles are too easy — solutions are obvious, puzzles are short, and 3 stars is almost guaranteed. The root cause is that players only need to match color counts without caring about spatial arrangement. Additionally, the tap-to-place interaction (select color from palette, tap cell) feels disconnected from the color-mixing theme.

**Two changes address this:**

1. **Drag interaction** — players drag from a colored cell to an adjacent cell, visually "spreading" color. This makes color mixing feel physical and naturally encourages contiguous placement.
2. **Contiguity constraint** — all cells of each color must form a single connected group. This is a hard win requirement (not just a star penalty).

## Proposed Solution

### 1. New Drag Interaction Model

Replace the current "select from palette + tap cell" with a single-hop drag system:

- **Drag from a colored cell to an adjacent empty cell** → places that color in the empty cell
- **Drag from a primary cell to an adjacent different-primary cell (release quickly)** → mixes the colors (e.g., drag red onto yellow → orange)
- **Drag from a primary cell to an adjacent different-primary cell (keep holding)** → mixes first, then overpowers. The cell transitions through the mix to the dragged color (e.g., red onto yellow → orange → red after ~500ms hold). This gives players two tools in one gesture: mix or overpower.
- **Drag from a primary cell to an adjacent secondary cell** → overpowers immediately (e.g., drag red onto orange → red). No mix step since primaries don't mix with secondaries.
- **Only primaries can be dragged from** — secondaries are inert (cannot initiate a drag)
- **Single-hop only** — each drag gesture affects one target cell. No multi-cell chaining.
- **Pre-filled cells** can be dragged FROM (if primary) but cannot be overwritten
- **Blocker cells** cannot be dragged to or from
- **Secondary cells** are locked — cannot be overwritten AND cannot be dragged from
- **Remove `ColorPalette` widget** — no longer needed. Delete `color_palette.dart` and its test.

**Files to modify:**

- `lib/games/chromix/cubit/chromix_cubit.dart` — replace `selectColor()` + `placeColor()` with `startDrag(row, col)`, `dragTo(row, col)`, and `endDrag()`
- `lib/games/chromix/cubit/chromix_state.dart` — add `dragOrigin`, `dragColor`, `isOverpowering` fields (nullable/bool, using `Type? Function()?` copyWith wrapper for nullable fields); remove `selectedColor`
- `lib/games/chromix/view/widgets/chromix_grid.dart` — add `GestureDetector` for pan gestures, convert coordinates via cell size arithmetic: `col = (localOffset.dx / cellWidth).floor()`, `row = (localOffset.dy / cellHeight).floor()`
- `lib/games/chromix/view/widgets/chromix_cell_widget.dart` — minor updates for drag visual feedback (highlight valid drop targets)
- **Delete** `lib/games/chromix/view/widgets/color_palette.dart` and `test/games/chromix/view/widgets/color_palette_test.dart`
- Update `lib/games/chromix/view/widgets/widgets.dart` — remove `color_palette.dart` export
- Update `lib/games/chromix/view/chromix_page.dart` — remove `ColorPalette()` widget from layout

**Cubit drag logic (`chromix_cubit.dart`):**

```
startDrag(row, col):
  cell = grid.cellAt(row, col)
  if cell is not ColorCell → return
  if cell.color is not primary → return  // only primaries can be dragged from
  emit state with dragOrigin=(row,col), dragColor=cell.color

dragTo(row, col):
  if not orthogonally adjacent to dragOrigin → return
  targetCell = grid.cellAt(row, col)
  if targetCell is BlockerCell → return
  if targetCell.isPreFilled → return  // can't overwrite pre-filled
  if targetCell is EmptyCell → place dragColor (always a primary), record move, check win
  if targetCell is ColorCell:
    if targetCell.isLocked → return
    if targetCell.color == dragColor → return (no-op)
    if dragColor.isPrimary && targetCell.color.isPrimary:
      // MIX: place the secondary, start hold timer for overpower
      mixed = ColorMixer.mix(targetCell.color, dragColor)
      if mixed != null → place mixed, record move, start _overpowerTimer
    if dragColor.isPrimary && targetCell.color.isSecondary:
      // OVERPOWER: replace secondary with the dragged primary immediately
      place dragColor, record move, check win
    else → return
  // Do NOT update dragOrigin — single-hop only

_onOverpowerTimeout():  // fires after ~500ms hold
  // The cell was mixed (e.g., orange). Now overpower to the drag color (e.g., red).
  // This is a SECOND move on the same cell.
  replace current cell color with dragColor
  record move (previous cell = the mixed color)
  check win

endDrag():
  cancel _overpowerTimer if running
  clear dragOrigin, dragColor
```

**Overpower timer details:**
- When a mix occurs (primary + primary → secondary), a ~500ms timer starts
- If the player keeps their finger on the cell (no `endDrag` called), the timer fires and the cell transitions from the secondary to the dragged primary
- If the player lifts their finger before the timer fires, the mix stands (orange stays orange)
- The overpower is a separate `MoveRecord` — undo reverses the overpower first, then the mix
- Timer is managed in the cubit, NOT in the widget layer (keeps logic out of UI)

**copyWith for nullable drag fields (`chromix_state.dart`):**

```dart
ChromixState copyWith({
  // ... existing fields ...
  ({int row, int col})? Function()? dragOrigin,
  ChromixColor? Function()? dragColor,
}) {
  return ChromixState(
    // ... existing fields ...
    dragOrigin: dragOrigin != null ? dragOrigin() : this.dragOrigin,
    dragColor: dragColor != null ? dragColor() : this.dragColor,
  );
}
```

### 2. Contiguity Constraint

All cells of the same color must form a single orthogonally-connected group for the puzzle to be solved.

**a) Contiguity checker — new pure function (`lib/games/chromix/logic/contiguity_checker.dart`):**

```
bool allGroupsContiguous(ChromixGrid grid):
  for each ChromixColor present in grid:
    find all cell indices with that color
    BFS/flood-fill from the first index (orthogonal only, blockers impassable)
    if visited count != total count for that color → return false
  return true
```

Update barrel: add `export 'contiguity_checker.dart';` to `lib/games/chromix/logic/logic.dart`.

**b) Generator update (`lib/games/chromix/logic/puzzle_generator.dart`):**

Replace `_buildSolution()` with a region-growing algorithm:

```
_buildSolution(indices, random):
  0. Validate non-blocker cells form a single connected component.
     If not (blockers partition the grid), return null (triggers retry).
  1. Pick seed cells for each color region (6 seeds, well-distributed).
  2. Grow each region by randomly adding orthogonally adjacent unassigned cells
     until the target cell count is reached.
  3. Assign primaries and secondaries to regions
     (ensure each secondary's constituent primaries exist on the board).
```

**Pre-filled selection must be contiguity-aware:** After peel-back (secondary → constituent primary), verify that the resulting puzzle's pre-filled primaries don't create forced non-contiguity in the solution. If they do, retry with different pre-filled selection.

**Update fallback generator** (`_generateFallback`) to also use the contiguous `_buildSolution` algorithm instead of random assignment.

**Consider increasing `maxRetries`** from 10 to 20-30 since contiguity + uniqueness is a tighter constraint.

**c) Solver update (`lib/games/chromix/logic/puzzle_solver.dart`):**

Add contiguity check to the solution validation — only at leaf nodes when distribution matches:

```
// Rename _matchesTarget check at leaf:
if (_matchesTarget() && allGroupsContiguous(_currentGrid())) {
  solutionCount++;
  // ...
}
```

The contiguity check runs only when distribution already matches, so most branches are pruned by distribution first. On a 4×4 grid, the BFS is negligible. The `optimalMoves` calculation will now reflect the contiguity-constrained optimal (since only contiguous solutions are counted).

**d) Win condition update (`lib/games/chromix/cubit/chromix_cubit.dart`):**

```dart
// In _checkWinAndPersist():
final distributionMatches = mapEquals(state.currentDistribution, state.target);
final contiguous = allGroupsContiguous(state.grid);
if (state.grid.isFullyFilled && distributionMatches && contiguous) {
  // Win!
}
```

### 3. Contiguity Feedback

**V1: Simple approach.** Use `allGroupsContiguous()` (bool) to show a text indicator when the grid is in a violation state. Only check contiguity for colors whose placed count matches their target count (avoids noisy feedback on partially-filled grids where disconnected groups are expected).

**State changes:**
- Add `bool hasContiguityViolation` to `ChromixState` (derived/recomputed after each move and undo)
- Show a subtle text indicator (e.g., "Colors must be connected") below the grid when `hasContiguityViolation` is true and the grid is fully filled or a color has reached its target count

**Not in v1:** Per-cell `disconnectedCells()` tracking, pulsing borders, or cell-level animation. These can be added in a follow-up if playtesting shows players need more granular feedback.

**Files to modify:**
- `lib/games/chromix/cubit/chromix_state.dart` — add `bool hasContiguityViolation` field
- `lib/games/chromix/cubit/chromix_cubit.dart` — recompute after each move/undo
- `lib/games/chromix/view/chromix_page.dart` — show text indicator when violation is true

### 4. Instructions Update

Update `ChromixInstructionsDialog` to explain:

- The drag interaction (drag from a colored cell to an adjacent cell to spread color)
- Color mixing via drag (drag a primary onto a different primary to mix)
- The contiguity rule ("each color must form one connected group")

**File:** `lib/games/chromix/view/widgets/instructions_dialog.dart`

### 5. Serialization & Backward Compatibility

- **Remove `selectedColor`** from `_persistSession()` — stop writing it
- **Remove `selectedColor`** from `_deserializeState()` — stop reading it (old sessions with `selectedColor` still deserialize; the field is simply ignored)
- **Drag state is transient** — `dragOrigin` and `dragColor` are NOT persisted. Add a code comment noting this is intentional.
- **Restored sessions must recompute** `hasContiguityViolation` from the restored grid
- **Daily seed determinism change**: the new generator algorithm produces different puzzles for the same seed. Old in-progress sessions will fail deserialization (target/optimalMoves mismatch) and be cleared by the existing catch block. This is acceptable for a daily puzzle.

### 6. Undo Handling

Undo already works by restoring the previous cell. After undo, `hasContiguityViolation` is recomputed from the restored grid. No special undo logic needed — the existing `MoveRecord` system handles cell restoration, and contiguity is recalculated on every state change.

## Technical Considerations

- **Architecture**: All changes stay within `lib/games/chromix/`. No cross-game or core changes needed.
- **Performance**: Contiguity BFS on a 4×4 grid (16 cells max) is negligible. No profiling needed.
- **Generator retries**: Region-growing may fail to partition cells cleanly with blockers. Increase `maxRetries` to 20-30. The existing fallback path also uses the new algorithm.
- **Grid topology**: Generator must validate non-blocker cells form a single connected component before attempting region-growing. If blockers partition the grid, return null and retry.
- **Drag gesture conflicts**: Pan gestures on the grid must not conflict with scroll gestures on the page. Use `GestureDetector` with `onPanStart`/`onPanUpdate`/`onPanEnd` on the grid widget. Coordinate conversion: `col = (localOffset.dx / cellWidth).floor()`, `row = (localOffset.dy / cellHeight).floor()`.
- **No animations in v1**: Color changes are instant. Animations can be added as a polish follow-up.
- **State persistence**: `selectedColor` removed from serialized state; `dragOrigin`/`dragColor` are transient (not persisted — drag state resets on app restart).

## Acceptance Criteria

### Drag Interaction
- [ ] Player can drag from a primary-colored cell to an adjacent empty cell to place that color (`chromix_cubit.dart`)
- [ ] Player cannot drag from a secondary-colored cell — secondaries are inert (`chromix_cubit.dart`)
- [ ] Player can drag from a primary cell to an adjacent different-primary cell to mix colors (quick release → secondary) (`chromix_cubit.dart`)
- [ ] Player can hold after mixing to overpower — cell transitions from secondary to dragged primary after ~500ms (`chromix_cubit.dart`)
- [ ] Overpower is a separate MoveRecord — undo reverses overpower first, then the mix (`chromix_cubit.dart`)
- [ ] Player can drag a primary onto a non-pre-filled secondary to overpower immediately (no timer) (`chromix_cubit.dart`)
- [ ] Lifting finger before timer fires keeps the mix result (`chromix_cubit.dart`)
- [ ] Drag is single-hop only — one target cell per gesture, no chaining (`chromix_cubit.dart`)
- [ ] Drag only works to orthogonally adjacent cells (not diagonal) (`chromix_cubit.dart`)
- [ ] Pre-filled cells can be dragged from but not overwritten (`chromix_cubit.dart`)
- [ ] Blocker cells cannot be dragged to or from (`chromix_cubit.dart`)
- [ ] Secondary (locked) cells cannot be overwritten and cannot be dragged from (`chromix_cubit.dart`)
- [ ] `ColorPalette` widget is deleted; `selectedColor` removed from state (`color_palette.dart`, `chromix_state.dart`)
- [ ] Grid handles pan gestures for drag without conflicting with page scroll (`chromix_grid.dart`)
- [ ] `dragOrigin` and `dragColor` use `Type? Function()?` copyWith wrapper (`chromix_state.dart`)
- [ ] Overpower timer is managed in the cubit, not the widget layer (`chromix_cubit.dart`)

### Contiguity Constraint
- [ ] New `allGroupsContiguous()` function correctly identifies contiguous/non-contiguous grids (`contiguity_checker.dart`)
- [ ] Barrel file updated: `logic.dart` exports `contiguity_checker.dart` (`logic.dart`)
- [ ] Generator produces puzzles with contiguous color regions using region-growing (`puzzle_generator.dart`)
- [ ] Generator validates non-blocker cells form a single connected component (`puzzle_generator.dart`)
- [ ] Generator pre-filled selection is contiguity-aware after peel-back (`puzzle_generator.dart`)
- [ ] Fallback generator also uses contiguous algorithm (`puzzle_generator.dart`)
- [ ] `maxRetries` increased to 20-30 (`puzzle_generator.dart`)
- [ ] Solver rejects solutions where any color group is disconnected (`puzzle_solver.dart`)
- [ ] `optimalMoves` reflects contiguity-constrained optimal (`puzzle_solver.dart`)
- [ ] Win condition requires `isFullyFilled && distributionMatches && allGroupsContiguous` (`chromix_cubit.dart`)

### Contiguity Feedback
- [ ] `hasContiguityViolation` bool in state, recomputed after every move and undo (`chromix_state.dart`, `chromix_cubit.dart`)
- [ ] Only check contiguity for colors whose count matches target (avoid noise on partial grids) (`chromix_cubit.dart`)
- [ ] Text indicator shown when contiguity is violated and relevant (`chromix_page.dart`)

### Instructions
- [ ] Instructions dialog explains drag interaction (`instructions_dialog.dart`)
- [ ] Instructions dialog explains contiguity rule (`instructions_dialog.dart`)

### Serialization
- [ ] `selectedColor` removed from `_persistSession()` and `_deserializeState()` (`chromix_cubit.dart`)
- [ ] Drag state (origin, color) is intentionally not persisted (`chromix_cubit.dart`)
- [ ] Restored sessions recompute `hasContiguityViolation` (`chromix_cubit.dart`)

### Testing
- [ ] Unit tests for `allGroupsContiguous()` — contiguous grid, non-contiguous grid, single-color grid, grid with blockers (`contiguity_checker_test.dart`)
- [ ] Unit tests for updated `PuzzleGenerator` — generated puzzles have contiguous regions across multiple seeds, max-blocker edge cases, partitioned-grid rejection (`puzzle_generator_test.dart`)
- [ ] Unit tests for updated `PuzzleSolver` — rejects non-contiguous solutions (`puzzle_solver_test.dart`)
- [ ] Cubit tests for drag flow: `startDrag` → `dragTo` → `endDrag`, including rejection cases (blocker, won state, non-adjacent, pre-filled target) (`chromix_cubit_test.dart`)
- [ ] Cubit tests for overpower: mix then timer fires → cell becomes dragged primary; lift before timer → mix stands (`chromix_cubit_test.dart`)
- [ ] Cubit tests for overpower undo: undo after overpower restores the mix; undo again restores original (`chromix_cubit_test.dart`)
- [ ] Cubit tests for immediate overpower: drag primary onto non-pre-filled secondary → replaces immediately (`chromix_cubit_test.dart`)
- [ ] Cubit tests for win condition with contiguity check (`chromix_cubit_test.dart`)
- [ ] Cubit tests for `hasContiguityViolation` recomputation on move/undo (`chromix_cubit_test.dart`)
- [ ] Widget tests for drag gesture handling on grid (`chromix_grid_test.dart`)
- [ ] Widget test for contiguity violation text indicator (`chromix_page_test.dart`)
- [ ] Widget test for updated instructions dialog (`instructions_dialog_test.dart`)
- [ ] Verify `ColorPalette` widget and test are deleted (`color_palette.dart` removed)

## Success Metrics

- Puzzles feel noticeably harder — 3-star completion rate should drop (playtest subjectively)
- Drag interaction feels intuitive — color spreading is discoverable without reading instructions
- No regression in puzzle generation reliability (generator still produces valid puzzles within retry limit)

## Dependencies & Risks

- **Risk: Drag UX may be confusing** — mitigated by clear instructions and the fact that pre-filled cells provide starting drag points
- **Risk: Generator may struggle to partition with many blockers** — mitigated by increased retry limit (20-30) and connected-component validation
- **Risk: Gesture conflicts with scrolling** — mitigated by using pan gestures scoped to the grid widget only, with cell-size arithmetic for coordinate conversion
- **Risk: Daily seed change** — same seed produces different puzzle after update. Old in-progress sessions cleared gracefully by existing error handling.
- **No external dependencies** — all changes are pure Dart logic + Flutter widgets

## References & Research

- Brainstorm: `docs/brainstorm/2026-04-07-chromix-contiguity-constraint-brainstorm-doc.md`
- Current generator: `lib/games/chromix/logic/puzzle_generator.dart` — `_buildSolution()` at line 95
- Current solver: `lib/games/chromix/logic/puzzle_solver.dart` — `_matchesTarget()` at line 83
- Current win check: `lib/games/chromix/cubit/chromix_cubit.dart` — `_checkWinAndPersist()` at line 190
- Current cell widget: `lib/games/chromix/view/widgets/chromix_cell_widget.dart`
- Current instructions: `lib/games/chromix/view/widgets/instructions_dialog.dart`
