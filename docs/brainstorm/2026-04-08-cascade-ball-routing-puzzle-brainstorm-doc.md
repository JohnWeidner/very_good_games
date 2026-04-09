---
date: 2026-04-08
topic: cascade-ball-routing-puzzle
---

# Cascade: Daily Ball-Routing Puzzle

## What We're Building

A daily puzzle game where players route numbered balls through a vertical board of toggle levers into target bins at the bottom. Three colored balls (1-red, 2-blue, 3-yellow) drop one at a time from three openings at the top. The player assigns each ball to a drop slot and configures the levers before pressing "Drop." Balls fall one row at a time, hitting levers that deflect them left or right — and each ball flips the levers it passes through, changing the path for the next ball.

Think pachinko meets logic puzzle — the visual satisfaction of watching balls cascade through a machine, combined with the spatial reasoning of figuring out the right configuration.

## Why This Approach

We evaluated four interaction models:

1. **Path/flow building** — Connect-the-dots style routing. Clean but static.
2. **Tile placement** — Tetris-like fitting. Good but overlaps with Chromix's spatial feel.
3. **Pachinko routing with prediction** — Study the board, predict the outcome. Cerebral but passive — no satisfying "watch it play out" moment.
4. **Pachinko routing with configuration** — Set up the board, then watch your plan execute. Double payoff: puzzle-solving + visual cascade.

Option 4 was chosen for its unique combination of planning and spectacle. The sequential ball interaction (Ball 1 changes the board for Ball 2) adds emergent depth from simple rules.

## Key Decisions

### Board Layout
- **3 drop slots** at the top — player assigns balls 1, 2, 3 to slots
- **~6-8 toggle levers** arranged on the board in fixed positions (set by daily seed)
- **3 target bins** at the bottom — labeled 1, 2, 3 in shuffled positions (set by daily seed)
- **Board size**: 5 columns wide, 7 rows tall — enough depth for interesting paths without being overwhelming on mobile

### Core Mechanic: Toggle Levers

**One rule, no variants:** When a ball hits a lever, it deflects in the lever's current direction, then the lever flips to the opposite direction.

- Each lever points left (←) or right (→)
- Ball arrives at a lever → deflects one column in the lever's direction + falls one row
- The lever then flips (← becomes →, or vice versa)
- Ball 1 going left at a lever causes Ball 2 to go right at the same lever

No sticky levers, no one-way deflectors, no ball-specific levers. The beauty of this game is emergent complexity from one simple rule. Players learn one thing and then reason about cascading consequences.

### Ball Movement Rules

**Grid-based logic, smooth animation:**

The ball falls one row per tick. At each row:
1. **Empty cell** → ball falls straight down one row
2. **Lever cell** → ball deflects one column in the lever's direction, moves down one row, lever flips
3. **Wall/edge** → if a lever deflects into a wall or grid edge, the ball stays in the same column and keeps falling (deflection blocked)

**No ball collisions.** Balls drop sequentially (1 second apart), so they never occupy the board simultaneously. Each ball's journey completes before the next one drops.

Animation is smooth and continuous (ball slides diagonally through lever cells) even though the underlying logic is grid-based. Players can trace paths cell-by-cell on the visible grid.

### Player Actions

**Two decisions only:**

1. **Assign balls to drop slots** — drag balls 1 (red), 2 (blue), 3 (yellow) to the three openings at the top. All three must be assigned before dropping.
2. **Flip levers** — tap a lever to toggle its starting direction (← ↔ →) before dropping.

Then press **"Drop"** to start the cascade.

The board layout (where levers are positioned) is fixed by the daily seed. The player does NOT place or remove levers — only flips their initial direction. This constrains the puzzle to two interacting dimensions (drop assignment + lever configuration) that players can reason about separately then combine.

**Reset** undoes all changes (lever flips + ball assignments) to try a different approach.

### Win Condition

Three target bins at the bottom are labeled 1, 2, 3 (in shuffled positions set by the daily seed). Ball 1 (red) must land in bin 1, Ball 2 (blue) must land in bin 2, Ball 3 (yellow) must land in bin 3.

Color-coding reinforces the goal: bins glow the matching ball color. When a ball lands in the correct bin, it lights up with a satisfying effect. Wrong bin = dim/neutral feedback.

The puzzle is solved when all three balls land in their correct bins.

### Scoring
- **Star rating** based on number of attempts (drop + reset cycles)
- 3 stars: solved on the first drop
- 2 stars: solved in 2-3 attempts
- 1 star: solved in 4+ attempts
- Each "Drop" counts as an attempt regardless of outcome

### Difficulty Sweet Spot

Target: solvable in 60-90 seconds for an experienced player.

- Ball assignment has 6 permutations (3! = 6)
- With 6 levers, there are 64 lever states
- But most states are pruneable by tracing one ball at a time
- The sequential interaction (Ball 1 flips levers for Ball 2) is the key complexity driver
- Players can trace Ball 1's path mentally, then figure out Ball 2's path through the modified board, then Ball 3
- This "sequential simulation" approach makes the puzzle tractable but not trivial

### Visual Design
- **Style**: Clean, tactile, satisfying — elegant pinball machine aesthetic
- **Ball colors**: 1 = red, 2 = blue, 3 = yellow (bold, distinct, colorblind-friendly with number labels)
- **Ball drop animation**: smooth gravity-driven fall, balls visibly deflect off levers
- **Lever animation**: lever arm rotates when flipped (by player tap or ball hit)
- **Cascade timing**: 1 second between ball drops — enough to watch each ball's full journey
- **Target feedback**: bins light up green for correct ball, neutral for wrong ball
- **Board aesthetic**: clean geometry, subtle grid lines, metallic lever feel

### Daily Seed
- Same deterministic approach as other games — all players solve the same puzzle each day
- Board layout (lever positions), initial lever states, target bin arrangement, and correct ball assignment all derived from daily seed
- Puzzle generator must verify exactly one valid configuration exists (unique solution)

### Integration
- Follows existing patterns: `GameDefinition`, `GameRegistry`, daily seed, streak tracking
- Nostr sharing: share result with star rating and attempt count
- Community stats and leaderboard
- Instructions dialog for first-time players
- Win celebration (shared `WinCelebration` widget)

## Open Questions

- **Breakable platforms (v2)**: Some puzzles could add fragile platforms that break after Ball 1 passes, opening new paths for Ball 2/3. This adds variety without changing the core mechanic. Save for a future version if the base game needs more depth.
- **Board generation**: Need to design the puzzle generator carefully — random lever placement may not always produce puzzles with unique solutions. Likely needs: generate board → simulate all configurations → verify exactly one works → reject and retry if not.
- **Name**: "Cascade" is the working title. Other options: "Drop", "Deflect", "Tumble", "Lever Logic".

## Success Criteria

- Puzzles are solvable in 60-90 seconds by an experienced player
- The ball cascade animation is satisfying to watch
- The toggle mechanic is immediately intuitive (tap to flip)
- Sequential ball interaction creates genuine "aha" moments when players realize how Ball 1's path affects Ball 2
- Works well on phone — levers are easy to tap, balls are easy to follow
- New puzzle every day via deterministic seed
