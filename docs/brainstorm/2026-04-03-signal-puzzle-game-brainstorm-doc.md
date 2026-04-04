---
date: 2026-04-03
topic: signal-puzzle-game
---

# Signal: Daily Grid Logic Puzzle

## What We're Building

A daily logic puzzle game where players place walls on a grid to control how far numbered "towers" broadcast their signals. Each tower shows a number indicating exactly how many cells its signal should reach in the four cardinal directions (up, down, left, right). Signals travel in straight lines until they hit a wall or the grid edge. The player wins when every tower's signal count matches its number.

Think Minesweeper meets Akari (Light Up) — pure spatial reasoning with no language barrier. One puzzle per day, seeded deterministically so all players solve the same board.

## Why This Approach

Three concepts were considered:

1. **Chain Link** (word ladder) — Strong depth but English-only, limiting audience. Requires a large dictionary asset.
2. **Signal** (grid logic) — Visual/spatial, language-independent, elegant deduction loop. Fresh concept that doesn't clone an existing well-known game directly.
3. **Flip** (card sorting under uncertainty) — Fast but felt too luck-dependent on early reveals, weaker "aha" moments.

Signal was chosen for its balance of accessibility, originality, and replayability. The visual nature makes it immediately understandable, while the logic depth keeps players coming back.

## Key Decisions

- **Grid size**: Daily seed picks either 5x5 or 6x6 — keeps players on their toes without grids getting too large for mobile
- **Interaction**: Drag to paint walls across cells for speed; tap to toggle individual walls for precision
- **Feedback**: Live conflict highlighting — towers flash red when their constraint is violated and show current signal count (e.g., "3/4"). Accessible and less frustrating than check-on-submit
- **Scoring**: Moves only (total wall placements including undos). No time pressure. Rewards decisive, logical play over speed
- **Daily seed**: Same deterministic seeding approach as Guess the Number — all players get the same board each day
- **Nostr integration**: Share results via kind 30042 events, same pattern as existing game. Community stats on results overlay

## Open Questions

- **Puzzle generation algorithm**: How to generate boards that are guaranteed solvable with exactly one solution? Needs a generator that places towers, solves, then verifies uniqueness. May need to research constraint-satisfaction approaches.
- **Difficulty tuning**: What makes a 5x5 "easy" vs "hard"? Number of towers, their placement density, how many walls are needed? Needs playtesting to find the sweet spot for under-3-minute solves.
- **Drag interaction on small grids**: Does drag-to-paint feel good on a 5x5 grid on phone screens, or does tap-to-toggle end up being the primary input? May need to support both and see what players prefer.
- **Tutorial/onboarding**: How to teach the mechanic to new players? An interactive mini-puzzle (3x3) on first launch could work.
- **Visual design**: How to make signal "broadcasts" visible? Animated rays from towers? Colored cell highlights? Needs design exploration.
