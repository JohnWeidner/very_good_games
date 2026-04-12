---
date: 2026-04-12
topic: chromix-component-overpower
---

# Chromix Component Overpower

## What We're Building

Allow a primary color to overpower an adjacent secondary color when the primary is a component of that secondary. Currently, secondary cells are fully locked (`isLocked` returns true for all secondaries), so the only way to replace a secondary is via the hold-to-overpower timer after a mix. This change adds a second path: drag a component primary onto a secondary to replace it directly.

For example, if a cell is Orange (Red + Yellow), dragging Red or Yellow onto it replaces it with the dragged primary. Dragging Blue onto Orange is not allowed (Blue is not a component of Orange). This gives players a recovery path when they accidentally create a secondary by lifting their finger too early during a mix, without needing to use Undo.

## Why This Approach

Three approaches were considered:

1. **Cubit-only change** (selected): Modify the `isLocked` guard and overpower branch in `ChromixCubit._handleDragOntoColor`, add `isComponentOf` to `ColorMixer`, and relax the `_hasTrappedCell` check in the generator. Minimal scope (~20-30 lines of logic), no UI changes needed.

2. **Cubit + UI feedback**: Same logic changes plus a visual shake/flash when a non-component overpower is attempted. Better UX but more work. Can be added later if players are confused.

3. **Unified overpower refactor**: Merge timer-overpower and component-overpower into one concept. Cleaner long-term but larger refactor for the same user benefit. Premature.

Approach 1 was chosen because the change is small, isolated, and the existing timer-overpower already provides the "hold to overpower" affordance. Adding the tap-again path is purely additive.

## Key Decisions

- **Component-only overpower**: A primary can only overpower a secondary that contains it (Red can overpower Orange and Purple; Blue can overpower Green and Purple; Yellow can overpower Orange and Green). Non-component combinations are blocked (no-op).
- **Move counting**: Component-overpower counts as a move, same as the timer-overpower. Both paths are considered two moves total (the original mix + the overpower).
- **Keep timer-overpower**: The existing hold-to-overpower timer stays. Both mechanisms coexist as two ways to achieve the same result.
- **Update generator's trapped-cell check**: Currently, a pre-filled primary next to a pre-filled secondary is flagged as "trapped" (no valid neighbors). With component-overpower, a primary adjacent to its parent secondary is not trapped. This relaxation allows more starting grid variety.
- **Solver unchanged**: The backtracking solver doesn't model moves — it tries all possible final states. Component-overpower doesn't change which final states are valid, so the solver needs no changes.
- **Generator simulation unchanged**: `_simulateMoves` only uses spread and mix during forward generation. Overpower isn't used during puzzle construction, so the simulation logic stays the same.

## Open Questions

- Should the dead overpower branch (line 211-228 in `chromix_cubit.dart`) be cleaned up or documented, given that it was previously unreachable code that now becomes live?
- Should existing daily puzzles (already generated/cached) be invalidated, or will the change be backward-compatible? (Likely compatible since it only adds player options, doesn't change valid final states.)
- Should the scoring thresholds be adjusted given the slightly easier recovery? (Probably not — the effect is minor and the star rating already accounts for move count.)
