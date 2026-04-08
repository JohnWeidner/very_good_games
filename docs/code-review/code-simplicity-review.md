# Code Simplicity Review: Chromix Contiguity + Drag Interaction

**Date**: 2026-04-07
**Scope**: 22 files (12 source, 10 test) -- drag interaction, contiguity constraint, overpower mechanic, win celebration, puzzle generator rewrite
**Reviewer**: Code Simplicity Agent

---

## Simplification Analysis

### Core Purpose

Convert Chromix from a tap-to-place interaction to drag-based interaction, add a contiguity constraint (each color must form one connected group), introduce an overpower mechanic (hold after mix to replace with dragged color), add a shared WinCelebration widget with confetti across all games, and rewrite puzzle generation to use forward simulation guaranteeing reachability via drag moves.

### Unnecessary Complexity Found

#### 1. [Critical] Duplicate BFS contiguity logic in three places

**Files**: `lib/games/chromix/cubit/chromix_cubit.dart` (lines 352-386, 467-512), `lib/games/chromix/logic/contiguity_checker.dart` (lines 7-43)

The BFS contiguity check is implemented three separate times:

- `_isColorContiguous()` in the cubit (instance method, lines 352-386) -- checks a single color via BFS
- `_computeContiguityViolation()` in the cubit (static method, lines 467-512) -- iterates target colors and runs inline BFS per color
- `allGroupsContiguous()` in `contiguity_checker.dart` -- iterates all colors via BFS

The cubit's `_recomputeContiguity()` calls `_isColorContiguous()`, then `_checkWinAndPersist()` separately calls `allGroupsContiguous()` from the extracted checker, and `_computeContiguityViolation()` is used during deserialization with yet another inline BFS. This is three implementations of the same core algorithm.

**Suggestion**: The cubit should delegate entirely to `contiguity_checker.dart`. Add a `hasViolationForTargets(ChromixGrid grid, Map<ChromixColor, int> target)` function there. Delete `_isColorContiguous` and `_computeContiguityViolation` from the cubit. Estimated savings: ~80 lines.

---

#### 2. [Important] Blob label centroid computation is over-engineered

**File**: `lib/games/chromix/view/widgets/chromix_grid.dart` (lines 115-178)

`_buildBlobLabel` computes the "most interior cells" by finding cells with the highest same-blob neighbor count, then averages their centroids. On a 4x4 grid with at most 12 non-blocker cells and blobs of at most ~6 cells, this interior-detection algorithm adds 30 lines of logic that produces visually identical results to a simple centroid of all blob cells.

**Suggestion**: Replace with a plain centroid:
```dart
var cx = 0.0, cy = 0.0;
for (final idx in blob.cells) {
  cx += (idx % size + 0.5) * cellSize;
  cy += (idx ~/ size + 0.5) * cellSize;
}
cx /= blob.cells.length;
cy /= blob.cells.length;
```
Estimated savings: ~25 lines.

---

#### 3. [Important] Repeated win-celebration boilerplate across three game pages

**Files**: `lib/games/chromix/view/chromix_page.dart`, `lib/games/signal/view/signal_page.dart`, `lib/games/guess_the_number/view/game_page.dart`

Each game page has nearly identical code:
- `_showResults = false` with `addPostFrameCallback` to restore won state on rebuild (~8 lines each)
- `_onWin` / `_onGameOver` method calling `WinCelebration.of(context)?.trigger(...)` (~8 lines each)
- Reset handler calling `WinCelebration.of(context)?.reset()` (1 line each)
- Wrapping `body` with `WinCelebration(child: ...)` (structural change)

The pattern is copied three times with only the cubit type and status enum name differing.

**Suggestion**: Either create a `WinCelebrationMixin` that provides `showResults`, `onWin()`, and `resetCelebration()`, or make `WinCelebration` itself manage the `showResults` boolean and expose it via its state (e.g., `WinCelebration.of(context)?.showResults`). Estimated savings: ~40 lines across three files, and easier onboarding when adding future games.

---

#### 4. [Important] `_allPrimariesCanGrow` adds ~50 lines of defensive validation

**File**: `lib/games/chromix/logic/puzzle_generator.dart` (new code, `_allPrimariesCanGrow` method)

This method runs a BFS from every primary cell to verify it can reach an empty cell or same-color cell. However, `_simulateMoves` already handles stuck states by returning null (the simulation collects all valid actions and returns null if none exist). The uniqueness solver then rejects unsolvable puzzles. `_allPrimariesCanGrow` is a fail-fast optimization that duplicates what the simulation already guarantees.

**Suggestion**: Try removing `_allPrimariesCanGrow` and rely on `_simulateMoves` returning null for stuck grids. If generation time regresses noticeably (measure it), add it back with a comment explaining the performance justification. Estimated savings: ~50 lines.

---

#### 5. [Important] Trivial fallback puzzle silently serves a degenerate game

**File**: `lib/games/chromix/logic/puzzle_generator.dart` (new code, last-resort in `_generateFallback`)

After 50 fallback attempts, the generator creates a "1-blocker, 15-cell all-red puzzle." This puzzle is unsolvable in any meaningful way and would be a terrible player experience. If this code path is reachable, there is a bug in the generator. Silently serving garbage hides bugs.

**Suggestion**: Replace the trivial fallback with `throw StateError('Puzzle generation failed after all retries')`. In a correctly working generator, this should never trigger. If it does, you want a crash report, not a confused player.

---

#### 6. [Suggestion] Unused `mixedColor` parameter in `_startOverpowerTimer`

**File**: `lib/games/chromix/cubit/chromix_cubit.dart` (line 222)

`_startOverpowerTimer` accepts `ChromixColor mixedColor` but never reads it. This is a leftover from an earlier design.

**Suggestion**: Remove the parameter. Update the call site at line 200.

---

#### 7. [Suggestion] Neighbor-finding helper duplicated in three files

**Files**: `puzzle_generator.dart` (`_neighbors`), `chromix_grid.dart` (`_neighborsOf`), `contiguity_checker.dart` (`_orthogonalNeighbors`)

Three private implementations of identical "get orthogonal neighbors for a grid index" logic.

**Suggestion**: Add a static `ChromixGrid.neighborsOf(int row, int col)` method in the model layer and use it everywhere. Estimated savings: ~20 lines.

---

#### 8. [Suggestion] `CellEdges.all` constant is never used

**File**: `lib/games/chromix/view/widgets/chromix_cell_widget.dart` (lines 18-24)

`CellEdges.all` is defined but never referenced in the codebase. `CellEdges.none` is used as a default parameter value (appropriate), but `.all` is speculative.

**Suggestion**: Remove it. Estimated savings: 6 lines.

---

### Code to Remove

| Location | Reason | LOC |
|---|---|---|
| `chromix_cubit.dart:352-386` | `_isColorContiguous` duplicates `contiguity_checker.dart` | ~35 |
| `chromix_cubit.dart:467-512` | `_computeContiguityViolation` duplicates checker + inline BFS | ~45 |
| `chromix_cell_widget.dart:18-24` | `CellEdges.all` unused constant | 6 |
| `chromix_cubit.dart:225` | `mixedColor` param unused | 1 |
| `puzzle_generator.dart` | `_allPrimariesCanGrow` if simulation handles it | ~50 |
| Estimated total removable | | ~137 |

### Simplification Recommendations

1. **Consolidate contiguity checking into `contiguity_checker.dart`** (Most impactful)
   - Current: Three separate BFS implementations across two files
   - Proposed: Single `contiguity_checker.dart` with `allGroupsContiguous()` and `hasViolationForTargets(grid, target)`; cubit delegates to both
   - Impact: ~80 LOC saved, single source of truth for a core game rule

2. **Simplify blob label placement**
   - Current: Interior-cell detection with best-neighbor-count algorithm (~30 lines)
   - Proposed: Simple centroid of all blob cells (~5 lines)
   - Impact: ~25 LOC saved, no visual difference on a 4x4 grid

3. **Extract win celebration pattern to reduce cross-game duplication**
   - Current: ~30 lines of identical boilerplate in each game page
   - Proposed: Mixin or richer WinCelebration widget that manages showResults state
   - Impact: ~40 LOC saved across 3 files, easier to add new games

4. **Unify neighbor-finding helpers**
   - Current: Three private copies of the same function
   - Proposed: One shared static method on `ChromixGrid`
   - Impact: ~20 LOC saved

### YAGNI Violations

1. **`CellEdges.all` constant** -- Defined but never referenced. Speculative convenience.

2. **`_allPrimariesCanGrow` validation in generator** -- Defensive check that duplicates what `_simulateMoves` already handles by returning null. Added complexity without proven performance benefit.

3. **Trivial fallback puzzle** -- A degenerate all-red puzzle is worse than failing loudly. No player should see this; if they do, something is seriously wrong.

### Additional Observations

**Well done aspects of this changeset:**
- Clean removal of `ColorPalette` (tap-to-select) and its test, replaced with drag semantics
- The overpower timer mechanic is well-isolated with proper cleanup in `close()`, `endDrag()`, `undo()`, and `resetWithSeed()`
- Good test coverage for drag interactions, including edge cases (non-adjacent, blocker, secondary, overpower timer, undo of overpower)
- `WinCelebration` is a reasonable shared widget with clean timer management
- Session deserialization now validates blocker positions match the generated puzzle, preventing stale data bugs
- Forward generation strategy is sound and well-documented
- `_DragAction` / `_ActionType` classes in generator are appropriately scoped as private implementation details
- CellEdges + blob rendering is a nice visual improvement

**Potential concern:**
- The overpower tests use `Future<void>.delayed(const Duration(milliseconds: 600))` to wait for the 500ms timer. These are real-time waits in tests. If the timer duration changes, the tests silently become flaky or slow. Consider using `fakeAsync` from `package:clock` to control time in tests.

### Final Assessment

**Total potential LOC reduction**: ~170 lines (~12% of changed code)
**Complexity score**: Medium
**Recommended action**: Proceed with simplifications -- the triplicated BFS logic (Critical) should be consolidated before merging. The important items (blob centroid, win-celebration boilerplate, generator defensiveness) are worth addressing but not blockers. Suggestions are polish.
