---
title: "feat: add guess the number game"
type: feat
date: 2026-04-02
---

## feat: add guess the number game

## Overview

The first game module for Very Good Games — a deduction puzzle where players narrow down a hidden number (1–400) on a 20x20 grid by asking strategic questions. Each question type (except `= N`) can only be used once, forcing varied mathematical thinking. The game integrates with the hub shell via `GameDefinition` and supports daily mode with deterministic seeding.

## Problem Statement

The game hub shell is built but has no games registered. This is the first game that validates the entire architecture — `GameDefinition` contract, `DailySeed`, streak tracking, and the home screen tile lifecycle.

## Game Design

### Grid

A 20x20 grid of 400 circles. Numbers increase from bottom-left (1) to top-right (400). Row labels on the left edge show the first number of each row. Cells do **not** display their number — instead, a magnifying lens appears when the player touches the grid, showing a zoomed 5x5 area with numbers visible on each cell.

### Cell States

- **Possible** (green) — number is still a candidate
- **Eliminated** (gray) — ruled out by a question
- **Wrong guess** (red) — guessed with `=` and was incorrect
- **Target** (gold) — the correct answer, revealed on win

### Interaction Model — "Card Tray"

Questions are presented as cards in a horizontally scrollable tray at the top of the screen. The turn flow:

1. **Select** — Tap a card in the tray to stage it
2. **Pick parameter** — For questions needing a number, touch the grid and use the magnifying lens to pick a cell. For `ones digit`, use the 0-9 digit picker on the card. No-parameter questions skip this step.
3. **Confirm** — Tap "Play" on the staged card to apply the question
4. **Cancel** — Tap "Cancel" or swipe the card down to abort

Used cards gray out in the tray. The player can switch cards at any time before confirming. Parameters can be re-picked before tapping Play.

### Question Types (8 total)

| Type | Parameter | Description | Mental model |
|---|---|---|---|
| `< N` | Grid cell | Is the target less than N? | Range |
| `odd?` | None | Is the target odd? | Parity |
| `÷ N` | Grid cell | Is the target divisible by N? | Multiples |
| `prime?` | None | Is the target prime? | Number theory |
| `ends in` | Digit (0-9) | Does the ones digit equal N? | Modular arithmetic |
| `= N` | Grid cell | Guess the exact number *(repeatable)* | Risk/reward |
| `shotgun` | None | Picks 50 random numbers — HIT (12.5%): eliminates everything else; MISS (87.5%): eliminates just those 50 | Luck/gamble |
| `grenade` | Grid cell | Eliminates 20 closest remaining cells by Euclidean distance | Spatial |

### Win & Lose Conditions

- **Win**: Only one possible cell remains (auto-detected after any question)
- **Lose**: Score reaches zero (from time drain + question costs)

### Scoring

Formula: `max(0, 600 - (questions × 50) - (seconds × 2))`

- Starting budget: 600 points
- Max time (0 questions): 5 minutes
- Max questions (0 seconds): 12
- Timer starts on first question played (not on page load)
- Score bar drains green → yellow → red as score drops
- Star ratings: 3 stars ≥ 450, 2 stars ≥ 250, 1 star for any win

### Daily Mode

Target number derived from `DailySeed.forDate(today)` via `(seed % 400) + 1`. All players get the same target on the same UTC day. Shotgun results are deterministic per daily seed + question count, so identical play produces identical outcomes.

## Architecture

```
lib/games/guess_the_number/
├── guess_the_number_game.dart    # GameDefinition implementation
├── theme/
│   └── game_colors.dart          # Centralized color constants
├── models/
│   ├── models.dart               # Barrel
│   ├── question_type.dart        # QuestionType enum + QuestionCategory
│   └── cell_state.dart           # CellState enum
├── logic/
│   ├── logic.dart                # Barrel
│   ├── question_evaluator.dart   # Applies questions to the grid
│   ├── prime_checker.dart        # Sieve-based prime check for 1-400
│   └── score_calculator.dart     # Scoring formula + budget constants
├── cubit/
│   ├── game_cubit.dart           # Game state management
│   └── game_state.dart           # State (part file)
└── view/
    ├── view.dart                 # Barrel
    ├── game_page.dart            # Top-level page + timer + streak persistence
    └── widgets/
        ├── widgets.dart          # Barrel
        ├── number_grid.dart      # 20x20 CustomPaint grid + zoom lens overlay
        ├── card_tray.dart        # Scrollable question card tray
        ├── question_card.dart    # Staged card with params + Play/Cancel
        ├── digit_picker.dart     # 0-9 button grid for ones digit
        ├── game_header.dart      # Timer, question count, remaining count
        ├── results_overlay.dart  # Win/lose screen with score breakdown
        └── score_bar.dart        # Live score progress bar
```

## Acceptance Criteria

### Functional

- [x] 20x20 grid renders with numbers 1 (bottom-left) to 400 (top-right)
- [x] Magnifying lens appears on grid touch showing 5x5 zoomed area with numbers
- [x] All 8 question types can be selected and applied correctly
- [x] Question types (except `= N`) can only be used once per game
- [x] Card tray always visible; staged card appears below grid
- [x] Digit picker (0-9) for `ones digit` question
- [x] Eliminated cells dim to gray, wrong guesses turn red
- [x] Score bar drains as time passes and questions are asked
- [x] Game auto-wins when 1 cell remains; target turns gold
- [x] Game auto-loses when score reaches 0
- [x] Results overlay shows win (score + breakdown + stars) or loss
- [x] Daily mode uses deterministic seed
- [x] Shotgun uses deterministic RNG seeded from daily seed
- [x] Game completion persists streak data to storage
- [x] Game appears on home screen tile with correct daily status

### Non-Functional

- [x] Grid renders smoothly at 60fps (400 circles via CustomPaint)
- [x] Zoom lens renders above all UI including AppBar (OverlayEntry)
- [x] Touch response feels immediate

### Quality Gates

- [x] All logic classes have unit tests
- [x] GameCubit has bloc_test coverage for all state transitions
- [ ] Widget tests for view components
- [x] `flutter analyze` passes with zero issues
- [x] All tests pass

## Dependencies

- **Game hub shell** (committed at `d7c1908`)
- **No new packages** — uses flutter_bloc, go_router, equatable, shared_preferences

## Future Considerations

- **Nostr result sharing** — shareable Nostr note with score
- **Practice mode** — random non-daily target
- **Elimination animations** — ripple/fade on eliminated cells
- **Sound effects** — audio feedback
- **Session persistence** — save/restore game across app kills
- **Onboarding tutorial** — interactive first-time walkthrough
- **Game log** — scrollable history of questions asked

## References

- Brainstorm: [docs/brainstorm/2026-04-02-daily-games-hub-brainstorm-doc.md](docs/brainstorm/2026-04-02-daily-games-hub-brainstorm-doc.md)
- Game hub shell plan: [docs/plan/2026-04-02-feat-game-hub-shell-plan.md](docs/plan/2026-04-02-feat-game-hub-shell-plan.md)
- `GameDefinition`: [lib/core/game_registry/game_definition.dart](lib/core/game_registry/game_definition.dart)
- `DailySeed`: [lib/core/daily_seed/daily_seed.dart](lib/core/daily_seed/daily_seed.dart)
- `GameStorageRepository`: [lib/core/storage/game_storage_repository.dart](lib/core/storage/game_storage_repository.dart)
