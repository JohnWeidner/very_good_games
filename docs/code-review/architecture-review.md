# Architecture Review: `lib/games/cascade/`

**Date**: 2026-04-09
**Scope**: `lib/games/cascade/` and all subdirectories
**Reviewer**: Architecture Review Agent

---

## Layer Separation

### Expected layers (per CLAUDE.md):
- `models/` -- data models (sealed classes, enums, equatable)
- `logic/` -- pure Dart game logic (calculators, generators, evaluators)
- `cubit/` -- state management (Cubit + part-of State)
- `view/` -- Flutter widgets (page, grid, overlays)
- `theme/` -- game-specific colors
- `cascade_game.dart` -- `GameDefinition` implementation

### Layer dependency matrix

| Source layer | Allowed dependencies | Actual dependencies | Status |
|---|---|---|---|
| models/ | equatable, dart:core | equatable only | Clean |
| logic/ | models/, dart:math | models/ + dart:math | Clean |
| cubit/ | models/, logic/, core/ | models/, logic/, core/ | Clean |
| view/ | cubit/, models/, theme/, core/, nostr/ | cubit/, models/, theme/, core/, nostr/ | Clean |
| theme/ | flutter/material | flutter/material only | Clean |
| cascade_game.dart | core/, view/ | core/, view/ | Clean |

### Import scan results

**Violations found: 0**

All dependency flows follow the expected direction:
- `models/` has zero upward dependencies (no imports of logic, cubit, or view)
- `logic/` depends only on `models/` (correct)
- `cubit/` depends on `models/` and `logic/` (correct -- state management calls logic)
- `view/` depends on `cubit/`, `models/`, `theme/`, and shared app-level modules (correct)
- No view file imports logic directly (business logic stays in cubit)
- No model file imports Flutter (pure Dart)

**Clean files**: All 25 files checked.

---

## State Management Assessment

### CascadeCubit

**File**: `lib/games/cascade/cubit/cascade_cubit.dart`

| Check | Result |
|---|---|
| Naming | Correct: `CascadeCubit` is descriptive and follows VGV Cubit naming |
| State immutability | Correct: `CascadeState` is Equatable with all-final fields |
| `part of` pattern | Correct: `cascade_state.dart` uses `part of 'cascade_cubit.dart'` |
| Business logic location | Correct: all game logic (assign, flip, drop, reset) is in the Cubit |
| Data access | Correct: Cubit calls `GameStorageRepository` -- view never touches storage directly for game state |
| Complexity match | Correct: Cubit with multiple states is appropriate for this game flow |
| copyWith pattern | Correct: nullable fields (`dropResult`, `score`) use the `Type? Function()?` wrapper pattern as specified in CLAUDE.md |
| Persistence | Correct: `_persistSession()` uses `unawaited()` for fire-and-forget storage |
| Isolate usage | Correct: `compute(PuzzleGenerator.generate, dailySeed)` keeps heavy computation off the main thread |

**Rating**: Correct -- no issues.

### CascadeState

**File**: `lib/games/cascade/cubit/cascade_state.dart`

| Check | Result |
|---|---|
| Equatable props | Correct: all 7 fields listed in `props` |
| Enum status | Correct: `CascadeStatus` has 5 clear states (loading, configuring, dropping, won, failed) |
| Loading state factory | Correct: `CascadeState.loading()` creates a minimal placeholder |
| Derived getters | Correct: `allBallsAssigned` and `stars` are computed from state, not stored |

**Rating**: Correct -- no issues.

### View state management

**File**: `lib/games/cascade/view/cascade_page.dart`

- `_showResults` is tracked as local widget state (`bool`) in `_CascadeViewState`. This is UI-only state (overlay visibility) and is appropriate for `setState`.
- The view correctly delegates all game actions to `CascadeCubit` via `context.read<CascadeCubit>()`.
- `BlocConsumer` is used appropriately -- `listenWhen` filters for win transitions, `builder` rebuilds on all state changes.

**Rating**: Correct -- no issues.

---

## Dependency Direction

### Internal dependency graph (cascade module)

```
cascade_game.dart --> core/, view/
view/ --> cubit/, models/, theme/, core/, nostr/
cubit/ --> logic/, models/, core/
logic/ --> models/
models/ --> (none, only equatable)
theme/ --> (none, only flutter/material)
```

**Direction violations: 0**
**Circular dependencies: 0**

All arrows flow downward: view -> cubit -> logic -> models. No reverse or circular dependencies within the cascade module.

### External dependency check

The cascade module imports from these external (app-level) modules:

1. `package:very_good_games/core/core.dart` -- Shared infrastructure (correct)
2. `package:very_good_games/nostr/sharing/` -- Nostr result sharing (correct for view layer)
3. `package:very_good_games/nostr/stats/` -- Community stats (correct for view layer)
4. `package:very_good_games/nostr/profile/profile.dart` -- Profile cubit (correct for view layer)
5. `package:nostr_identity/nostr_identity.dart` -- Identity repository (correct -- used in BlocProvider creation)

No cascade module is imported by nostr or core modules, so dependency direction is clean.

---

## Package Structure

### Directory completeness

| Expected component | Present | File(s) |
|---|---|---|
| `models/` with barrel file | Yes | `models.dart` exports 4 files alphabetically |
| `logic/` with barrel file | Yes | `logic.dart` exports 3 files alphabetically |
| `cubit/` with barrel file | Yes | `cubit.dart` exports 1 file |
| `view/` with barrel file | Yes | `view.dart` exports page + widgets barrel |
| `view/widgets/` with barrel file | Yes | `widgets.dart` exports 7 files alphabetically |
| `theme/` with barrel file | Yes | `theme.dart` exports 1 file |
| `cascade_game.dart` (`GameDefinition`) | Yes | Implements `GameDefinition` correctly |

**Rating**: Complete -- all expected components present.

### Test coverage

| Source file | Test file | Status |
|---|---|---|
| `cascade_game.dart` | `cascade_game_test.dart` | Present |
| `cubit/cascade_cubit.dart` | `cubit/cascade_cubit_test.dart` | Present |
| `logic/ball_simulator.dart` | `logic/ball_simulator_test.dart` | Present |
| `logic/puzzle_generator.dart` | `logic/puzzle_generator_test.dart` | Present |
| `logic/score_calculator.dart` | `logic/score_calculator_test.dart` | Present |
| `models/ball.dart` | `models/ball_test.dart` | Present |
| `models/cascade_board.dart` | `models/cascade_board_test.dart` | Present |
| `models/drop_result.dart` | `models/drop_result_test.dart` | Present |
| `models/lever.dart` | `models/lever_test.dart` | Present |
| `view/cascade_page.dart` | -- | **Missing** |
| `view/widgets/ball_tray.dart` | `view/widgets/ball_tray_test.dart` | Present |
| `view/widgets/ball_widget.dart` | `view/widgets/ball_widget_test.dart` | Present |
| `view/widgets/bin_widget.dart` | `view/widgets/bin_widget_test.dart` | Present |
| `view/widgets/cascade_board_widget.dart` | -- | **Missing** |
| `view/widgets/cascade_results_overlay.dart` | -- | **Missing** |
| `view/widgets/instructions_dialog.dart` | `view/widgets/instructions_dialog_test.dart` | Present |
| `view/widgets/lever_widget.dart` | `view/widgets/lever_widget_test.dart` | Present |

**Missing tests**: 3 files lack corresponding test files:
1. `view/cascade_page.dart` -- the main page with BlocProvider setup and game flow
2. `view/widgets/cascade_board_widget.dart` -- the largest widget (739 lines) with complex animation logic
3. `view/widgets/cascade_results_overlay.dart` -- the results overlay with Nostr sharing

---

## Barrel File Compliance

### Convention: "use barrel files; never import across layer boundaries"

Several cross-module imports bypass available barrel files. While consistent with the Chromix game pattern, they technically violate the barrel file convention:

1. **`cascade_page.dart:10-14`** -- imports 5 nostr files directly (`nostr/sharing/cubit/result_sharing_cubit.dart`, `nostr/sharing/repository/nostr_publish_repository.dart`, `nostr/stats/cubit/community_stats_cubit.dart`, `nostr/stats/cubit/leaderboard_cubit.dart`, `nostr/stats/repository/community_stats_repository.dart`) instead of using `nostr/sharing/sharing.dart` and `nostr/stats/stats.dart` barrel files.

2. **`cascade_results_overlay.dart:4-5`** -- imports `core/daily_seed/date_key.dart` and `core/view/widgets/star_rating.dart` directly instead of `core/core.dart`.

3. **`cascade_results_overlay.dart:7-12`** -- imports 6 nostr files directly instead of using barrel files.

Note: Intra-module direct imports (e.g., `ball_widget.dart` imported by `bin_widget.dart`) are acceptable within the same layer to avoid circular barrel file imports.

Note: The `nostr/sharing/sharing.dart` barrel does not re-export its `view/` files, so some direct imports are necessary until the barrel is updated. This is a project-level issue.

---

## Additional Observations

### Suggestions

1. **CascadeBoardWidget complexity** (`view/widgets/cascade_board_widget.dart`, 739 lines): This is the largest file in the module. It handles grid rendering, drop slot interactions, lever rendering, bin rendering, ball animation (gravity easing, wall bounces, bin bounces, lever deflections), and landed ball positioning. Consider extracting the animation/physics logic (`_gravityEase`, `_solveQuadraticTime`, `_interpolatedPosition` -- approximately 200 lines) into a separate testable class or standalone functions in the `logic/` layer.

2. **Pre-drop snapshot not persisted** (`cubit/cascade_cubit.dart:37-39`): `_preDropBoard` and `_preDropSlots` are mutable instance fields for reset bookkeeping. If the app is killed during `failed` state, reset falls back to `state.board.resetLevers(state.initialLevers)` and `defaultSlotAssignments`. Including pre-drop configuration in the serialized session would provide exact reset behavior across app restarts.

3. **Duplicate `utcDateKey()` call** (`cascade_results_overlay.dart:79`): The overlay calls `utcDateKey()` independently for the leaderboard `dTag` rather than receiving the `dateKey` already computed in `CascadePage`. Around midnight UTC the two calls could return different dates. This is a pre-existing pattern from Chromix.

---

## Compliance with "Adding a New Game" Checklist

Per the project's CLAUDE.md:

| Step | Requirement | Status |
|---|---|---|
| 1 | Create `lib/games/cascade/` with models, logic, cubit, view, theme | Done |
| 2 | Implement `GameDefinition` in `cascade_game.dart` | Done |
| 3 | Register in `main.dart` GameRegistry | Done |
| 4 | Add `EventBuilder.buildCascadeResult()` for Nostr sharing | Done |
| 5 | Use shared overlay widgets (ResultSharingListener, ShareResultButton, etc.) | Done |
| 6 | Use `utcDateKey()` for date formatting | Done |
| 7 | Use `GameStorageRepository` for persistence (sessions, streaks, instructions seen) | Done |

---

## Summary of Findings

| # | Severity | Description | Location |
|---|----------|-------------|----------|
| 1 | Important | Missing test: `cascade_page_test.dart` (page-level integration) | `view/cascade_page.dart` |
| 2 | Important | Missing test: `cascade_board_widget_test.dart` (739-line animation widget) | `view/widgets/cascade_board_widget.dart` |
| 3 | Important | Missing test: `cascade_results_overlay_test.dart` (results + sharing) | `view/widgets/cascade_results_overlay.dart` |
| 4 | Suggestion | Extract animation/physics logic from CascadeBoardWidget to logic layer for testability | `cascade_board_widget.dart` |
| 5 | Suggestion | Persist pre-drop snapshot for exact reset across app restarts | `cascade_cubit.dart:37-39` |
| 6 | Suggestion | Pass `dateKey` to results overlay instead of calling `utcDateKey()` again | `cascade_results_overlay.dart:79` |

---

## Verdict

**Ready to merge** with a follow-up task to add the 3 missing widget/page tests.

Architecture is clean: zero layer separation violations, zero dependency direction issues, zero circular dependencies, zero Dart analysis concerns. The module follows all VGV conventions (Cubit/part-of pattern, Equatable state, nullable copyWith wrapper, barrel files, shared UI reuse, `kDebugMode` gating) and satisfies every item on the "Adding a New Game" checklist.
