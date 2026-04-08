---
date: 2026-04-07
topic: chromix-contiguity-constraint
---

# Chromix — Contiguity Constraint for Harder Puzzles

## What We're Building

Add a spatial contiguity rule to Chromix: all cells of the same color must form a connected group (orthogonally adjacent). This transforms the puzzle from pure color-count matching into a spatial reasoning challenge. The rule applies to all 6 colors (primaries and secondaries), is shown as an explicit rule in instructions, and is enforced at solve time with live UI feedback.

## Why This Approach

The current Chromix puzzles are too easy across the board — solutions are obvious, puzzles are short, and 3 stars is almost guaranteed. The root cause is that players only need to match color counts without caring about where colors go. Three approaches were considered:

1. **Generation-side contiguity + solver validation (chosen):** Modify the generator to build contiguous color regions, update the solver to reject non-contiguous solutions, and add live feedback in the cubit/UI. Full implementation that works cleanly with the existing architecture.

2. **Post-generation filter:** Keep the generator as-is, reject non-contiguous puzzles after the fact. Simpler but wasteful — many puzzles would be rejected, and the solver wouldn't respect the constraint.

3. **Visual hint only:** Add a connectivity indicator without enforcing the rule. Doesn't actually increase difficulty — just adds optional information.

Approach 1 was chosen because it addresses the difficulty problem at every layer (generation, solving, gameplay) and integrates naturally with the existing generate → solve → play pipeline.

## Key Decisions

- **Keep 4x4 grid:** The grid size is fine; the problem is lack of spatial reasoning, not lack of cells. We can always increase grid size later if needed.
- **Contiguity applies to all 6 colors:** Red, yellow, blue, orange, green, and purple groups must each be contiguous. Maximum spatial constraint.
- **Explicit rule:** Shown in the instructions dialog and enforced in the UI. Players know the rule upfront rather than discovering it implicitly.
- **Contiguity only for now:** No changes to pre-fill count, blocker count, or star thresholds. Ship the spatial constraint, playtest, then tune further if needed.
- **Generation-aware:** `_buildSolution()` should place colors in contiguous groups (e.g., flood-fill or region-growing) rather than randomly assigning colors and hoping for contiguity.
- **Solver-aware:** `PuzzleSolver` must reject solutions where any color group is disconnected.
- **Live UI feedback:** The cubit should check contiguity after each move. Disconnected groups could be highlighted or flagged so the player knows they're violating the rule before they finish.

## Open Questions

- What UI treatment for disconnected groups? Subtle border/highlight, or a more prominent warning?
- Should the win condition block completion if contiguity is violated, or just prevent 3 stars?
- Will the contiguity constraint make puzzle generation significantly slower? May need to profile the generator with the new constraint.
- Should `isFullyFilled && distributionMatches && allGroupsContiguous` all be required for a win, or should contiguity be a separate quality gate?
