---
date: 2026-04-12
topic: game-timer
---

# Game Timer Across All Games

## What We're Building

A visible elapsed-time timer for all four games (Chromix, Guess the Number, Signal Grid, Cascade). The timer starts when the player begins interacting with a puzzle, pauses when the game screen is not visible (app backgrounded or navigated away), and resumes when the player returns. The final elapsed time is persisted in the session state, included in Nostr result events, and used to compute an average completion time shown in the community stats section of the leaderboard.

Guess the Number already tracks `elapsedSeconds` in its event builder. This feature extends that pattern to the remaining three games and adds a shared implementation so all games handle timing consistently.

## Why This Approach

Three approaches were considered:

1. **Shared `GameTimerMixin` on game cubits (chosen)** -- A mixin that adds `startTimer()`, `pauseTimer()`, `resumeTimer()`, and `elapsedSeconds` to any cubit. Each game cubit mixes it in and calls start/pause/resume at the right lifecycle points. Timer logic lives in one place; per-game code is minimal.

2. **Per-game cubit code** -- Each cubit manages its own `Timer` and elapsed field independently. Simple but duplicates ~30 lines of identical logic four times with no guarantee of consistency.

3. **Separate `GameTimerCubit`** -- A standalone cubit composed alongside each game cubit. Cleanest separation but requires additional provider wiring on every game page and coordination between two cubits for persistence and result sharing.

The mixin was chosen because it keeps timer logic DRY, avoids extra provider wiring, and lets each game cubit own its full state (including elapsed time) for persistence and Nostr sharing.

## Key Decisions

- **Mixin in `lib/core/`**: `GameTimerMixin` on `Cubit` provides `elapsedSeconds`, `startTimer()`, `pauseTimer()`, `resumeTimer()`, and `disposeTimer()`. Ticks every second and emits state via a callback.
- **Pause via `WidgetsBindingObserver` + `RouteAware`**: Game pages register as observers. On `AppLifecycleState.paused`/`inactive` or route push (navigated away), call `pauseTimer()`. On `resumed` or route pop-back, call `resumeTimer()`.
- **Session persistence**: `elapsedSeconds` is added to each game's session JSON alongside existing fields (e.g., `moveCount`). Restored on app restart so the timer continues from where it left off.
- **Nostr result events**: Each game's `EventBuilder.build*Result()` method gets an `elapsedSeconds` parameter. Added as an `['l', 'time-<seconds>', 'games.vgg.time']` tag (matching the existing Guess the Number pattern).
- **Community stats**: `CommunityStatsCubit` computes average time from result events that include the time tag. Displayed as "Avg. time: M:SS" in the `CommunityStatsSection`.
- **Timer display during gameplay**: A small `Text` widget showing `M:SS` displayed near the move counter at the bottom of each game page. Uses `bodySmall` style to stay unobtrusive.
- **Timer starts on first interaction**: Not on page load. The timer begins when the player makes their first move (drag, tap, etc.) to avoid penalizing players who read the board before acting.

## Open Questions

- Should the timer display show tenths of a second, or just whole seconds? (Leaning toward whole seconds for simplicity.)
- Should completed games show the final time in the results overlay, or just in the shared Nostr event?
