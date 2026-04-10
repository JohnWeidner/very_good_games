# Code Simplicity Review: Cascade Ball-Routing Puzzle (`lib/games/cascade/`)

**Date**: 2026-04-09
**Scope**: All files under `lib/games/cascade/` and its subdirectories
**Reviewer**: Code Simplicity Agent

---

## Simplification Analysis

### Core Purpose

The Cascade game lets a player route three numbered balls into matching target bins by assigning balls to drop slots and flipping levers. The code must:

1. Generate a daily puzzle deterministically from a seed with exactly one winning configuration.
2. Let the player configure the board (assign balls, flip levers).
3. Simulate the drop and animate balls traversing the board.
4. Detect a win, record a score/streak, and show a results overlay.

---

### Unnecessary Complexity Found

#### 1. `unassignBall` method on `CascadeCubit` is never called

**File**: `cubit/cascade_cubit.dart`, lines 113–124

`unassignBall` is a public method on the cubit that is never invoked anywhere in the view layer. The `BallTray` only calls `onBallAssigned` on drop. Slot removal happens implicitly through `assignBall` (dragging to a new slot swaps). The method has its own guard logic for out-of-bounds indices and null checks — all dead.

**Suggestion**: Remove entirely. If a "drag ball back to tray" interaction is added in the future, introduce this method then.

**Estimated savings**: 11 lines of dead public API.

---

#### 2. `CascadeBoard.dropSlotColumns` and `binColumns` are identical constants

**File**: `models/cascade_board.dart`, lines 32–36

```dart
static const dropSlotColumns = [1, 2, 3];
static const binColumns = [1, 2, 3];
```

Both constants have identical values and represent the same physical columns on the board. The comment on `binColumns` even acknowledges this: "Bin positions (center 3 columns, same as drop slots)." Two names for the same value forces readers to verify they are the same before trusting either reference.

**Suggestion**: Keep one constant (e.g., `centerColumns`) and use it throughout. Saves 3 lines and removes the unnecessary disambiguation burden.

---

#### 3. `CascadeBoard.leverAt()` is dead code

**File**: `models/cascade_board.dart`, lines 46–51

`leverAt(row, col)` returns a `Lever?` by linear scan but is never called. The simulator has its own `_leverIndexAt` because it needs the index (not the lever object) to call `flipLever(index)`. The board-level method cannot serve that need and has no other callers.

**Suggestion**: Remove `leverAt` (6 lines). If index-based lookup is ever needed at the board level, promote `_leverIndexAt` from the simulator.

---

#### 4. `CascadeColors.binCorrect` color is unused

**File**: `theme/cascade_colors.dart`, line 21

`CascadeColors.binCorrect` (`Color(0xFF43A047)`) is defined but never referenced. The `BinWidget` uses only `binNeutral`; bins do not change color on win. This is a reserved-for-later constant.

**Suggestion**: Remove it (2 lines). Add it when green win-state bin coloring is actually implemented.

---

#### 5. Mutable pre-drop fields on `CascadeCubit` bypass `CascadeState`

**File**: `cubit/cascade_cubit.dart`, lines 36–39, 145–147, 204–208

`_preDropBoard` and `_preDropSlots` are nullable instance fields on the cubit that snapshot state at drop time and are consumed by `reset()`. However:

- The state already carries `initialLevers` for reset.
- The `reset()` method has fallback paths (`?? state.board.resetLevers(state.initialLevers)` and `?? defaultSlotAssignments`) that already handle the null case correctly.
- Storing mutable fields outside of `CascadeState` breaks the pattern that all meaningful game state lives in the state object, making the cubit harder to test and reason about.

**Suggestion**: Remove `_preDropBoard` and `_preDropSlots`. Use the existing fallback paths in `reset()` unconditionally: reset levers to `state.initialLevers` and slots to `defaultSlotAssignments`. If preserving the exact pre-drop configuration is important, move those fields into `CascadeState` instead. The current fallbacks already do the right thing for the documented behavior ("resets to seed defaults for another attempt").

**Estimated savings**: ~8 lines plus restored cubit purity.

---

#### 6. `BallId.label` switch has three arms that mechanically follow the index

**File**: `models/ball.dart`, lines 13–17

```dart
String get label => switch (this) {
  BallId.ball1 => '1',
  BallId.ball2 => '2',
  BallId.ball3 => '3',
};
```

Each arm returns the 1-based index as a string. The switch will never diverge from ordinal order because the enum members are defined in ordinal order.

**Suggestion**:
```dart
String get label => '${index + 1}';
```
Saves 4 lines. Self-documenting: the label is the 1-based position.

---

#### 7. `CascadeState.loading()` duplicates default field values

**File**: `cubit/cascade_state.dart`, lines 39–46

The `loading()` named constructor explicitly initializes every field, most of which match the default parameter values declared in the main constructor. This creates two places where defaults live, risking drift.

**Suggestion**: Use a delegating constructor:
```dart
CascadeState.loading() : this(
  board: CascadeBoard(levers: const [], binOrder: const [0, 1, 2]),
  initialLevers: const [],
  status: CascadeStatus.loading,
);
```
Saves ~5 lines and keeps defaults in one place.

---

#### 8. Redundant `SizedBox` wrapper in `BinWidget`

**File**: `view/widgets/bin_widget.dart`, lines 32–65

`BinWidget` wraps a `Container` inside a `SizedBox` — both setting `width: cellSize, height: cellSize`. The outer `SizedBox` provides no additional constraint beyond what the `Container` already applies.

**Suggestion**: Remove the outer `SizedBox` and let the `Container` handle sizing. Saves ~4 lines.

---

#### 9. `onViewPuzzle` null guard repeated twice in sequence

**File**: `view/widgets/cascade_results_overlay.dart`, lines 85–91

```dart
if (onViewPuzzle != null)
  OutlinedButton(...),
if (onViewPuzzle != null)
  const SizedBox(width: 12),
```

The spacer's visibility is coupled to the button's. This should be expressed as a single conditional block:
```dart
if (onViewPuzzle != null) ...[
  OutlinedButton(...),
  const SizedBox(width: 12),
],
```
Saves 2 lines and makes the coupling explicit.

---

#### 10. Attempts pluralization duplicated in two widgets

**File**: `view/cascade_page.dart`, lines 257–259; `view/widgets/cascade_results_overlay.dart`, lines 64–66

Both `_ActionRow` and `CascadeResultsOverlay` construct the same inline string:
```dart
'${state.attempts} ${state.attempts == 1 ? 'attempt' : 'attempts'}'
```

**Suggestion**: Extract a one-line helper function or extension:
```dart
String attemptsLabel(int n) => '$n ${n == 1 ? 'attempt' : 'attempts'}';
```
Minor, but prevents the strings from drifting independently.

---

### Code to Remove

| Location | Reason | Estimated LOC |
|---|---|---|
| `models/ball.dart:13–17` | Replace switch with `'${index + 1}'` | -4 |
| `cubit/cascade_cubit.dart:113–124` | `unassignBall` — never called from UI | -11 |
| `cubit/cascade_cubit.dart:36–39,145–147,204–208` | `_preDropBoard`/`_preDropSlots` mutable fields | -8 |
| `models/cascade_board.dart:34–36` | Duplicate `binColumns` constant | -3 |
| `models/cascade_board.dart:46–51` | Dead `leverAt` method | -6 |
| `theme/cascade_colors.dart:21–22` | Unused `binCorrect` color | -2 |
| `view/widgets/cascade_results_overlay.dart:86,90` | Repeated `onViewPuzzle` null guard | -2 |
| `view/widgets/bin_widget.dart:32,65` | Redundant outer `SizedBox` | -4 |
| **Total** | | **~40 lines** |

---

### Simplification Recommendations

1. **Remove `unassignBall`** (most impactful YAGNI)
   - Current: Public method with 3 guard checks, zero callers in the view layer.
   - Proposed: Delete entirely. Add only if drag-back-to-tray is designed and built.
   - Impact: -11 lines, removes dead public API.

2. **Remove mutable pre-drop cubit fields**
   - Current: `_preDropBoard`/`_preDropSlots` snapshot state outside of `CascadeState`, with fallback paths that already do the right thing.
   - Proposed: Rely on the existing fallbacks in `reset()`. All game state belongs in `CascadeState`.
   - Impact: -8 lines, restores cubit purity.

3. **Collapse `dropSlotColumns`/`binColumns` to one constant**
   - Current: Two constants with identical values; a comment admits they are the same.
   - Proposed: Single `static const centerColumns = [1, 2, 3]`.
   - Impact: -3 lines, removes misleading dual naming.

4. **Remove dead `leverAt` method**
   - Current: A board-level lookup that can never serve the simulator's actual need (index) and has no other caller.
   - Proposed: Delete.
   - Impact: -6 lines.

5. **Simplify `BallId.label`**
   - Current: Three-arm switch returning ordinal strings.
   - Proposed: `'${index + 1}'`.
   - Impact: -4 lines.

6. **Simplify `CascadeState.loading()` constructor**
   - Current: Explicit initialization of every field, duplicating defaults from the main constructor.
   - Proposed: Delegating constructor with only the two non-default fields.
   - Impact: -5 lines, single source of default values.

---

### YAGNI Violations

- **`unassignBall`**: Represents a "remove ball from slot" interaction that does not exist in the UI. No design calls for it now.

- **`CascadeColors.binCorrect`**: A green win-state bin color with no current consumer. The bins are neutral-colored regardless of outcome. Add when the visual feature ships.

- **`CascadeBoard.leverAt`**: A convenience accessor whose return type (`Lever?`) cannot serve the only real lookup need (an index for `flipLever`). No caller exists.

---

### What Is Appropriately Complex

The following complex code is load-bearing and should not be simplified:

- **`_gravityEase` and `_solveQuadraticTime`** in `CascadeBoardWidget`: Physics-based animation timing is inherently mathematical. The binary search for per-ball start times is called once per drop, not per frame.
- **`PuzzleGenerator._countSolutions`**: Enumerating 6 permutations × 2^N lever states is the correct approach for a puzzle with a uniqueness requirement. The inner loop is well-commented.
- **`BallSimulator._simulateBall`**: Wall bounce and bin bounce position lists are load-bearing data for the animation layer. The complexity is justified by the animation precision it enables.
- **`_interpolatedPosition` in `CascadeBoardWidget`**: Arc math for deflection, wall bounce, and bin bounce is dense but each branch is distinct behavior. The comments adequately explain each case.

---

### Final Assessment

**Total potential LOC reduction**: ~40 lines out of ~780 total (~5%)
**Complexity score**: Low–Medium

The game is well-structured overall. The logic and animation layers carry appropriate complexity for the behavior they deliver. The simplification opportunities are concentrated in dead code (`unassignBall`, `leverAt`, `binCorrect`), a duplicate constant (`binColumns`), and minor structural issues (pre-drop mutable fields, loading constructor, bin widget wrapper).

**Recommended action**: Proceed with simplifications. Items 1–4 (dead code and duplicate constant) are clean removals with no risk. Items 5–6 are polish. The pre-drop field refactor (item 2) is the most architecturally meaningful change and worth doing as a standalone commit.
