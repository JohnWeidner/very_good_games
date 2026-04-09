# Code Simplicity Review: Cascade Ball-Routing Puzzle

**Branch**: `feat/cascade-ball-routing-puzzle`
**Date**: 2026-04-08
**Reviewer**: Claude (code-simplicity agent)

---

## Simplification Analysis

### Core Purpose

The Cascade game lets a player arrange three balls across three drop slots and flip levers on a grid, then release the balls to cascade through the levers into labeled bins at the bottom. The player wins when every ball lands in its matching bin. State persists across app restarts and the result is shareable via Nostr.

---

### Unnecessary Complexity Found

#### 1. `swapSlots` cubit method is redundant with `assignBall`

**File**: `lib/games/cascade/cubit/cascade_cubit.dart`, lines 146-157

`assignBall` already handles the swap case internally: it finds where the dragged ball currently lives, moves whatever is in the target slot to that old slot, then puts the dragged ball in the target. `swapSlots` is a thin wrapper that performs the exact same swap manually with an explicit temp variable.

Crucially, there are no call sites for `swapSlots` in any view widget. All drag targets in the board call `assignBall`. `swapSlots` exists as dead API.

**Suggested simplification**: Remove `swapSlots` entirely. `assignBall` is sufficient for any "swap" interaction because it already performs that exact path.

**Estimated removal**: ~12 lines production, ~14 lines test.

---

#### 2. `unassignBall` has no view call site

**File**: `lib/games/cascade/cubit/cascade_cubit.dart`, lines 133-143

There is no drag gesture or tap handler anywhere in the view that calls `unassignBall`. The interaction model is drag-only: balls are dragged from the tray to a slot, or between slots via `assignBall`. There is no "drag back to tray" or "tap to unassign" gesture.

This is a YAGNI violation. The method implements an interaction path that was not built.

**Suggested simplification**: Remove `unassignBall` and its test. Re-add only when an explicit unassign gesture is designed.

**Estimated removal**: ~10 lines production, ~9 lines test.

---

#### 3. `_generatePuzzle` static wrapper is unnecessary

**File**: `lib/games/cascade/cubit/cascade_cubit.dart`, lines 81-83

```dart
static CascadeGenerateResult _generatePuzzle(int seed) {
  return PuzzleGenerator.generate(seed);
}
```

`compute` requires a top-level or static function. `PuzzleGenerator.generate` is already a static method with the exact signature `(int) -> CascadeGenerateResult`, so it qualifies as a direct tear-off.

**Suggested simplification**: Replace `compute(_generatePuzzle, seed)` with `compute(PuzzleGenerator.generate, seed)` at both call sites, then delete `_generatePuzzle`.

**Estimated removal**: 3 lines.

---

#### 4. `_initializeFromSeed` duplicates the non-storage branch of `_initialize`

**File**: `lib/games/cascade/cubit/cascade_cubit.dart`, lines 91-104

`_initializeFromSeed` is only called by `resetWithSeed`, which is itself only reachable in `kDebugMode`. Its body is identical to the `isClosed`-check + `compute` + `emit` pattern in `_initialize`, just without the session restore. This is ~13 lines of near-duplicate code.

**Suggested simplification**: Inline the body of `_initializeFromSeed` directly into `resetWithSeed` (it is only one call site), or accept a `bool skipRestore` argument on a unified private initializer. Either approach eliminates the duplicate.

**Estimated removal**: ~13 lines.

---

#### 5. `CascadeBoard.fromJson` factory is dead code

**File**: `lib/games/cascade/models/cascade_board.dart`, lines 17-24

Session deserialization in the cubit (`_deserializeState`, lines 291-294) constructs `CascadeBoard` manually:

```dart
final board = CascadeBoard(
  levers: levers,
  binOrder: result.board.binOrder,
);
```

`CascadeBoard.fromJson` is never called anywhere in the codebase. The `Lever.fromJson` factory is legitimately used and should stay; the board factory is not.

**Suggested simplification**: Remove `CascadeBoard.fromJson`. Add it back if the session deserialization is ever refactored to use it.

**Estimated removal**: ~7 lines.

---

#### 6. `cascadeStars` is called twice in `CascadeResultsOverlay` when `state.stars` already exists

**File**: `lib/games/cascade/view/widgets/cascade_results_overlay.dart`, lines 34 and 111

Both `build` and `_share` call `cascadeStars(state.attempts)` directly, importing the logic barrel for that one function. `CascadeState` already exposes a `stars` getter (cascade\_state.dart line 73) that computes the identical value. The overlay bypasses the state getter and calls the raw function, meaning if the scoring formula changes the overlay becomes a maintenance target.

**Suggested simplification**: Use `state.stars` in both places. This removes the need to import `logic.dart` in the overlay file.

**Estimated removal**: 2 lines simplified, 1 import potentially removed.

---

#### 7. Attempts pluralization string is duplicated verbatim across two files

**Files**:
- `lib/games/cascade/view/cascade_page.dart`, lines 257-258
- `lib/games/cascade/view/widgets/cascade_results_overlay.dart`, lines 65-66

Both files contain:
```dart
'${state.attempts} ${state.attempts == 1 ? 'attempt' : 'attempts'}'
```

This is minor but exact duplication of string formatting logic. A one-line getter on `CascadeState` would centralize it.

**Suggested simplification**: Add `String get attemptsLabel => '$attempts ${attempts == 1 ? 'attempt' : 'attempts'}';` to `CascadeState` and use it in both places.

**Estimated removal**: Net zero lines, but eliminates the duplication.

---

#### 8. Three-level ternary nesting in `_buildDropSlots`

**File**: `lib/games/cascade/view/widgets/cascade_board_widget.dart`, lines 222-260

The child expression inside `DragTarget.builder` has three nested `?:` branches:

```
assignedBall != null && _shouldShowSlotBall(...)
  ? isConfiguring
    ? Draggable(...)
    : Center(BallWidget(...))
  : Center(Icon(...))
```

This is the most complex widget sub-tree in the file. Three-level ternaries are hard to visually parse and resist widget-test targeting.

**Suggested simplification**: Extract a private `_buildSlotChild(BallId? ball, bool showBall, bool isConfiguring, double cellSize)` method with three early-return branches (empty, has-ball-locked, has-ball-draggable). No lines removed, but a meaningful clarity improvement.

---

#### 9. `_GridPainter` private color constants bypass `CascadeColors`

**File**: `lib/games/cascade/view/widgets/cascade_board_widget.dart`, lines 533-534

```dart
static const _edgeColor = Color(0xFFD0D0D0);
static const _slotColor = Color(0xFFEEEEEE);
```

All other board colors are in `CascadeColors`. These two are defined as private constants inside `_GridPainter`, making them invisible to the theme class and harder to adjust consistently.

**Suggested simplification**: Move to `CascadeColors` with names like `gridEdge` and `slotBackground`. Net zero line change, but makes theming consistent.

---

### Code to Remove

| File | Lines | Reason | LOC |
|------|-------|--------|-----|
| `cubit/cascade_cubit.dart` | 146-157 | `swapSlots` — redundant with `assignBall`, no call site | ~12 |
| `cubit/cascade_cubit.dart` | 133-143 | `unassignBall` — no view call site | ~10 |
| `cubit/cascade_cubit.dart` | 81-83 | `_generatePuzzle` — replace with `PuzzleGenerator.generate` tear-off | 3 |
| `cubit/cascade_cubit.dart` | 91-104 | `_initializeFromSeed` — inline into `resetWithSeed` | ~13 |
| `models/cascade_board.dart` | 17-24 | `CascadeBoard.fromJson` — no call site | ~7 |
| `test/cubit/cascade_cubit_test.dart` | 77-106 | Tests for removed `unassignBall` and `swapSlots` | ~28 |

**Estimated total LOC reduction: ~73 lines** (~5% of the total diff size).

---

### Simplification Recommendations

**1. Remove `unassignBall` and `swapSlots`** (highest impact)

- Current: Two cubit methods with no view call sites
- Proposed: Delete both methods and their tests
- Impact: ~50 lines removed; reduces the public cubit API to only what the view uses

**2. Replace `_generatePuzzle` with a direct tear-off** (trivial, zero risk)

- Current: One-line static wrapper for `PuzzleGenerator.generate`
- Proposed: `compute(PuzzleGenerator.generate, seed)` at both call sites
- Impact: 3 lines removed

**3. Inline or unify `_initializeFromSeed`** (reduces duplication)

- Current: A second async initializer that duplicates the non-storage path of `_initialize`
- Proposed: Inline the 5-line body into `resetWithSeed` directly
- Impact: ~13 lines removed

**4. Remove `CascadeBoard.fromJson`** (dead code removal)

- Current: Factory constructor with no callers
- Proposed: Delete and re-add if ever needed
- Impact: ~7 lines removed

**5. Use `state.stars` in `CascadeResultsOverlay`** (consistency)

- Current: `cascadeStars(state.attempts)` called twice, bypassing the state getter
- Proposed: `state.stars` in both places; remove `logic.dart` import from overlay
- Impact: 2 lines simplified, improves correctness under future scoring changes

**6. Extract `_buildSlotChild` from the nested ternary** (readability)

- Current: Three-level `?:` chain inside `DragTarget.builder`
- Proposed: Private method with early-return branches
- Impact: No LOC change, significant clarity improvement for future maintenance

---

### YAGNI Violations

**`unassignBall`**: Implements an "unassign" gesture that has no corresponding UI interaction. The ball interaction model uses drag-only mechanics; there is no path from the view that calls this method. It is feature code written speculatively.

**`swapSlots`**: Implements index-based slot swapping, but `assignBall` already handles the same swap transparently as part of ball reassignment. There is no view interaction that would need a swap-by-index without also knowing which ball to move.

**`CascadeBoard.fromJson`**: Preparatory deserialization code. The actual session deserialization skips it and constructs the board manually, meaning this factory was written in anticipation of a refactor that has not happened.

---

### Final Assessment

The Cascade implementation is clean and well-structured. Logic is properly isolated in pure Dart classes, the cubit handles all state transitions correctly, animations are clearly separated from game logic, and conventions from the rest of the codebase are followed throughout.

The issues found are all minor: three dead methods/factories, one unnecessary wrapper, and two small view-layer duplications. None affect correctness or behavior. The animation code in `cascade_board_widget.dart` is the most complex part of the implementation but the complexity is inherent to the domain (animating three sequential balls through a grid) and is handled clearly.

**Total potential LOC reduction**: ~73 lines (~5%)
**Complexity score**: Low
**Recommended action**: Proceed with targeted removals before merge — changes are mechanical, low-risk, and reduce the public cubit API to exactly what the view uses.
