---
title: "feat: add chromix component-overpower"
type: feat
date: 2026-04-12
---

## feat: add chromix component-overpower - Minimal

Allow a primary color to overpower an adjacent secondary color when the primary is a component of that secondary. Currently secondary cells are fully locked, so the only recovery path is the hold-to-overpower timer after a mix. This adds a direct drag path: drag a component primary onto a secondary to replace it immediately (1 move).

For example: Orange = Red + Yellow. Dragging Red or Yellow onto Orange replaces it. Dragging Blue onto Orange is a no-op (Blue is not a component of Orange).

Both mechanisms (timer-overpower and component-overpower) coexist. This gives players a faster recovery when they accidentally create a secondary by lifting their finger too early during a mix.

## Acceptance Criteria

- [ ] `ColorMixer.isComponentOf(primary, secondary)` returns `true` for valid component relationships (6 valid pairs), `false` otherwise
- [ ] Dragging a component primary onto any secondary (pre-filled or player-created) replaces the secondary with the primary
- [ ] Dragging a non-component primary onto a secondary remains a no-op
- [ ] Component-overpower increments `moveCount` by 1
- [ ] Component-overpower is recorded in move history and undoable (restores the secondary)
- [ ] Component-overpower triggers contiguity recomputation and win-condition check
- [ ] No overpower timer starts after a component-overpower (it's a terminal action)
- [ ] Generator's `_hasTrappedCell` considers a primary adjacent to its parent secondary as not trapped
- [ ] Existing timer-overpower behavior is unchanged
- [ ] All new and modified logic has unit tests

## Context

### Guard placement

The `isLocked` getter on `ColorCell` ([chromix_cell.dart:70](lib/games/chromix/models/chromix_cell.dart#L70)) returns `color.isSecondary` and has no access to the drag color. The component check must live in the cubit, not the model.

**Approach**: In `_handleDragOntoColor` ([chromix_cubit.dart:184](lib/games/chromix/cubit/chromix_cubit.dart#L184)), change the guard from:

```dart
if (targetCell.isLocked) return;
```

to:

```dart
if (targetCell.isLocked && !ColorMixer.isComponentOf(dragColor, targetCell.color)) return;
```

This lets component primaries through to the existing overpower branch at lines 211-228, which was previously dead code and now becomes live.

### Dead code becomes live

The overpower branch at [chromix_cubit.dart:211-228](lib/games/chromix/cubit/chromix_cubit.dart#L211-L228) checks `dragColor.isPrimary && targetCell.color.isSecondary` and replaces the secondary with the dragged primary. This was unreachable because the `isLocked` guard at line 184 returned early for all secondaries. With the guard relaxed for component primaries, this branch activates. Add a brief comment explaining the history.

### Generator relaxation

In `_hasTrappedCell` ([puzzle_generator.dart:197-222](lib/games/chromix/logic/puzzle_generator.dart#L197-L222)), a pre-filled cell is "trapped" if it has no adjacent empty or same-color cell. With component-overpower, a primary adjacent to its parent secondary is not trapped — it can overpower that secondary. Add `ColorMixer.isComponentOf` as a third "open neighbor" condition.

### `isComponentOf` mapping

| Primary | Component of |
|---------|-------------|
| Red | Orange, Purple |
| Yellow | Orange, Green |
| Blue | Green, Purple |

All other primary-secondary combinations return `false`. Inputs where primary is not actually primary or secondary is not actually secondary return `false`.

### Test changes

- **New**: `ColorMixer.isComponentOf` unit tests — all 18 combinations (6 primary x 3 secondary) plus invalid inputs ([color_mixer_test.dart](test/games/chromix/logic/color_mixer_test.dart))
- **Update**: "drag onto secondary cell is no-op (locked)" test at [chromix_cubit_test.dart:405](test/games/chromix/cubit/chromix_cubit_test.dart#L405) — split into:
  - "component primary overpowers secondary" (Red onto Orange = Red, moveCount +1)
  - "non-component primary onto secondary is no-op" (Blue onto Orange, unchanged)
  - "undo after component-overpower restores secondary"
- **New**: Generator test verifying a primary adjacent only to its parent secondary is not flagged as trapped ([puzzle_generator_test.dart](test/games/chromix/logic/puzzle_generator_test.dart))

### Deferred

- Instructions dialog update mentioning component-overpower
- Visual feedback (shake/flash) for rejected non-component overpower attempts
- Analytics distinguishing component-overpower from timer-overpower

## MVP

### `color_mixer.dart` — add `isComponentOf`

```dart
// color_mixer.dart
/// Whether [primary] is a component of [secondary].
///
/// For example, Red is a component of Orange (Red + Yellow) and
/// Purple (Red + Blue).
static bool isComponentOf(ChromixColor primary, ChromixColor secondary) {
  if (!primary.isPrimary || !secondary.isSecondary) return false;
  final mixed = mix(/* the other component */, primary);
  // Implementation: check if mixing primary with any other primary yields secondary
  return ChromixColor.primaries.any(
    (other) => other != primary && mix(primary, other) == secondary,
  );
}
```

### `chromix_cubit.dart` — relax guard at line 184

```dart
// chromix_cubit.dart:184
// Before:
if (targetCell.isLocked) return;

// After:
if (targetCell.isLocked &&
    !ColorMixer.isComponentOf(dragColor, targetCell.color)) {
  return;
}
```

### `puzzle_generator.dart` — relax `_hasTrappedCell`

```dart
// puzzle_generator.dart — inside the neighbor check loop
// Add as a third "open neighbor" condition:
if (cell is ColorCell &&
    neighbor is ColorCell &&
    ColorMixer.isComponentOf(cell.color, neighbor.color)) {
  hasOpenNeighbor = true;
}
```

## References

- Brainstorm: [docs/brainstorm/2026-04-12-chromix-component-overpower-brainstorm-doc.md](docs/brainstorm/2026-04-12-chromix-component-overpower-brainstorm-doc.md)
