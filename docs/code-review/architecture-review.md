## Architecture Review -- Cascade Ball-Routing Puzzle

**Branch**: `feat/cascade-ball-routing-puzzle`
**Date**: 2026-04-08
**Reviewer**: Architecture Review Agent

---

### Layer Separation

**Violations found: 0**

All dependency directions are correct across the Cascade module:

| Layer | Imports from | Status |
|-------|-------------|--------|
| `models/` | `equatable`, within-layer direct imports only | Clean |
| `logic/` | `models/` only | Clean |
| `cubit/` | `logic/`, `models/`, `core/` | Clean |
| `view/` | `cubit/`, `models/`, `logic/` (score_calculator only), `theme/`, `core/`, `nostr/` | Clean |
| `theme/` | `flutter/material.dart` only | Clean |
| `cascade_game.dart` | `core/`, `view/` | Clean |

Verified no reverse imports exist:
- `models/` does not import `cubit/`, `logic/`, `view/`, or `theme/`
- `logic/` does not import `cubit/`, `view/`, or `theme/`
- `cubit/` does not import `view/` or `theme/`

The `view/` layer imports `logic/logic.dart` in `cascade_results_overlay.dart` at line 7 to access `cascadeStars()`. This is a read-only utility function call (pure scoring logic), consistent with the Chromix pattern where `chromix_results_overlay.dart` similarly imports `logic/logic.dart` for score calculation. This is acceptable -- the logic layer provides pure functions that the view layer consumes.

**Clean files**: All 25 source files checked.

---

### State Management Assessment

**CascadeCubit**: Correct

- **Naming**: `CascadeCubit` and `CascadeState` follow established VGV Cubit naming convention (matches `ChromixCubit`/`ChromixState`, `SignalCubit`/`SignalState`).
- **State immutability**: `CascadeState` extends `Equatable`, all fields are `final`, lists in `CascadeBoard` are `List.unmodifiable()`. Copy is via `copyWith()`.
- **copyWith nullable pattern**: Uses `Type? Function()?` wrapper for `dropResult` and `score` fields (lines 82-95 of `cascade_state.dart`), correctly following the project convention for nullable fields that need explicit null-setting.
- **part-of pattern**: `cascade_state.dart` uses `part of 'cascade_cubit.dart'` (line 1), consistent with project convention.
- **Business logic location**: All game logic (simulation, puzzle generation, scoring) lives in `logic/`. The cubit delegates to `BallSimulator.simulate()`, `PuzzleGenerator.generate()`, and `cascadeScore()`. No business logic in view widgets.
- **Data access**: Cubit accesses `GameStorageRepository` for persistence. Views access it only through cubit or via `context.read<GameStorageRepository>()` for instructions/streaks (matching the established Chromix pattern).
- **Handler organization**: Methods are focused and single-purpose: `assignBall`, `unassignBall`, `swapSlots`, `flipLever`, `drop`, `completeDrop`, `skipAnimation`, `reset`. Each guards on status before mutating state.
- **Isolate usage**: Puzzle generation runs via `compute()` (line 48 of `cascade_cubit.dart`), properly keeping heavy computation off the main thread. The `_generatePuzzle` static method is correctly a top-level-compatible static for isolate execution.

**CascadeStatus enum**: Correct

- Five clear states: `loading`, `configuring`, `dropping`, `won`, `failed`. State machine transitions are well-guarded in cubit methods.

**Minor observation**: The `_preDropBoard` and `_preDropSlots` fields on `CascadeCubit` (lines 37-39) are mutable instance fields used for reset bookkeeping. This is a pragmatic choice -- they store the pre-drop snapshot to enable restoring configuration state after a failed drop. These are internal cubit fields not exposed in state, so they do not violate immutability of the emitted `CascadeState`. This is acceptable.

---

### Dependency Direction

**Direction violations: 0**

Dependency graph flows correctly:

```
cascade_game.dart --> core/, view/
view/ --> cubit/, models/, logic/ (score only), theme/, core/, nostr/
cubit/ --> logic/, models/, core/
logic/ --> models/
models/ --> (equatable only)
theme/ --> (flutter only)
```

No circular dependencies detected. No game module imports another game module.

The cross-module imports from `view/` to `nostr/` (sharing cubits, event builder, stats) are consistent with all existing games (`chromix`, `signal`, `guess_the_number`). The `nostr/` module provides app-level shared infrastructure that game views consume. These imports are:
- `cascade_page.dart` lines 9-13: Nostr cubit/repository providers (identical to Chromix pattern)
- `cascade_results_overlay.dart` lines 7-13: Sharing UI components, event builder

**Clean dependencies**: All packages.

---

### Package Structure

**Cascade module**: Complete

| Check | Status |
|-------|--------|
| Directory structure (models, logic, cubit, view, theme) | Present |
| Barrel files in every directory | Present and alphabetically ordered |
| `GameDefinition` implementation | Present (`cascade_game.dart`) |
| Registered in `main.dart` GameRegistry | Present (line 33) |
| `EventBuilder.buildCascadeResult()` for Nostr sharing | Present (event_builder.dart lines 85-113) |
| Uses shared `ResultSharingListener` | Present (cascade_results_overlay.dart line 36) |
| Uses shared `ShareResultButton` | Present (cascade_results_overlay.dart line 75) |
| Uses shared `CommunityStatsSection` | Present (cascade_results_overlay.dart line 78) |
| Uses shared `StarRating` | Present (cascade_results_overlay.dart line 73) |
| Uses `utcDateKey()` from core | Present (cascade_page.dart line 26) |
| Uses `GameStorageRepository.hasSeenInstructions()` | Present (cascade_page.dart line 102) |
| Uses `GameStorageRepository.markInstructionsSeen()` | Present (cascade_page.dart line 106) |
| Debug shuffle gated with `kDebugMode` | Present (cascade_page.dart line 146) |
| Uses `WinCelebration` shared widget | Present (cascade_page.dart line 165) |
| Single clear responsibility | Yes -- self-contained ball-routing puzzle |

**Test coverage assessment**:

| Source file | Test file | Status |
|------------|-----------|--------|
| `models/ball.dart` | `ball_test.dart` | Present |
| `models/cascade_board.dart` | `cascade_board_test.dart` | Present |
| `models/drop_result.dart` | `drop_result_test.dart` | Present |
| `models/lever.dart` | `lever_test.dart` | Present |
| `logic/ball_simulator.dart` | `ball_simulator_test.dart` | Present |
| `logic/puzzle_generator.dart` | `puzzle_generator_test.dart` | Present |
| `logic/score_calculator.dart` | `score_calculator_test.dart` | Present |
| `cubit/cascade_cubit.dart` | `cascade_cubit_test.dart` | Present |
| `view/widgets/ball_widget.dart` | `ball_widget_test.dart` | Present |
| `view/widgets/bin_widget.dart` | `bin_widget_test.dart` | Present |
| `view/widgets/lever_widget.dart` | `lever_widget_test.dart` | Present |
| `view/widgets/instructions_dialog.dart` | `instructions_dialog_test.dart` | Present |
| `view/widgets/cascade_board_widget.dart` | -- | **Missing** |
| `view/widgets/cascade_results_overlay.dart` | -- | **Missing** |
| `view/widgets/ball_tray.dart` | -- | **Missing** |
| `view/cascade_page.dart` | -- | Missing (consistent with Chromix pattern) |
| `cascade_game.dart` | -- | Missing (consistent with Chromix pattern) |

Three test files are missing for widget files that should have tests. The `cascade_page_test.dart` and `cascade_game_test.dart` omissions are consistent with the existing Chromix game module (which also lacks those tests).

---

### Detailed Findings

#### Important Issues

**1. Missing `cascade_results_overlay_test.dart`**
- File: `lib/games/cascade/view/widgets/cascade_results_overlay.dart`
- The Chromix reference game includes `chromix_results_overlay_test.dart`. This overlay contains sharing logic (`_share` method at line 109), score display, star rating, and Nostr integration. It should have a corresponding widget test to maintain parity with the established testing pattern.

**2. Missing `cascade_board_widget_test.dart`**
- File: `lib/games/cascade/view/widgets/cascade_board_widget.dart`
- At 553 lines this is the largest and most complex widget in the module, containing animation controllers, interpolation logic, drag-and-drop behavior, and multiple rendering paths depending on game status. The `_interpolatedPosition` method (lines 363-437) has non-trivial geometry calculations with wall bounces and arcs. Testing this widget would catch animation and layout regressions.

**3. Missing `ball_tray_test.dart`**
- File: `lib/games/cascade/view/widgets/ball_tray.dart`
- Contains drag-and-drop interaction logic (Draggable widgets). A widget test verifying that unassigned balls render, that balls can be dragged, and that the `onBallAssigned` callback fires would prevent interaction regressions.

#### Suggestions

**1. Consider extracting board position interpolation to logic layer**
- File: `lib/games/cascade/view/widgets/cascade_board_widget.dart`, lines 363-437
- The `_interpolatedPosition` method is a pure function computing pixel positions from path data and cell size. Extracting it to `logic/` (e.g., as a static method or standalone function) would make the geometry calculations unit-testable without widget test overhead, and reduce the widget's 553-line footprint. The Chromix module keeps rendering logic in widgets, so this is not required by convention, but the complexity of wall-bounce and arc calculations in Cascade warrants it.

**2. Pre-drop snapshot could be part of persisted state**
- File: `lib/games/cascade/cubit/cascade_cubit.dart`, lines 37-39
- `_preDropBoard` and `_preDropSlots` are mutable instance fields that store pre-drop configuration for the reset feature. If the app process is killed during a `failed` state and the session is restored, the reset falls back to `state.board.resetLevers(state.initialLevers)` and `defaultSlotAssignments` (line 238) rather than the actual pre-drop configuration. Including pre-drop data in the serialized session would provide exact reset behavior across app restarts.

**3. Duplicate `utcDateKey()` call in results overlay**
- File: `lib/games/cascade/view/widgets/cascade_results_overlay.dart`, line 80
- The overlay calls `utcDateKey()` independently for the leaderboard `dTag` rather than receiving the `dateKey` already computed in `CascadePage`. If a user completes a game around midnight UTC, the page's `dateKey` and the overlay's `utcDateKey()` could theoretically differ. This is a pre-existing pattern from Chromix (`chromix_results_overlay.dart` line 81 does the same), so it is not a new issue introduced by this branch.

---

### Dart Analysis

`dart analyze lib/games/cascade/` returned **No issues found**. Zero warnings, zero info hints, zero errors.

---

### Compliance with "Adding a New Game" Checklist

Per the project's CLAUDE.md "Adding a New Game" section:

| Step | Requirement | Status |
|------|-------------|--------|
| 1 | Create `lib/games/cascade/` with models, logic, cubit, view, theme | Done |
| 2 | Implement `GameDefinition` in `cascade_game.dart` | Done |
| 3 | Register in `main.dart` GameRegistry | Done |
| 4 | Add `EventBuilder.buildCascadeResult()` for Nostr sharing | Done |
| 5 | Use shared overlay widgets | Done (ResultSharingListener, ShareResultButton, CommunityStatsSection, StarRating) |
| 6 | Use `utcDateKey()` for date formatting | Done |
| 7 | Use `GameStorageRepository` for persistence | Done (sessions, streaks, instructions seen) |

---

### Summary of Findings

| # | Severity | Description | Location |
|---|----------|-------------|----------|
| 1 | Important | Missing `cascade_results_overlay_test.dart` -- Chromix has its equivalent test | `lib/games/cascade/view/widgets/cascade_results_overlay.dart` |
| 2 | Important | Missing `cascade_board_widget_test.dart` -- 553-line widget with animation and geometry logic | `lib/games/cascade/view/widgets/cascade_board_widget.dart` |
| 3 | Important | Missing `ball_tray_test.dart` -- drag-and-drop interaction widget | `lib/games/cascade/view/widgets/ball_tray.dart` |
| 4 | Suggestion | Extract `_interpolatedPosition` to logic layer for unit testability | `cascade_board_widget.dart:363-437` |
| 5 | Suggestion | Include pre-drop snapshot in persisted session for exact reset across restarts | `cascade_cubit.dart:37-39` |
| 6 | Suggestion | Duplicate `utcDateKey()` call in overlay (pre-existing pattern from Chromix) | `cascade_results_overlay.dart:80` |

### Verdict

**Ready to merge after adding 3 missing widget tests.** Architecture is clean -- zero layer violations, zero dependency direction issues, zero Dart analysis issues. The module follows all VGV conventions and the "Adding a New Game" checklist completely. The three important items are all missing test files for interaction-heavy widgets.
