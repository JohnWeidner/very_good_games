---
date: 2026-04-07
topic: chromix-game
---

# Chromix — Color Mixing Puzzle Game

## What We're Building

A daily color-mixing grid puzzle where players place primary colors (Red, Yellow, Blue) on a 4x4 board to match a target color ratio. The board starts with pre-filled cells (primaries, secondaries, or black blockers). Pre-filled secondaries and black cells are locked — they can't be changed. Pre-filled primaries can be layered on. Players place primaries onto empty cells or layer a primary onto another primary to create a secondary color (Orange, Green, Purple). Secondary colors can only be created through mixing — they cannot be placed directly. The goal is to make the board's final color distribution match a target color bar.

Scoring is based on total moves plus undos — fewer is better. Each day's puzzle is generated algorithmically from the daily seed, with a solver verifying the puzzle has a unique solution.

## Why This Approach

Three puzzle generation strategies were considered:

1. **Pre-authored puzzle bank** — Hand-curated puzzles stored as JSON. Guarantees quality but requires ongoing curation and has finite supply.
2. **Algorithmic generation with solver verification** (chosen) — Generate from the daily seed, verify uniqueness with a backtracking solver. Infinite puzzles, consistent with how Signal and Guess the Number work. If some puzzles aren't fun, the generator can be tuned to filter them out.
3. **Hybrid** — Algorithmic with curated fallbacks. Most robust but most complex to build.

Algorithmic generation was chosen because it aligns with the existing seed-based daily puzzle pattern, avoids maintaining a data file, and can be iteratively improved by tuning generator constraints.

## Key Decisions

- **Color model: RYB (subtractive/paint mixing)** — More intuitive than RGB for most people. Red+Yellow=Orange, Red+Blue=Purple, Yellow+Blue=Green.
- **Players place primaries only** — Red, Yellow, Blue are the only colors a player can place. Secondaries (Orange, Green, Purple) are created exclusively through layering. This makes mixing the core mechanic, not an optional shortcut.
- **Three pre-filled cell types** — Primaries (can be layered on), secondaries (locked), and black blockers (locked). Pre-filled secondaries add constraint variety and help ensure unique solutions.
- **Layered mixing with one-layer max** — Placing a primary on another primary creates a secondary. Cells with secondary colors are locked (no further layering). This keeps rules simple and deterministic.
- **Unlimited primary supply** — Player can place any primary color any number of times. The constraint comes from the board layout, mixing rules, and tight target percentages.
- **Target shown as a visual color bar** — Intuitive and game-like. Player matches their board's color ratio to the target bar.
- **Undo fully reverts** — Undo reverses the last action: layered cells revert to their original primary, filled empty cells become empty. Each undo is counted.
- **Scoring: moves + undos** — Total placements plus undo count. Stars awarded based on proximity to the optimal (minimum) move count.
- **4x4 grid for v1** — Compact enough to guarantee unique solutions and keep puzzles quick. Architecture supports scaling to 5x5+ later.
- **Game name: Chromix** — Module path: `lib/games/chromix/`

## Resolved Questions

### Puzzle difficulty tuning
- **Pre-filled cells: 5-9 per puzzle** (varied by seed). Wide initial range to allow tuning from playtesting.
- **Black blockers: 1-4 per puzzle** (varied by seed). Also a wide range for playtesting. Some days feel open, others more constrained.
- The generator should produce puzzles across this range, and the solver verifies each has a unique solution. Narrow the ranges after playtesting.

### Star rating thresholds
- **3 stars** = optimal move count (perfect play)
- **2 stars** = optimal + 3 moves
- **1 star** = puzzle completed (any move count)
- Moderate thresholds — achievable 3 stars with effort, 1 star just for finishing.

### Nostr sharing format
- **Stats only** — stars and score. No board grid or color bar.
- Example: `Chromix #42 ⭐⭐⭐ — 8 moves`
- Keeps it minimal, avoids spoiling the puzzle for others.

### Hint system
- **No hints for v1.** The 4x4 board is small and undo is unlimited — players can learn by experimenting. Hints can be added in a future version if needed.

### Solver performance
- **Main thread first.** A 4x4 grid is small enough that the backtracking solver should run fast on the main thread. Move to a `compute()` isolate only if profiling on low-end devices shows jank. Avoids premature optimization.
