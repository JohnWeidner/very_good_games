# Architecture Review: feat/chromix-contiguity-drag

**Branch**: `feat/chromix-contiguity-drag` vs `main`
**Date**: 2026-04-07
**Reviewer**: Architecture Review Agent

---

## Architecture Review

### Layer Separation

- Violations found: 0
- Clean files: all checked files clean

**Analysis**: All changed files respect the project's layer boundaries:
- `lib/games/chromix/logic/` files import only from `models/` -- no Flutter, no cubit, no view imports.
- `lib/games/chromix/cubit/` imports from `logic/` and `models/` only (plus `core/` for storage). Does not import from `view/`.
- `lib/games/chromix/view/` files import from `cubit/`, `models/`, and `theme/` -- all permitted downward dependencies.
- `lib/core/view/widgets/win_celebration.dart` imports only `package:confetti` and `package:flutter` -- no game-specific dependencies.

### State Management Assessment

**ChromixCubit**: Correct -- with important observations

- Follows VGV Cubit + `part of` state pattern (`chromix_cubit.dart` + `chromix_state.dart`). **Correct**.
- State is immutable with Equatable, `copyWith` uses `Type? Function()?` wrapper for nullable fields (`dragOrigin`, `dragColor`, `score`). **Correct per project conventions**.
- Business logic (drag handling, mixing, overpower timer, undo, win detection, contiguity checking) is entirely in the cubit, not in views. **Correct**.
- Data access goes through `GameStorageRepository` injected via constructor. **Correct**.
- Naming is descriptive and domain-specific. **Correct**.

**Issues found**:

1. **[Important] Duplicated contiguity BFS logic -- 3 copies exist in the cubit**
   - `chromix_cubit.dart:352-386` -- `_isColorContiguous()` (instance method, used during gameplay)
   - `chromix_cubit.dart:467-512` -- `_computeContiguityViolation()` (static method, used during deserialization)
   - `contiguity_checker.dart:7-44` -- `allGroupsContiguous()` (standalone function in logic layer)

   All three implement the same BFS flood-fill algorithm for checking orthogonal contiguity of same-color cells. The cubit should delegate to `contiguity_checker.dart` instead of reimplementing the algorithm internally. The cubit already imports `logic/logic.dart` and calls `allGroupsContiguous` at line 392 for win checking, but then uses its own private copies for the violation feedback path.

   - `lib/games/chromix/cubit/chromix_cubit.dart:352` -- cubit reimplements BFS from `contiguity_checker.dart`
   - `lib/games/chromix/cubit/chromix_cubit.dart:467` -- cubit reimplements BFS again as static method

2. **[Suggestion] `_recomputeContiguity()` could delegate to logic layer**
   The method at `chromix_cubit.dart:329-349` that checks per-color contiguity when counts match targets is a reusable piece of game logic. It could live in `logic/contiguity_checker.dart` as a pure function (taking grid + target map, returning bool), keeping the cubit thinner and the logic testable in isolation.

**WinCelebration (core widget)**: Correct pattern

- Pure presentation widget with no business logic dependencies. **Correct**.
- Uses `findAncestorStateOfType` pattern for imperative control (`trigger`/`reset`). This is an acceptable Flutter pattern for animation orchestration, though an alternative would be a dedicated controller object.

### Dependency Direction

- Direction violations: 0
- Clean dependencies: all packages and modules

**Analysis**:
- `logic/` depends on `models/` only. No reverse.
- `cubit/` depends on `logic/` and `models/`. No reverse.
- `view/` depends on `cubit/`, `models/`, `theme/`. No reverse.
- `core/view/widgets/` depends on Flutter + `confetti` package only. No game-specific imports.
- No circular dependencies detected.

### Package Structure

**lib/core/view/widgets/win_celebration.dart** (NEW):

- [x] Correct location in shared `core/view/widgets/`
- [x] Single clear responsibility (confetti celebration sequence)
- [x] No game-specific dependencies
- [ ] **[Important] Not exported via barrel file** -- `lib/core/core.dart` does not export `view/widgets/`. All three game pages (`chromix_page.dart:7`, `game_page.dart:9`, `signal_page.dart:7`) import the file directly as `package:very_good_games/core/view/widgets/win_celebration.dart` instead of through `package:very_good_games/core/core.dart`. Per project conventions ("Imports: use barrel files"), a `widgets.dart` barrel should be created in `lib/core/view/widgets/` and re-exported through `core.dart`.

**lib/games/chromix/logic/contiguity_checker.dart** (NEW):

- [x] Correct location in `logic/` layer
- [x] Pure Dart, no Flutter dependencies
- [x] Single responsibility (contiguity checking)
- [x] Exported in `logic/logic.dart` barrel file

**lib/games/chromix/view/widgets/widgets.dart** (barrel):

- [x] Exports are alphabetically ordered
- [x] Deleted `color_palette.dart` is no longer exported
- [x] All widget files are accounted for

**Duplicate `_colorFor` helper**:

- **[Suggestion]** `chromix_cell_widget.dart:98` and `color_bar.dart:97` both define identical `static Color _colorFor(ChromixColor color)` switch expressions mapping `ChromixColor` to `Color`. This could be a single utility in `theme/` (e.g., an extension on `ChromixColor` or a static method on `ChromixColors`), reducing duplication and ensuring color mappings stay in sync.

### Cross-Game Consistency

The three game pages (`chromix_page.dart`, `signal_page.dart`, `game_page.dart`) all use the same `WinCelebration` widget and follow the same MultiBlocProvider pattern with identical Nostr-related cubit wiring. This is good consistency, though the amount of identical boilerplate across game pages (ResultSharingCubit, CommunityStatsCubit, LeaderboardCubit, ProfileCubit creation) is a future candidate for extraction into a shared `GamePageShell` widget.

### Summary of Findings

| # | Severity | Description | Location |
|---|----------|-------------|----------|
| 1 | Important | Contiguity BFS logic duplicated 3 times (cubit has 2 private copies of what `contiguity_checker.dart` already provides) | `chromix_cubit.dart:352-386`, `chromix_cubit.dart:467-512` |
| 2 | Important | `win_celebration.dart` not exported via barrel files; imported directly bypassing `core.dart` | `chromix_page.dart:7`, `game_page.dart:9`, `signal_page.dart:7` |
| 3 | Suggestion | `_colorFor` helper duplicated in `chromix_cell_widget.dart` and `color_bar.dart` -- extract to `theme/` | `chromix_cell_widget.dart:98`, `color_bar.dart:97` |
| 4 | Suggestion | Per-color contiguity violation check in cubit could be extracted to `logic/contiguity_checker.dart` as a pure function | `chromix_cubit.dart:329-349` |
| 5 | Suggestion | MultiBlocProvider boilerplate (5 Nostr cubits) is identical across all 3 game pages -- future extraction candidate | `chromix_page.dart:29-69`, `signal_page.dart:29-64`, `game_page.dart:39-82` |

### Verdict

**Ready to merge with minor fixes.** Fix 2 important issues before merging:
1. Eliminate the duplicated BFS implementations in the cubit by delegating to `contiguity_checker.dart`.
2. Add barrel file exports for `win_celebration.dart` and update imports across all game pages.

No layer separation violations, no dependency direction violations, and state management follows VGV conventions correctly. The suggestions are improvements that can be addressed in a follow-up.
