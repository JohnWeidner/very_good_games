# Test Quality Review — Cascade Ball-Routing Puzzle

**Reviewed**: 2026-04-09
**Stack**: Flutter / Dart, bloc_test ^10.0.0, mocktail ^1.0.4, flutter_test

---

## Test Run

**Result**: All 76 tests pass (0 failures, 0 errors).

---

## Coverage Summary

- **Test run**: Pass — 76/76
- **Overall cascade coverage**: 392/934 lines = 42%
- **Files with tests**: 14/18 source files

### Per-File Coverage

| File | Coverage | Notes |
|---|---|---|
| `cubit/cascade_cubit.dart` | 94% (99/105) | 6 lines missed: `resetWithSeed`, `skipAnimation` |
| `cubit/cascade_state.dart` | 96% (22/23) | `stars` getter not covered |
| `logic/ball_simulator.dart` | 100% (40/40) | |
| `logic/puzzle_generator.dart` | 89% (50/56) | Fallback path not covered |
| `logic/score_calculator.dart` | 100% (4/4) | |
| `models/ball.dart` | 100% (4/4) | |
| `models/cascade_board.dart` | 100% (23/23) | |
| `models/drop_result.dart` | 100% (12/12) | |
| `models/lever.dart` | 100% (15/15) | |
| `cascade_game.dart` | 77% (10/13) | Route builder not covered |
| `view/cascade_page.dart` | 0% (0/126) | **No test file** |
| `view/widgets/ball_tray.dart` | 100% (17/17) | |
| `view/widgets/ball_widget.dart` | 100% (20/20) | |
| `view/widgets/bin_widget.dart` | 100% (13/13) | |
| `view/widgets/cascade_board_widget.dart` | 0% (1/334) | **No test file** |
| `view/widgets/cascade_results_overlay.dart` | 0% (0/46) | **No test file** |
| `view/widgets/instructions_dialog.dart` | 100% (24/24) | |
| `view/widgets/lever_widget.dart` | 64% (38/59) | Animation path not covered |

### Missing Test Files

| Source File | Severity |
|---|---|
| `view/cascade_page.dart` | Critical — top-level page, 0% coverage |
| `view/widgets/cascade_board_widget.dart` | Critical — most complex widget, 0% coverage |
| `view/widgets/cascade_results_overlay.dart` | Important — win screen, 0% coverage |

---

## State Management Test Quality

### `cascade_cubit_test.dart`

**Overall**: Solid coverage of the main lifecycle. Session restoration, corrupted session handling, status guard rails, and persistence are all tested. Several important gaps remain, and the pattern deviates from VGV convention.

#### Pattern Deviation — `bloc_test` not used for cubit tests

The project-wide VGV convention is `bloc_test` for cubit tests (`CLAUDE.md`: "Testing: `bloc_test` for cubits"). The chromix game uses `blocTest<ChromixCubit, ChromixState>(...)` throughout its cubit test. The cascade cubit test uses plain `test()` blocks with direct instantiation, a manual `_waitForReady` helper, and explicit `cubit.close()` calls in every test.

This is inconsistent with every other game in the project. `blocTest()` removes the need for the helper, makes the expected state emission sequence explicit and checked, and enforces teardown automatically. This is flagged as an important fix, not merely a suggestion, because it is a documented convention.

**Fix**: Migrate all cubit tests to `blocTest<CascadeCubit, CascadeState>(...)`. The `_waitForReady` helper is not needed with `blocTest` because the `wait` parameter handles async initialization.

#### Finding 1 — `skipAnimation` is not tested (Important)

`skipAnimation` is a public cubit method that the board widget calls when the user taps during animation. It is currently at 0% coverage (lines 191–193). A regression that broke the guard condition (`state.status != CascadeStatus.dropping`) would go undetected.

**Fix**: Add a test verifying (a) in `dropping` status `skipAnimation` transitions to `won` or `failed`, and (b) in `configuring` status `skipAnimation` is a no-op.

#### Finding 2 — `resetWithSeed` is not tested (Important)

`resetWithSeed` (lines 82–84) is at 0% coverage. It is gated behind `kDebugMode` in the view but is a public cubit method with its own code path — it re-emits `loading` and re-initializes with no storage. A test confirming the loading-then-configuring transition would cover the method and guard against regressions in the debug reload flow.

#### Finding 3 — `stars` getter on `CascadeState` not covered (Suggestion)

`CascadeState.stars` (line 73) returns `cascadeStars(attempts)` when `score != null`, else `0`. The zero branch is never reached in any test. A simple state-level test checking `stars == 0` pre-win and `stars == 3` post-win-on-first-attempt would complete coverage of this getter.

---

## Logic Test Quality

### `ball_simulator_test.dart`

**Overall**: Good. Happy path, win detection, loss detection, drop ordering, and the wall-bounce path are all covered. Two meaningful gaps remain.

#### Finding 4 — `leverFlips` are asserted for count and index but `step` is never checked (Important)

The test `'lever deflects ball and records leverFlip'` checks `leverFlips.length == 1` and `leverFlips[0].leverIndex == 0`, but never asserts `leverFlips[0].step`. The `step` field determines at which position in the animation the lever visual updates. An off-by-one in `step` would produce a visual glitch (lever flips a frame too early or too late) while all assertions still pass.

**Fix**: Add `expect(result.paths[1].leverFlips[0].step, <expected_index>)`. The expected value is the index in `positions` where the ball arrives at the lever row — in the two-lever test case this is deterministic.

#### Finding 5 — Wall bounce `wallBounces` set is asserted for size but not for the correct step index (Suggestion)

The `'wall bounce records wallBounces and extra positions'` test checks `path.wallBounces.length == 1` and total position count. It does not verify which step index is recorded in `wallBounces`. Like the lever flip step, this value drives animation timing. The step index is deterministic from the board layout used in the test, so asserting it would not add fragility.

#### Finding 6 — `_generateFallback` path in `puzzle_generator.dart` is not tested (Suggestion)

`PuzzleGenerator._generateFallback` (lines 175–188) is the last-resort path executed when 100 seed retries all fail. It is at 0% coverage. This path is difficult to trigger through the public `generate()` API, but it can be reached indirectly by passing a seed that exhausts all retries. Alternatively, the existence of the fallback board could be tested by checking that `generate()` always returns a board with 3 bins and 6 levers regardless of seed — a property test across a wide seed range would implicitly cover both paths.

### `score_calculator_test.dart`

**Overall**: Excellent. All discrete values, boundary cases, and beyond-boundary cases are covered with clearly named tests. No issues.

### `puzzle_generator_test.dart`

**Overall**: Strong. Determinism, bounds, uniqueness of lever positions, and bin structure are covered. One gap.

#### Finding 7 — Single-solution uniqueness is not verified (Suggestion)

The generator's primary contract is exactly one winning configuration per puzzle. `_countSolutions` enforces this internally, but no test verifies the contract from the outside. A regression where `_countSolutions` always returned 0 would silently fall through to the fallback without any test failing. A test that runs `BallSimulator.simulate` across all 6 × 2^n configurations for a generated puzzle and counts wins — expecting exactly 1 — would close this gap.

---

## Model Test Quality

### `lever_test.dart`

**Overall**: Strong. Covers `opposite`, `flip`, double-flip, equality, and serialization round-trip. No issues.

### `cascade_board_test.dart`

**Overall**: Good. Covers all public methods, equality, serialization, and the unmodifiable list guard. No issues.

### `drop_result_test.dart` and `ball_test.dart`

**Overall**: Adequate for pure value types. Equality is tested; no additional logic to cover.

---

## UI Component Test Quality

### `ball_widget_test.dart`

**Overall**: Good. Labels for all three balls are verified. `ballColor` returns distinct values for each ball. One minor improvement available: the distinct-color test does not verify which specific colors are returned, only that three unique values exist. This is acceptable.

### `bin_widget_test.dart`

**Overall**: Good. Three tests: label rendering per ball, and three-sided border verification via `BoxDecoration` inspection. No issues.

### `ball_tray_test.dart`

**Overall**: Good. Covers unassigned balls visible, all-assigned shows nothing, draggable when enabled, and non-draggable when disabled. All four meaningful states of `BallTray` are tested.

### `lever_widget_test.dart`

**Overall**: Adequate for interaction. Tap fires callback when enabled; tap is suppressed when disabled. The animation path (`didUpdateWidget` triggering `_triggerImpactAnimation`) is at 0% coverage, which is acceptable — visual-only animation behavior is low-value to widget-test.

### `instructions_dialog_test.dart`

**Overall**: Good. Tests show, all section headings visible, and dismiss flow in one test.

---

## Missing Widget Tests

### Finding 8 — `cascade_page.dart` has no test (Critical)

`CascadePage` / `_CascadeView` is the integration point for five BlocProviders, the `WinCelebration`, instructions auto-show, streak persistence, and the win listener. At 0% coverage, the following behaviors are entirely unverified:

- `loading` state renders `CircularProgressIndicator`
- `configuring` state renders the Drop button (enabled when all balls assigned, disabled otherwise)
- `failed` state renders the Reset button
- `won` state renders the Results FAB and, when tapped, the `CascadeResultsOverlay`
- Instructions are shown on first launch (`hasSeenInstructions` returns false)
- Instructions are not reshown after `markInstructionsSeen` is called

These tests require mocking the five cubit/repository dependencies and seeding `CascadeCubit` with known states via `BlocProvider.value` wrapping a `MockCascadeCubit`.

### Finding 9 — `cascade_board_widget.dart` has no test (Critical)

`CascadeBoardWidget` is the most complex widget in the game: it owns an `AnimationController`, reacts to `dropping` state transitions, builds drag-drop targets, renders `LeverWidget` per lever (enabled/disabled by status), renders `BinWidget` per bin, and handles skip-animation taps. At 0% coverage (334 lines untested), this is the largest risk in the test suite.

Minimum viable tests:

- In `configuring` state: lever widgets are present, `LeverWidget.enabled == true`, drop slots contain assigned ball widgets
- In `dropping` state: tapping the board calls `skipAnimation` on the cubit
- In `won`/`failed` state: `LeverWidget.enabled == false`; landed balls are rendered

### Finding 10 — `cascade_results_overlay.dart` has no test (Important)

`CascadeResultsOverlay` renders the win screen: score, attempt count, `StarRating`, `ShareResultButton`, and conditionally "View Puzzle" / "Back to Hub" buttons. The `onViewPuzzle` callback is only wired up when non-null.

Minimum viable tests:

- Score and attempt count are displayed
- `StarRating` widget is present
- "View Puzzle" button is visible when `onViewPuzzle` is provided, absent when null
- "Back to Hub" button is always present

These tests require a mock `ResultSharingCubit`, `CommunityStatsCubit`, `LeaderboardCubit`, and the Nostr identity/profile dependencies (or a narrow `BlocProvider.value` + mock setup).

---

## Anti-Patterns Found

No tautological assertions, mock-everything, or implementation-mirroring patterns were found in the existing tests. The cubit test has one structural issue described separately (conditional test body is not applicable anymore — the existing reset test now uses `_findLosingPermutation` to guarantee the failed state before calling `reset`).

---

## Recommendations

1. **Migrate `cascade_cubit_test.dart` to `blocTest`** — This is a documented VGV convention. Every other game in the project uses it. The manual `_waitForReady` + `cubit.close()` pattern is not idiomatic here. (Important)

2. **Add tests for `cascade_page.dart`** — Loading, configuring (Drop button enabled/disabled), failed (Reset button), and won (overlay or FAB) are all user-visible states with no coverage. This is the highest-risk gap. (Critical)

3. **Add tests for `cascade_board_widget.dart`** — At minimum: lever enabled/disabled by status, skip-animation tap in dropping state, landed balls shown post-drop. (Critical)

4. **Add tests for `cascade_results_overlay.dart`** — Score display, conditional "View Puzzle" button, always-present "Back to Hub" button. (Important)

5. **Add tests for `skipAnimation` and `resetWithSeed`** — Both are public cubit methods at 0% coverage. (Important)

6. **Assert `leverFlips[0].step` in `ball_simulator_test.dart`** — The step value drives animation timing; an off-by-one is not currently catchable. (Important)

---

## Verdict

**Needs work before merging.** The logic layer (simulator, score calculator) and all models are well-tested at or near 100% coverage. The cubit test is comprehensive for the core game lifecycle — session restoration, corruption recovery, and all status transitions are covered — but `skipAnimation` and `resetWithSeed` are untested public methods. The cubit tests also deviate from the project's `blocTest` convention used by every other game. The most significant gap is the UI layer: `cascade_page.dart` (0%, 126 lines) and `cascade_board_widget.dart` (0%, 334 lines) are completely untested, and `cascade_results_overlay.dart` (0%, 46 lines) has no coverage either. Taken together, the entire interactive surface of the game — how states are rendered, how user interactions are wired — has no widget test coverage.

**Critical issues**: 2 (missing tests for `cascade_page.dart`, `cascade_board_widget.dart`)
**Important issues**: 5 (missing `cascade_results_overlay.dart` tests, untested `skipAnimation`/`resetWithSeed`, `leverFlips.step` not asserted, `blocTest` convention deviation)
**Suggestions**: 5 (stars getter, wall-bounce step, fallback path, uniqueness property, sequential lever state assertion)
