# Test Quality Review — Cascade Ball-Routing Puzzle

**Branch**: `feat/cascade-ball-routing-puzzle`
**Reviewed**: 2026-04-08
**Stack**: Flutter / Dart, bloc_test ^10.0.0, mocktail ^1.0.4, flutter_test

---

## Test Run

**Result**: All 62 tests pass (0 failures).

The test suite runs cleanly across all layers. The one failure in the first run was a test runner artefact (coverage output path did not exist) — re-running without the coverage flag produced a clean pass.

---

## Coverage Summary

- **Test run**: Pass — 62/62
- **Files with tests**: 12/18 source files
- **Missing test files**: 6 (see below)

### Missing Test Files

| Source File | Assessment |
|---|---|
| `lib/games/cascade/cascade_game.dart` | Low priority — `GameDefinition` is thin routing/metadata glue; no custom logic to test. Acceptable to omit. |
| `lib/games/cascade/cubit/cascade_state.dart` | No dedicated file needed — state is exercised exhaustively through `cascade_cubit_test.dart`. Acceptable. |
| `lib/games/cascade/view/cascade_page.dart` | **Missing** — see finding below. |
| `lib/games/cascade/view/widgets/ball_tray.dart` | **Missing** — see finding below. |
| `lib/games/cascade/view/widgets/cascade_board_widget.dart` | **Missing** — see finding below. |
| `lib/games/cascade/view/widgets/cascade_results_overlay.dart` | **Missing** — see finding below. |

---

## State Management Test Quality

### `cascade_cubit_test.dart`

**Overall**: Good coverage of the happy path and most guard conditions. Two important gaps and one pattern deviation.

#### Pattern Deviation: cubit tested directly instead of with `bloc_test`

The VGV project convention (per `CLAUDE.md`) is `bloc_test` for cubits. The chromix game (`chromix_cubit_test.dart`) uses direct instantiation rather than `blocTest()` as well, so this is a cross-game inconsistency rather than a per-file problem. The cascade test follows the chromix pattern exactly, so it is internally consistent. That said, `blocTest()` would eliminate the manual `_waitForReady` helper and `cubit.close()` in every test, and would make the state emission sequence explicit. This is flagged as a suggestion.

#### Finding 1 — `completeDrop` test does not cover the won branch deterministically (Important)

```dart
// cascade_cubit_test.dart:174
cubit..drop()..completeDrop();
expect(
  cubit.state.status,
  anyOf(CascadeStatus.won, CascadeStatus.failed),
);
```

`anyOf(won, failed)` accepts any outcome. The test always passes regardless of whether `completeDrop` computes a correct score on win, clears the session on win, or handles `dropResult == null` gracefully. The won branch — which sets `score`, clears storage, and persists no session — is never asserted. A seed with a known-win configuration (identity slot assignment `[ball1, ball2, ball3]` with identity `binOrder [0,1,2]` and no levers) would produce a deterministic win in one drop. The failed path also has no assertion beyond the status field.

**Fix**: Create two separate tests — one using a seed/board that guarantees a win (or construct `CascadeState` directly) and one that guarantees a failure. Assert `score` is non-null and matches `cascadeScore(1)` on win; assert `score` is null on failure; verify `saveSession(key, null)` is called on win.

#### Finding 2 — `reset` test is conditionally skipped if seed 42 produces a first-attempt win (Important)

```dart
// cascade_cubit_test.dart:204
if (cubit.state.status == CascadeStatus.failed) {
  cubit.reset();
  // assertions...
}
```

If seed 42 happens to produce a win on the first drop, the entire `reset` body is silently skipped and the test reports passing with zero assertions. This is an anti-pattern: the test provides false confidence because it can succeed without verifying anything. The `reset` method is non-trivial — it restores `_preDropBoard`, `_preDropSlots`, preserves `attempts`, and re-emits `configuring` — and it deserves a test that actually runs.

**Fix**: Use a seed that is guaranteed to fail on the default slot arrangement (or flip a lever to ensure failure), so that the reset assertions always execute. Alternatively, construct the cubit state directly with a `DropResult(isWin: false)` to remove the dependency on the puzzle generator.

#### Finding 3 — Session restoration path is entirely untested (Important)

`CascadeCubit._initialize` contains a full deserialization path: it reads a stored session, calls `_deserializeState`, and emits the restored state. There is no test that:
- Sets up `storageRepository.getSession()` to return a valid session map
- Verifies the cubit emits the restored state (correct levers, attempts, status)
- Covers the `dropping → failed` status normalisation on deserialization
- Covers the corrupted-data `on Object` catch block (which calls `saveSession(key, null)`)

The storage mock always returns `null` in `setUp`, so this entire branch is dead in the test suite. Given that session restoration is the primary persistence mechanism, this is a significant gap.

**Fix**: Add at least three tests: (1) valid session restores state correctly, (2) a session with status `dropping` is normalised to `failed`, (3) a corrupted session (e.g. missing key) triggers `saveSession(key, null)` and falls through to a fresh puzzle.

#### Finding 4 — `skipAnimation` is not tested (Suggestion)

`skipAnimation` is a one-line guard that delegates to `completeDrop`. It does nothing if status is not `dropping`. Given it is a public method and part of the UI interaction contract (tapping the board during a drop), it warrants a dedicated test verifying that: (a) it triggers `completeDrop` when dropping, and (b) it is a no-op in other statuses.

#### Finding 5 — `resetWithSeed` is not tested (Suggestion)

`resetWithSeed` is gated by `kDebugMode` in the view but is a public cubit method. Its async initialization path is identical to the main initializer and is fully reachable. A test confirming it emits loading then transitions to configuring with a new board would prevent regressions in the dev-only debug flow.

---

## Logic Test Quality

### `ball_simulator_test.dart`

**Overall**: Good foundation. Happy paths and basic win/loss detection are covered. Two logic gaps.

#### Finding 6 — Wall bounce path is partially tested but not asserted on `wallBounces` (Important)

The test `'lever at wall edge does not deflect but still flips'` constructs a board that causes a wall bounce and checks `finalBin`, but never asserts that `path.wallBounces` is non-empty. The `wallBounces` set drives the animation (two extra positions are added per bounce), so an incorrect value would silently produce a broken animation while all assertions still pass.

**Fix**: Add `expect(result.paths[0].wallBounces, isNotEmpty)` and verify the exact number of extra positions added (3 instead of 1 for a bounce row).

#### Finding 7 — `leverFlips` are never asserted in any test (Important)

`BallPath.leverFlips` records which lever flipped at which step, and `CascadeBoardWidget._animatedLevers` depends on this to replay lever animations. None of the simulator tests assert on `leverFlips`. A regression that cleared or mis-populated the list would not be caught.

**Fix**: In the existing `'lever deflects ball and flips'` test, add assertions that `result.paths[1].leverFlips` has length 1 and that `leverFlips[0].leverIndex == 0` and `leverFlips[0].step` points to the correct position index.

#### Finding 8 — Sequential lever flip interaction is not fully asserted (Suggestion)

The test `'sequential drops: first ball flips lever for second'` checks final bin positions but does not verify the board state after the first ball. The core mechanic of Cascade — lever state carries across balls — should have at least one explicit check that the lever direction post-first-ball differs from the initial direction, confirming that `BallSimulator.simulate` passes the mutated board forward.

### `puzzle_generator_test.dart`

**Overall**: Strong. Determinism, bounds, uniqueness, and bin structure are all covered. One gap.

#### Finding 9 — Uniqueness property (single solution) is not verified (Suggestion)

The generator's primary contract is that it produces a puzzle with exactly one winning configuration. This is checked internally by `_countSolutions`, but no test verifies it from the outside. The test could call `BallSimulator.simulate` across all permutations for a generated puzzle and count wins, expecting exactly 1. Without this, a regression that made `_countSolutions` always return 0 would silently fall through to the fallback without any test failing.

### `score_calculator_test.dart`

**Overall**: Excellent. All discrete score values are tested with named tests, boundary and beyond-boundary cases are covered, and the test names read as specification. No issues.

---

## Model Test Quality

### `lever_test.dart`

**Overall**: Strong. Covers equality, serialization round-trip, flip, and double-flip. No issues.

### `cascade_board_test.dart`

**Overall**: Good. Covers constants, `leverAt`, `flipLever`, `resetLevers`, equality, serialization round-trip, and unmodifiable list guard. One minor gap.

#### Finding 10 — `fromJson` with an invalid direction string is not tested (Suggestion)

`Lever.fromJson` and `CascadeBoard.fromJson` use `LeverDirection.values.byName()` which throws `ArgumentError` on an unknown string. This is the most likely serialization failure mode (e.g. a schema migration). Testing the error path would complement the existing round-trip test.

### `drop_result_test.dart`

**Overall**: Thin but adequate for pure value types. Tests equality only. No issues for models that have no methods beyond Equatable.

### `ball_test.dart`

**Overall**: Adequate. Tests `label`, `index`, and count. No issues.

---

## UI Component Test Quality

### `ball_widget_test.dart`

**Overall**: Good. Tests label rendering for all three balls and that `ballColor` returns distinct colors. The distinct-color assertion could be stronger (checking specific colors) but the current form catches regressions.

### `bin_widget_test.dart`

**Overall**: Thin. Two tests exist but one is essentially a smoke test.

#### Finding 11 — Tautological assertion in second `BinWidget` test (Important)

```dart
// bin_widget_test.dart:23
testWidgets('renders without isCorrect set', (tester) async {
  await tester.pumpWidget(/* ... BinWidget ... */);
  expect(find.byType(BinWidget), findsOneWidget);
});
```

Finding a widget you just explicitly pumped into the tree proves nothing about its rendering. The assertion cannot fail under any non-catastrophic circumstance. It inflates coverage without catching bugs.

**Fix**: Assert on rendered content (e.g. `expect(find.text('1'), findsOneWidget)` for `BallId.ball1`), or remove this test entirely if it adds no distinct coverage over the first test.

### `lever_widget_test.dart`

**Overall**: Good. Tests tap callback when enabled and tap suppression when disabled. The animation behaviour (`didUpdateWidget` triggering `_triggerImpactAnimation`) is not tested, which is acceptable for a visual-only animation.

### `instructions_dialog_test.dart`

**Overall**: Good. Tests show, content presence, and dismiss flow in a single test. Adequate for a static content dialog.

---

## Missing Widget Tests

### Finding 12 — `cascade_page.dart` has no test (Important)

`CascadePage` is the top-level page and the integration point for all cubits. It handles the `loading` state (shows a progress indicator), the `won` state (shows results overlay and FAB), the `failed` state (shows reset button), and the `configuring` state (shows the board and drop button). None of these states are covered by a widget test. At minimum the following states should be tested:

- Loading state renders `CircularProgressIndicator`
- Configuring state renders the drop button enabled when all balls are assigned
- Configuring state renders the drop button disabled when a ball is unassigned
- Won state renders the results overlay (or FAB if `_showResults` is false)
- Failed state renders the reset button

These tests require providing a mock `CascadeCubit` seeded with a known state, using `BlocProvider.value`.

### Finding 13 — `ball_tray.dart` has no test (Important)

`BallTray` has meaningful conditional rendering: unassigned balls appear as draggable when `enabled`, and as non-interactive when `enabled: false`. It also filters out balls that are already assigned (`slotAssignments.contains(b)`). Neither path is tested.

**Fix**: Add tests for:
- All three balls appear when no slots are assigned
- An assigned ball does not appear in the tray
- Balls are wrapped in `Draggable` when `enabled: true`
- Balls are not wrapped in `Draggable` when `enabled: false`

### Finding 14 — `cascade_board_widget.dart` has no test (Important)

`CascadeBoardWidget` is the most complex widget in the game. It manages its own animation controller, subscribes to cubit state, starts/stops the drop animation, handles skip-animation taps, builds drop slots with drag targets, renders levers and bins, and computes `_animatedLevers`. None of this is tested.

A full end-to-end animation test is not required, but the following states should be covered:

- Configuring state: drop slots render with assigned balls; lever widgets are present and tappable
- Dropping state: a tap on the board calls `skipAnimation` (via `completeDrop`)
- Won/Failed state: landed balls are rendered via `_buildLandedBalls`; lever widgets have `enabled: false`

These tests require a mock cubit seeded with known states and a `MediaQuery` ancestor.

### Finding 15 — `cascade_results_overlay.dart` has no test (Important)

`CascadeResultsOverlay` renders score, attempts, star rating, and action buttons. The `onViewPuzzle` callback path (showing the "View Puzzle" button) is conditionally rendered only when `onViewPuzzle != null`. None of this is tested.

**Fix**: Add tests for:
- Score and attempt count are displayed correctly
- `StarRating` widget is present
- "View Puzzle" button appears when `onViewPuzzle` is provided and is absent when it is null
- "Back to Hub" button is always present

---

## Anti-Patterns Found

### `test/games/cascade/view/widgets/bin_widget_test.dart:23` — Tautological Assertion

**Anti-pattern**: No meaningful assertion
**Issue**: `expect(find.byType(BinWidget), findsOneWidget)` finds the widget you just pumped. It cannot fail under any working implementation and verifies nothing about rendering.
**Fix**: Assert on content or remove.

### `test/games/cascade/cubit/cascade_cubit_test.dart:204` — Conditional Test Body

**Anti-pattern**: Assertions hidden inside a conditional that can silently not execute
**Issue**: The `reset()` assertions only run if seed 42 yields a failure. If it yields a win, the test passes with zero assertions executed.
**Fix**: Use a deterministic failing board so the reset assertions always run.

### `test/games/cascade/cubit/cascade_cubit_test.dart:174` — Vacuous `anyOf` Assertion

**Anti-pattern**: Assertion that accepts the full range of possible outcomes
**Issue**: `anyOf(CascadeStatus.won, CascadeStatus.failed)` passes for any working or partially broken implementation. Neither the won nor failed branch is meaningfully exercised.
**Fix**: Split into two separate deterministic tests that each assert on the specific expected outcome and its side effects.

---

## Recommendations

1. **Add deterministic win and fail tests for `completeDrop` and `reset`** — Use a zero-lever board with identity `binOrder [0,1,2]` and `slotAssignments [ball1, ball2, ball3]` for a guaranteed win in one drop. Use any mis-routed configuration for a guaranteed fail. This eliminates the conditional test body and vacuous `anyOf` anti-patterns in one pass.

2. **Add session restoration tests to `cascade_cubit_test.dart`** — Set up `storageRepository.getSession()` to return a serialized session map and verify the cubit emits the correct restored state. This is currently a complete blind spot for the only persistence path.

3. **Add tests for `cascade_page.dart`, `ball_tray.dart`, `cascade_results_overlay.dart`, and `cascade_board_widget.dart`** — Four widgets with meaningful conditional rendering have no coverage. Start with `CascadePage` (loading, configuring, won states) and `CascadeResultsOverlay` (score display, button visibility) as these are highest user-visible risk.

4. **Assert on `leverFlips` and `wallBounces` in `ball_simulator_test.dart`** — These fields drive the animation layer. An uncaught regression here would produce a visually broken game with all tests still green.

5. **Remove or replace the tautological `BinWidget` test** — `expect(find.byType(BinWidget), findsOneWidget)` provides zero signal. Replace it with an assertion on content or remove it.

---

## Verdict

**Needs work before merging.** The logic layer (simulator, generator, score calculator) and models are well-tested. The cubit test structure is sound but has three important gaps: a non-deterministic reset test, a vacuous `completeDrop` assertion, and zero session-restoration coverage. Four UI widgets — `cascade_page.dart`, `ball_tray.dart`, `cascade_board_widget.dart`, and `cascade_results_overlay.dart` — are shipped with no test coverage at all. The tautological assertion in `bin_widget_test.dart` should be corrected. The logic test gaps for `leverFlips` and `wallBounces` are lower risk but should be addressed before the animation behaviour can be considered verified.
