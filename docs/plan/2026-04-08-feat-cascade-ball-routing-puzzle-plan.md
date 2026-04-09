---
title: "feat: add Cascade ball-routing puzzle game"
type: feat
date: 2026-04-08
---

## feat: add Cascade ball-routing puzzle game

## Overview

Add **Cascade**, the fourth daily puzzle game in Very Good Games. Players route three numbered/colored balls through a vertical board of toggle levers into matching target bins. The game combines spatial reasoning with sequential planning -- each ball flips the levers it passes through, changing the path for subsequent balls.

The core mechanic is one simple rule: a ball deflects in a lever's direction, then the lever flips. Emergent complexity arises from the cascading consequences across three sequential ball drops.

## Problem Statement / Motivation

The app currently has three games (Guess the Number, Signal, Chromix). Adding a fourth game with a distinct mechanic (physics-based routing with sequential state changes) broadens the daily puzzle offering and introduces the first game with a substantial animation phase, differentiating it from the tap/drag-based games.

The brainstorm identified "pachinko routing with configuration" as the winning interaction model for its unique combination of planning (configure levers + assign balls) and spectacle (watch the cascade play out).

## Proposed Solution

Implement Cascade as a self-contained game module at `lib/games/cascade/` following the established `GameDefinition` pattern. The game has two distinct phases:

1. **Configuration phase** -- player assigns balls to drop slots and flips lever directions
2. **Drop phase** -- animated ball cascade with lever interactions, leading to win or retry

### Key Design Decisions

#### State Machine

```
loading -> configuring -> dropping -> won
                ^            |
                |            v
                +------- failed
```

- **`loading`**: Puzzle generating in isolate (via `compute`)
- **`configuring`**: Player assigns balls and flips levers. Drop button enabled only when all 3 balls are assigned
- **`dropping`**: Animation in progress, all user input blocked
- **`won`**: All 3 balls in correct bins. Triggers streak, celebration, results overlay
- **`failed`**: At least one ball in wrong bin. Reset available

#### Reset Semantics

Reset restores the board to its **seed-generated defaults**: all lever directions return to initial positions, all ball assignments are cleared. The attempt counter is preserved. This matches the brainstorm's "undoes all changes" language and keeps the mental model simple -- each attempt starts from a clean slate.

#### Wall-Deflection Lever Flip Rule

**Levers always flip when a ball arrives, regardless of whether the deflection succeeds.** If a lever at column 0 points left, the ball stays in column 0 (blocked by edge) and continues falling, but the lever still flips to right. This maintains the "one rule, no exceptions" philosophy from the brainstorm and is simpler to reason about for both players and the puzzle generator.

#### Score Formula

Score is attempt-based, inverted to higher-is-better for consistency with other games:

```dart
int cascadeScore(int attempts) => max(100 - (attempts - 1) * 25, 10);

int cascadeStars(int attempts) {
  if (attempts == 1) return 3;
  if (attempts <= 3) return 2;
  return 1;
}
```

This gives: 1 attempt = 100 (3 stars), 2 = 75, 3 = 50 (2 stars), 4 = 25 (1 star), 5+ = 10.

#### Ball Assignment Interaction

- Balls start in a **tray row** above the 3 drop slots
- **Drag** a ball from the tray to a drop slot to assign
- **Drag** a ball from one slot to another to **swap**
- **Tap** an assigned ball to **unassign** (return to tray)
- Drop button is **disabled** until all 3 balls are assigned

#### Animation Timing

- **~200ms per row** for ball movement (7 rows = ~1.4s per ball)
- **0.5s pause** between balls (start-to-start, not end-to-start)
- Total animation: ~3-4 seconds for all 3 balls
- **Tap-to-skip**: Tapping during the drop animation instantly resolves all remaining balls and shows the final result. Available on all attempts.

#### Post-Drop Failure State

After all 3 balls land:
1. **1.5-second pause** showing balls in bins (correct bins glow green, wrong bins dim/neutral)
2. Levers visible in their post-drop (mutated) positions so the player can see what happened
3. Reset button appears
4. On Reset, board snaps back to seed defaults (no animation needed for reset)

### Board Dimensions

- **5 columns x 7 rows** (fixed for all puzzles)
- **3 drop slots** at the top (columns 1, 2, 3 -- leaving columns 0 and 4 as edges)
- **3 target bins** at the bottom (positions shuffled by daily seed)
- **6-8 toggle levers** at fixed positions (set by daily seed)

### Module Structure

```
lib/games/cascade/
  models/
    lever.dart            -- Lever (position, direction enum)
    ball.dart             -- Ball (id, color, assigned slot)
    cascade_board.dart    -- CascadeBoard (grid, levers, bins, ball assignments)
    drop_result.dart      -- DropResult (ball paths, final positions, success)
    models.dart           -- barrel file
  logic/
    ball_simulator.dart   -- Pure simulation: given board + assignments, compute ball paths
    puzzle_generator.dart -- Generate board from seed, verify unique solution
    score_calculator.dart -- cascadeScore(), cascadeStars()
    logic.dart            -- barrel file
  cubit/
    cascade_cubit.dart    -- State management (configure, drop, reset, win)
    cascade_state.dart    -- CascadeState (part of cubit)
    cubit.dart            -- barrel file
  view/
    cascade_page.dart     -- Top-level page (MultiBlocProvider)
    widgets/
      cascade_board_widget.dart  -- Board grid with levers, bins, drop slots
      ball_tray.dart             -- Draggable ball tray above drop slots
      lever_widget.dart          -- Single lever (tap to flip, animated rotation)
      ball_widget.dart           -- Animated ball during drop
      bin_widget.dart            -- Target bin with correct/wrong feedback
      cascade_results_overlay.dart -- Results overlay (star rating, share, stats)
      instructions_dialog.dart   -- First-time instructions
      widgets.dart               -- barrel file
    view.dart            -- barrel file
  theme/
    cascade_colors.dart  -- Color constants (ball colors, lever, bin, board)
    theme.dart           -- barrel file
  cascade_game.dart      -- GameDefinition implementation
```

### Models

#### `Lever`

```dart
// lib/games/cascade/models/lever.dart
enum LeverDirection { left, right }

class Lever extends Equatable {
  const Lever({required this.row, required this.col, required this.direction});
  final int row;
  final int col;
  final LeverDirection direction;
  Lever flip() => Lever(row: row, col: col, direction: direction.opposite);
}
```

#### `Ball`

```dart
// lib/games/cascade/models/ball.dart
enum BallId { ball1, ball2, ball3 }

class Ball extends Equatable {
  const Ball({required this.id});
  final BallId id;
  // ball1 = red, ball2 = blue, ball3 = yellow (derived from id)
}
```

#### `CascadeBoard`

```dart
// lib/games/cascade/models/cascade_board.dart
class CascadeBoard extends Equatable {
  const CascadeBoard({
    required this.levers,
    required this.binOrder,    // e.g., [2, 0, 1] meaning bin positions
  });
  static const columns = 5;
  static const rows = 7;
  final List<Lever> levers;
  final List<int> binOrder;    // which bin is at each of the 3 bin positions

  CascadeBoard flipLever(int index) => ...;
  CascadeBoard resetLevers(List<Lever> initialLevers) => ...;
  Lever? leverAt(int row, int col) => ...;
}
```

#### `DropResult`

```dart
// lib/games/cascade/models/drop_result.dart
class BallPath {
  const BallPath({required this.ballId, required this.positions, required this.finalBin});
  final BallId ballId;
  final List<({int row, int col})> positions;  // each step in the path
  final int finalBin;  // which bin the ball landed in
}

class DropResult extends Equatable {
  const DropResult({required this.paths, required this.isWin});
  final List<BallPath> paths;  // one per ball, in drop order
  final bool isWin;
}
```

### Logic

#### `BallSimulator`

Pure function: given a board configuration and ball-to-slot assignments, simulate all 3 balls and return their paths plus final lever states. This is the core engine used by both the gameplay cubit and the puzzle generator.

```dart
// lib/games/cascade/logic/ball_simulator.dart
class BallSimulator {
  /// Simulates all 3 balls dropping through the board.
  /// Returns the paths and whether all balls reached correct bins.
  static DropResult simulate({
    required CascadeBoard board,
    required List<BallId> slotAssignments, // ball in slot 0, 1, 2
  });

  /// Simulates a single ball, mutating lever states.
  /// Returns the ball's path and the updated board.
  static (BallPath, CascadeBoard) _simulateBall({
    required CascadeBoard board,
    required BallId ballId,
    required int startCol,  // the drop slot column
  });
}
```

Ball movement per tick:
1. Ball is at `(row, col)`
2. Check if `(row, col)` has a lever:
   - **Yes**: Compute target column = `col + (lever.direction == left ? -1 : 1)`. If target column is out of bounds (< 0 or >= 5), ball stays at `col`. Lever flips. Ball moves to `(row + 1, targetCol)`.
   - **No**: Ball moves to `(row + 1, col)`.
3. If `row + 1 >= rows`, ball has exited the board -- determine which bin it lands in.

#### `PuzzleGenerator`

Follow the established generate-then-verify pattern from Chromix/Signal:

```dart
// lib/games/cascade/logic/puzzle_generator.dart
typedef CascadeGenerateResult = ({
  CascadeBoard board,
  List<Lever> initialLevers,
  List<int> binOrder,
  int solutionSlotAssignment,    // encoded as 3-digit base-3
  List<LeverDirection> solutionLeverStates,
});

class PuzzleGenerator {
  static CascadeGenerateResult generate(int seed) {
    // 1. Use Random(seed) to place 6-8 levers on the 5x7 grid
    // 2. Randomly assign initial lever directions
    // 3. Randomly shuffle bin order
    // 4. Enumerate all configurations (6 ball permutations x 2^N lever states)
    //    - For 6 levers: 6 x 64 = 384 configs (cheap to enumerate)
    //    - For 8 levers: 6 x 256 = 1536 configs (still cheap)
    // 5. Simulate each configuration, count wins
    // 6. Accept if exactly 1 winning configuration
    // 7. Retry with seed+1 if not unique
    // Fallback after 100 retries: accept puzzle with fewest solutions (2+)
  }
}
```

**Key insight**: The search space is small enough (max ~1536 configs) that brute-force enumeration is feasible and fast. No backtracking solver needed -- just simulate every possible configuration and count winners.

### Cubit / State

#### `CascadeStatus`

```dart
enum CascadeStatus { loading, configuring, dropping, won, failed }
```

#### `CascadeState`

```dart
// lib/games/cascade/cubit/cascade_state.dart
class CascadeState extends Equatable {
  const CascadeState({
    required this.board,
    required this.initialLevers,
    required this.status,
    this.slotAssignments = const [null, null, null],
    this.attempts = 0,
    this.dropResult,
    this.score,
  });

  final CascadeBoard board;
  final List<Lever> initialLevers;  // for reset
  final CascadeStatus status;
  final List<BallId?> slotAssignments;  // 3 slots, each null or a ball
  final int attempts;
  final DropResult? dropResult;  // populated during/after dropping
  final int? score;  // populated on win

  bool get allBallsAssigned => slotAssignments.every((s) => s != null);
  int get stars => score != null ? cascadeStars(attempts) : 0;
}
```

#### `CascadeCubit` Methods

```dart
class CascadeCubit extends Cubit<CascadeState> {
  // Construction: generate puzzle via compute isolate, restore session

  void assignBall(BallId ball, int slotIndex);  // assign ball to slot
  void unassignBall(int slotIndex);              // remove ball from slot
  void swapSlots(int fromSlot, int toSlot);      // swap two assignments
  void flipLever(int leverIndex);                // toggle lever direction
  void drop();                                    // start the cascade (configuring -> dropping)
  void completeDrop();                            // called when animation finishes (dropping -> won/failed)
  void skipAnimation();                           // instant-resolve remaining balls
  void reset();                                   // failed -> configuring (restore initial levers, clear assignments)
}
```

**Session persistence** (matching Chromix pattern):
- Persist after every user action in `configuring` state: `slotAssignments`, `leverStates`, `attempts`
- Clear session on win
- Storage key: `cascade_state_$dateKey`

**App backgrounding during animation**: Persist the pre-drop configuration with the incremented attempt counter. On restore, if status was `dropping`, treat as `failed` and show post-drop result instantly (simulate without animation).

### View / Widgets

#### `CascadePage`

Follow Chromix pattern: `MultiBlocProvider` with `CascadeCubit`, `ResultSharingCubit`, `CommunityStatsCubit`, `LeaderboardCubit`, `ProfileCubit`.

```dart
// lib/games/cascade/view/cascade_page.dart
class CascadePage extends StatelessWidget {
  const CascadePage({required this.dailySeed, super.key});
  final int dailySeed;
  // MultiBlocProvider setup matching chromix_page.dart pattern
}
```

#### Board Widget Layout (top to bottom)

```
+---+---+---+---+---+
| Ball Tray (3 balls, draggable)    |
+---+---+---+---+---+
|   | S1| S2| S3|   |  <- Drop slots (columns 1-3)
+---+---+---+---+---+
|   |   | L>|   |   |  <- Row with lever
+---+---+---+---+---+
|   | <L|   |   |   |  <- Row with lever
+---+---+---+---+---+
|   |   |   | L>|   |  <- Row with lever
+---+---+---+---+---+
|   | <L|   | L>|   |  <- Row with levers
+---+---+---+---+---+
|   |   |   |   |   |  <- Empty row
+---+---+---+---+---+
|   |   |   |   |   |  <- Empty row
+---+---+---+---+---+
|   |B3 |B1 |B2 |   |  <- Target bins (shuffled)
+---+---+---+---+---+
```

- Ball tray: 3 draggable balls above the board
- Drop slots: columns 1, 2, 3 at the top of the board
- Levers: positioned within the grid, tappable during `configuring`
- Bins: 3 bins at the bottom showing target ball numbers

#### Animation

Use Flutter's `AnimationController` + `Tween` for smooth ball movement:
- Ball position interpolates between grid positions
- Diagonal movement through lever cells (deflection)
- Lever rotation animation on flip (both tap and ball-triggered)
- Bin glow animation on ball arrival

The `CascadeCubit` computes the full `DropResult` (all paths) synchronously via `BallSimulator`. The animation layer in the view reads the paths and animates them. When animation completes (or is skipped), the view calls `cubit.completeDrop()`.

### Theme

```dart
// lib/games/cascade/theme/cascade_colors.dart
abstract final class CascadeColors {
  static const ball1 = Color(0xFFE53935);     // Red
  static const ball2 = Color(0xFF1E88E5);     // Blue
  static const ball3 = Color(0xFFFDD835);     // Yellow
  static const lever = Color(0xFF616161);      // Gray
  static const leverActive = Color(0xFF424242); // Dark gray (during flip)
  static const binCorrect = Color(0xFF43A047);  // Green glow
  static const binNeutral = Color(0xFF9E9E9E);  // Gray
  static const board = Color(0xFFF5F5F5);       // Light background
  static const gridLine = Color(0xFFE0E0E0);    // Subtle grid lines
}
```

### Nostr Integration

Add `EventBuilder.buildCascadeResult()` following the existing pattern:

```dart
static NostrEvent buildCascadeResult({
  required String pubKeyHex,
  required int score,
  required int stars,
  required int attempts,
  required String date,
}) {
  // d tag: 'cascade:$date'
  // t tags: 'vgg', 'cascade'
  // l tags: score, stars, attempts
  // Content: 'Very Good Games - Cascade\n$stars Stars\n$attempts attempts\n$date'
}
```

### Game Registration

```dart
// lib/games/cascade/cascade_game.dart
class CascadeGame extends GameDefinition {
  CascadeGame({required super.storageRepository});

  @override String get id => 'cascade';
  @override String get name => 'Cascade';
  @override String get description => 'Route balls through levers in a daily puzzle';
  @override IconData get icon => Icons.arrow_downward;
  @override String get routePath => '/games/cascade';
  @override List<RouteBase> get routes => [
    GoRoute(
      path: routePath,
      builder: (context, state) => CascadePage(dailySeed: DailySeed.today()),
    ),
  ];
}
```

Register in `main.dart`:
```dart
CascadeGame(storageRepository: storageRepository),
```

## Technical Considerations

### Architecture

- Follows established `GameDefinition` module pattern exactly
- Pure logic layer (`BallSimulator`, `PuzzleGenerator`) is fully testable without Flutter
- Animation is a view-layer concern only; cubit deals with discrete states
- `BallSimulator.simulate()` is reused by both the cubit (gameplay) and generator (validation)

### Performance

- Puzzle generation runs in `compute` isolate (matching Chromix/Signal)
- Brute-force enumeration of ~384-1536 configurations is O(milliseconds)
- Animation uses standard Flutter `AnimationController` -- no custom render objects needed

### Risk: Puzzle Generation Reliability

The generator must produce unique-solution puzzles reliably. Mitigation:
- The search space is small enough for brute-force enumeration
- If no unique-solution board is found after 100 seed offsets, accept the board with the fewest solutions (fallback, matching Chromix pattern)
- Lever count (6-8) is tunable to control difficulty and uniqueness probability
- **Spike recommendation**: Prototype the generator first and measure uniqueness rate across 1000 seeds

### Risk: Animation State Management

This is the first game with a non-trivial animation phase. The key design decision is that the **cubit computes the full result synchronously** and the **view handles animation asynchronously**. This keeps state management simple:
- `drop()` computes `DropResult`, emits `dropping` status with result
- View reads `DropResult.paths` and animates them
- View calls `completeDrop()` when done (or on skip)
- If app backgrounds during animation, session persists as `configuring` with incremented attempts

## Acceptance Criteria

### Models
- [ ] `Lever` model with position, direction, flip (`lib/games/cascade/models/lever.dart`)
- [ ] `Ball` / `BallId` enum (`lib/games/cascade/models/ball.dart`)
- [ ] `CascadeBoard` with lever list, bin order, helpers (`lib/games/cascade/models/cascade_board.dart`)
- [ ] `DropResult` / `BallPath` for simulation output (`lib/games/cascade/models/drop_result.dart`)
- [ ] All models use Equatable, sealed classes where appropriate
- [ ] JSON serialization for session persistence

### Logic
- [ ] `BallSimulator.simulate()` correctly routes balls through levers (`lib/games/cascade/logic/ball_simulator.dart`)
- [ ] Lever flips on ball contact (even when deflection is blocked by wall)
- [ ] Sequential ball drops (Ball 1 modifies levers before Ball 2 drops)
- [ ] `PuzzleGenerator.generate()` produces deterministic puzzles from seed (`lib/games/cascade/logic/puzzle_generator.dart`)
- [ ] Generator verifies unique solution via brute-force enumeration
- [ ] Fallback after max retries (matching Chromix pattern)
- [ ] `cascadeScore()` and `cascadeStars()` (`lib/games/cascade/logic/score_calculator.dart`)

### Cubit
- [ ] `CascadeCubit` manages full state machine: loading -> configuring -> dropping -> won/failed (`lib/games/cascade/cubit/cascade_cubit.dart`)
- [ ] Ball assignment: assign, unassign, swap
- [ ] Lever flip during configuring phase
- [ ] Drop triggers simulation, emits result
- [ ] Reset restores seed defaults, preserves attempt count
- [ ] Session persistence via `GameStorageRepository` (save on every action, restore on init)
- [ ] Session cleared on win
- [ ] Streak tracking on win

### View
- [ ] `CascadePage` with MultiBlocProvider setup (`lib/games/cascade/view/cascade_page.dart`)
- [ ] Board widget showing 5x7 grid with levers and bins (`lib/games/cascade/view/widgets/cascade_board_widget.dart`)
- [ ] Ball tray with drag-to-assign interaction (`lib/games/cascade/view/widgets/ball_tray.dart`)
- [ ] Lever widget with tap-to-flip and animated rotation (`lib/games/cascade/view/widgets/lever_widget.dart`)
- [ ] Animated ball movement during drop phase (`lib/games/cascade/view/widgets/ball_widget.dart`)
- [ ] Target bin widget with correct/wrong feedback (`lib/games/cascade/view/widgets/bin_widget.dart`)
- [ ] Drop button (disabled until all balls assigned, hidden during drop/won/failed)
- [ ] Reset button (visible only in failed state)
- [ ] Tap-to-skip during animation
- [ ] Results overlay with star rating, attempts, share, community stats (`lib/games/cascade/view/widgets/cascade_results_overlay.dart`)
- [ ] Instructions dialog for first-time players (`lib/games/cascade/view/widgets/instructions_dialog.dart`)
- [ ] Win celebration via `WinCelebration` widget
- [ ] Debug shuffle button (gated by `kDebugMode`)
- [ ] Input blocked during `dropping` state
- [ ] 1.5s pause after failed drop before Reset appears
- [ ] Already-won restore: show results overlay immediately

### Integration
- [ ] `CascadeGame` implements `GameDefinition` (`lib/games/cascade/cascade_game.dart`)
- [ ] Registered in `GameRegistry` in `main.dart`
- [ ] `EventBuilder.buildCascadeResult()` for Nostr sharing
- [ ] Community stats fetch with `cascade:$dateKey`
- [ ] Leaderboard integration
- [ ] `utcDateKey()` for date formatting
- [ ] `GameStorageRepository` for hasSeenInstructions / markInstructionsSeen

### Testing
- [ ] Unit tests for `BallSimulator` (various board configs, edge deflection, lever flipping)
- [ ] Unit tests for `PuzzleGenerator` (determinism, unique solution verification)
- [ ] Unit tests for score calculator
- [ ] `bloc_test` tests for `CascadeCubit` (all state transitions, persistence, restore)
- [ ] Widget tests for key UI components (board, ball tray, lever, results overlay)
- [ ] Model serialization round-trip tests

## Success Metrics

- Puzzles are solvable in 60-90 seconds by an experienced player
- Generator produces unique-solution puzzles for >95% of seeds without fallback
- Ball cascade animation runs at 60fps on mid-range devices
- All acceptance criteria pass with full test coverage

## Dependencies & Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Puzzle generation rarely finds unique solutions | Medium | High | Tune lever count (6-8), test across 1000+ seeds, fallback to fewest-solutions |
| Animation performance on low-end devices | Low | Medium | Use standard Flutter animation APIs, avoid custom render objects |
| Ball assignment drag UX feels awkward on phone | Medium | Medium | Prototype early, ensure drop slots are large enough (~60px tap targets) |
| Animation state + app lifecycle edge cases | Medium | Low | Cubit computes synchronously; animation is view-only; backgrounding persists pre-drop state |

## References & Research

### Existing Patterns (follow exactly)
- Game definition: [chromix_game.dart](lib/games/chromix/chromix_game.dart)
- Cubit + State: [chromix_cubit.dart](lib/games/chromix/cubit/chromix_cubit.dart), [chromix_state.dart](lib/games/chromix/cubit/chromix_state.dart)
- Puzzle generator: [puzzle_generator.dart](lib/games/chromix/logic/puzzle_generator.dart) (generate-then-verify pattern)
- Grid model: [chromix_grid.dart](lib/games/chromix/models/chromix_grid.dart) (immutable grid with Equatable)
- Page setup: [chromix_page.dart](lib/games/chromix/view/chromix_page.dart) (MultiBlocProvider pattern)
- Score calculator: [score_calculator.dart](lib/games/chromix/logic/score_calculator.dart) (top-level functions)
- Theme colors: [chromix_colors.dart](lib/games/chromix/theme/chromix_colors.dart) (abstract final class)
- Results overlay: [chromix_results_overlay.dart](lib/games/chromix/view/widgets/chromix_results_overlay.dart) (EventBuilder usage)
- Nostr sharing: `EventBuilder.buildChromixResult()` pattern
- Brainstorm: [2026-04-08-cascade-ball-routing-puzzle-brainstorm-doc.md](docs/brainstorm/2026-04-08-cascade-ball-routing-puzzle-brainstorm-doc.md)
