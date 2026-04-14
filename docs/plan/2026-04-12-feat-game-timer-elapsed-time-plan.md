---
title: "feat: add elapsed-time timer to all games"
type: feat
date: 2026-04-12
---

## feat: add elapsed-time timer to all games - Standard

## Overview

Add a visible elapsed-time timer to all four games (Chromix, Guess the Number, Signal Grid, Cascade). The timer starts on first player interaction, pauses when the app is backgrounded, and resumes when the player returns. Final elapsed time is persisted in session state, included in Nostr result events, and used to compute average completion time in community stats.

Guess the Number already tracks `elapsedSeconds` with a view-managed `Timer.periodic` and cubit `tick()` method. This feature extracts that logic into a shared `GameTimerMixin`, migrates GTN to use it, and adds timer support to the remaining three games.

## Problem Statement / Motivation

Players have no sense of how long they spend on a puzzle, and the leaderboard lacks a time dimension. Adding elapsed time:
- Gives players a personal benchmark to improve against
- Enables community "Avg. time" stats alongside existing score stats
- Makes Nostr result sharing richer (time is already partially supported for GTN)
- Creates a consistent timing experience across all four games

## Proposed Solution

### 1. `GameTimerMixin` in `lib/core/timer/`

A mixin on `Cubit` that encapsulates all timer logic:

```dart
// lib/core/timer/game_timer_mixin.dart
mixin GameTimerMixin on Cubit {
  Timer? _gameTimer;
  int _elapsedSeconds = 0;
  bool _timerStarted = false;
  bool _timerPaused = false;

  int get elapsedSeconds => _elapsedSeconds;
  bool get timerStarted => _timerStarted;

  void initTimer({int initialSeconds = 0, bool alreadyStarted = false});
  void startTimer();       // Called on first interaction
  void pauseTimer();       // Called on app background
  void resumeTimer();      // Called on app foreground
  void resetTimer();       // Called on debug reset
  void disposeTimer();     // Called in cubit close()

  /// Each cubit implements this to emit state with new elapsedSeconds.
  void onTimerTick(int elapsedSeconds);
}
```

**Key design decision — `onTimerTick` callback**: The mixin cannot call `emit()` because it doesn't know the shape of `T` in `Cubit<T>`. Each game cubit implements `onTimerTick(int elapsedSeconds)` to emit its own state with the updated value. This also lets GTN run its score-loss check inside `onTimerTick`.

The mixin owns `Timer.periodic(Duration(seconds: 1), ...)` internally. The view does **not** manage the timer — it only calls `startTimer()`, `pauseTimer()`, `resumeTimer()`.

### 2. Migrate Guess the Number

Remove the view-managed `Timer.periodic` from [game_page.dart:99-108](lib/games/guess_the_number/view/game_page.dart#L99-L108). Remove the public `tick()` method from [game_cubit.dart:320-348](lib/games/guess_the_number/cubit/game_cubit.dart#L320-L348). Mix in `GameTimerMixin` and implement `onTimerTick` with the existing score-loss logic:

```dart
// game_cubit.dart
class GameCubit extends Cubit<GameState> with GameTimerMixin {
  @override
  void onTimerTick(int elapsedSeconds) {
    if (state.status.isTerminal) return;
    final newScore = ScoreCalculator.calculate(
      questions: state.questionCount,
      seconds: elapsedSeconds,
    );
    if (newScore <= 0) {
      emit(state.copyWith(elapsedSeconds: elapsedSeconds, status: GameStatus.lost, score: () => 0));
      _clearSession();
      return;
    }
    emit(state.copyWith(elapsedSeconds: elapsedSeconds));
  }
}
```

Session persistence and restoration unchanged — `elapsedSeconds` and `timerStarted` fields already exist.

### 3. Add timer to Chromix, Signal, and Cascade

Each game cubit:
1. Mix in `GameTimerMixin`
2. Add `elapsedSeconds` and `timerStarted` fields to state class
3. Implement `onTimerTick` (simple emit, no score-loss logic — time is informational)
4. Call `startTimer()` on first state-changing action
5. Call `disposeTimer()` in `close()` override
6. Persist `elapsedSeconds` and `timerStarted` in session JSON
7. Restore from session with `initTimer(initialSeconds: saved, alreadyStarted: saved)`
8. Default `elapsedSeconds` to `0` when deserializing old sessions (backwards compatibility)

**First-interaction triggers:**
| Game | Timer starts on | Method |
|------|----------------|--------|
| Guess the Number | First `confirmQuestion()` | Existing `timerStarted` flag |
| Chromix | First completed placement (`_placeOnEmpty` / `_handleDragOntoColor`) | Set flag before emit |
| Signal | First successful `toggleCell()` that modifies grid | Set flag before emit |
| Cascade | First `assignBall()` or `flipLever()` | Set flag before emit |

### 4. App lifecycle pause/resume via `WidgetsBindingObserver`

Each game page's inner `StatefulWidget` (e.g., `_ChromixView`, `_SignalView`, `_CascadeView`, `_GameView`) adds `WidgetsBindingObserver`:

```dart
class _ChromixView extends State<...> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<ChromixCubit>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      cubit.pauseTimer();
    } else if (state == AppLifecycleState.resumed) {
      cubit.resumeTimer();
    }
  }
}
```

**Why no `RouteAware`**: GoRouter has no `RouteObserver` configured, and the main navigation-away flow (`context.go('/')`) destroys the game page entirely (cubit disposed, timer canceled). Instructions dialogs appear before first interaction (timer not started). Adding `RouteAware` infrastructure for minimal benefit is deferred. `WidgetsBindingObserver` alone covers the primary pause scenario (app backgrounded).

### 5. Timer display in game views

A small `M:SS` text displayed near each game's existing stats area using `bodySmall` style:

| Game | Location | Placement |
|------|----------|-----------|
| Guess the Number | [game_header.dart](lib/games/guess_the_number/view/widgets/game_header.dart) | Already has timer `_StatChip` — refactor to use mixin's `elapsedSeconds` |
| Chromix | [chromix_page.dart:256](lib/games/chromix/view/chromix_page.dart#L256) | Add timer text to `_UndoRow` alongside "X moves, Y undos" |
| Signal | [signal_page.dart:184](lib/games/signal/view/signal_page.dart#L184) | Add timer text alongside "X moves" |
| Cascade | [cascade_page.dart:234](lib/games/cascade/view/cascade_page.dart#L234) | Add timer text to `_ActionRow` alongside "X attempts" |

Timer display: hidden during `loading` state, shows `0:00` once loaded (before first interaction), runs during gameplay, freezes at final value on win/loss/fail.

Add `Semantics(label: '$minutes minutes and $seconds seconds elapsed')` for screen reader accessibility.

### 6. Nostr result events

Add `elapsedSeconds` parameter to the three remaining event builders:
- `EventBuilder.buildChromixResult()` ([event_builder.dart](lib/nostr/sharing/event_builder.dart))
- `EventBuilder.buildSignalResult()`
- `EventBuilder.buildCascadeResult()`

Each adds the tag: `['l', 'time-$elapsedSeconds', 'games.vgg.score']`

**Namespace**: Use existing `games.vgg.score` (not `games.vgg.time` as the brainstorm suggested). GTN already publishes time tags under this namespace. Consistency avoids a migration.

Each game's share flow passes `elapsedSeconds` from the terminal state to the event builder.

### 7. Community stats — average time

Extend [community_stats_repository.dart](lib/nostr/stats/repository/community_stats_repository.dart):
- Add `_extractTime(Nip01Event)` method following the existing `_extractScore` pattern (line 205)
- Compute `avgTime` (average of all `time-N` values from events that have the tag)
- Add `avgTime` field to the `CommunityStats` model

Extend [CommunityStatsSection widget](lib/nostr/sharing/view/community_stats_section.dart):
- Display "Avg. time: M:SS" alongside existing player count and avg score

Events without a time tag are excluded from the average (backwards compatible with older GTN events that may lack the tag, and with any games where time wasn't tracked).

## Technical Considerations

- **Mixin + cubit lifecycle**: `disposeTimer()` must be called in every cubit's `close()` override. Chromix already overrides `close()` for `_overpowerTimer` — both timers must be cleaned up.
- **Cascade multi-phase**: Timer runs continuously through `configuring` -> `dropping` -> `failed` -> (reset) -> `configuring` -> ... -> `won`. It only stops on `won`. Time is purely informational for Cascade (does not affect score).
- **Session persistence frequency**: Timer is persisted only on user actions (not every tick), matching existing GTN behavior. On force-kill, seconds since last action are lost. Acceptable tradeoff — most puzzle actions happen frequently.
- **Backwards compatibility**: Old sessions without `elapsedSeconds` deserialize to `0` and `timerStarted: false`. No migration needed.
- **Score impact**: Time affects scoring **only** in GTN (existing `ScoreCalculator.costPerSecond`). For Chromix, Signal, and Cascade, time is purely informational (display + Nostr sharing). Score calculators unchanged.
- **Display overflow**: For times over 59:59 (unlikely in normal play), format as `H:MM:SS`. Simple guard in the format helper.

## Acceptance Criteria

### Core timer mixin (`lib/core/timer/`)
- [ ] `GameTimerMixin` provides `startTimer()`, `pauseTimer()`, `resumeTimer()`, `resetTimer()`, `disposeTimer()`, `initTimer()`
- [ ] Mixin ticks every second and calls `onTimerTick(elapsedSeconds)` on each tick
- [ ] `startTimer()` is idempotent (calling twice doesn't double-tick)
- [ ] `pauseTimer()` stops ticking; `resumeTimer()` restarts from where it left off
- [ ] `resetTimer()` sets elapsed to 0 and stops the timer
- [ ] `disposeTimer()` cancels the internal `Timer` and is safe to call multiple times
- [ ] Unit tests cover start, pause, resume, reset, dispose, and edge cases (pause when not started, resume when not paused)

### Guess the Number migration
- [ ] `GameCubit` mixes in `GameTimerMixin` and implements `onTimerTick` with score-loss logic
- [ ] View-managed `Timer.periodic` removed from `_GameViewState`
- [ ] `_GameViewState` adds `WidgetsBindingObserver` for pause/resume
- [ ] Existing behavior unchanged: timer starts on first `confirmQuestion()`, score decrements over time, auto-loss at score 0
- [ ] Session persistence unchanged (`elapsedSeconds` and `timerStarted` fields)
- [ ] Existing tests updated to reflect mixin-based timer

### Chromix timer
- [ ] `ChromixState` gains `elapsedSeconds: int` and `timerStarted: bool` fields
- [ ] `ChromixCubit` mixes in `GameTimerMixin`, implements `onTimerTick` (emit state)
- [ ] Timer starts on first completed color placement
- [ ] Timer stops on win (`ChromixStatus.won`)
- [ ] `_ChromixView` adds `WidgetsBindingObserver` for pause/resume
- [ ] Session JSON includes `elapsedSeconds` and `timerStarted`; old sessions default to 0
- [ ] `disposeTimer()` called in `close()` alongside existing `_overpowerTimer?.cancel()`
- [ ] Timer display shown in `_UndoRow` as `M:SS` with semantics label

### Signal timer
- [ ] `SignalState` gains `elapsedSeconds: int` and `timerStarted: bool` fields
- [ ] `SignalCubit` mixes in `GameTimerMixin`, implements `onTimerTick` (emit state)
- [ ] Timer starts on first successful `toggleCell()` that modifies the grid
- [ ] Timer stops on win (`SignalStatus.won`)
- [ ] `_SignalView` adds `WidgetsBindingObserver` for pause/resume
- [ ] Session JSON includes `elapsedSeconds` and `timerStarted`; old sessions default to 0
- [ ] Timer display shown alongside "X moves" text with semantics label

### Cascade timer
- [ ] `CascadeState` gains `elapsedSeconds: int` and `timerStarted: bool` fields
- [ ] `CascadeCubit` mixes in `GameTimerMixin`, implements `onTimerTick` (emit state)
- [ ] Timer starts on first `assignBall()` or `flipLever()`
- [ ] Timer runs through `failed` status and resets (does NOT pause on failure)
- [ ] Timer stops on win (`CascadeStatus.won`)
- [ ] `_CascadeView` adds `WidgetsBindingObserver` for pause/resume
- [ ] Session JSON includes `elapsedSeconds` and `timerStarted`; old sessions default to 0
- [ ] Timer display shown in `_ActionRow` alongside "X attempts" with semantics label

### Nostr result events
- [ ] `buildChromixResult()` accepts `elapsedSeconds` and adds `['l', 'time-$elapsedSeconds', 'games.vgg.score']` tag
- [ ] `buildSignalResult()` accepts `elapsedSeconds` and adds the time tag
- [ ] `buildCascadeResult()` accepts `elapsedSeconds` and adds the time tag
- [ ] Each game's share flow passes `elapsedSeconds` from terminal state to event builder
- [ ] Time displayed as `MM:SS` in event content text (matching GTN pattern)

### Community stats
- [ ] `CommunityStatsRepository` extracts `time-N` tags via `_extractTime()` method
- [ ] `CommunityStats` model includes `avgTime` (nullable — null when no time data)
- [ ] `CommunityStatsSection` displays "Avg. time: M:SS" when `avgTime` is available
- [ ] Events without time tags are excluded from average calculation

### Results overlay
- [ ] All four games display final elapsed time in the results overlay

### Testing
- [ ] `GameTimerMixin` unit tests (start, pause, resume, reset, dispose, tick counting, edge cases)
- [ ] Each game cubit's `onTimerTick` tested (state emission, GTN score-loss, terminal state guards)
- [ ] Session persistence round-trip tests (save with time, restore with time, restore without time)
- [ ] Event builder tests for time tag inclusion
- [ ] `CommunityStatsRepository` tests for `_extractTime` and average calculation
- [ ] Widget tests for timer display in each game page
- [ ] `WidgetsBindingObserver` lifecycle tests (pause/resume calls)

## Success Metrics

- Timer displays correctly in all four games during gameplay
- Timer pauses when app is backgrounded and resumes correctly
- Nostr result events include accurate elapsed time for all games
- Community stats show average completion time
- No regression in existing GTN timer/scoring behavior
- All existing tests continue to pass

## Dependencies & Risks

- **Mixin pattern complexity**: The `onTimerTick` callback approach adds one abstract method per cubit. If this feels heavy, an alternative is a simple helper class with a `Stream<int>` that cubits subscribe to. The mixin approach was chosen because it keeps state ownership within the cubit.
- **GTN migration risk**: Removing the view-managed timer and replacing with mixin-managed timer changes the control flow. Thorough testing of the existing tick-based score loss is critical.
- **Chromix `close()` override**: Already overrides `close()` for `_overpowerTimer`. Adding `disposeTimer()` is straightforward but must not be missed.
- **RouteAware deferred**: Timer will NOT pause when navigating to a dialog (e.g., re-opening instructions mid-game via info button, if that exists). This is acceptable for v1 since the instructions dialog only appears before first interaction.

## Deferred

- `RouteAware` / `RouteObserver` integration for in-app navigation pause (adds GoRouter observer infrastructure)
- User setting to hide timer display (for anxiety-sensitive players)
- Tenths-of-a-second display precision
- Time as a scoring factor for Chromix, Signal, or Cascade

## Open Questions from Brainstorm (Resolved)

- **Tenths of a second?** Deferred — whole seconds for v1 (simpler, matches GTN).
- **Show time in results overlay?** Yes — all four games show final time in results overlay for consistency.

## References & Research

- Brainstorm: [docs/brainstorm/2026-04-12-game-timer-brainstorm-doc.md](docs/brainstorm/2026-04-12-game-timer-brainstorm-doc.md)
- GTN timer reference: [game_cubit.dart:320-348](lib/games/guess_the_number/cubit/game_cubit.dart#L320-L348) (tick logic), [game_page.dart:99-108](lib/games/guess_the_number/view/game_page.dart#L99-L108) (view timer)
- GTN state fields: [game_state.dart:64-67](lib/games/guess_the_number/cubit/game_state.dart#L64-L67) (`elapsedSeconds`, `timerStarted`)
- Event builder time tag: [event_builder.dart:44](lib/nostr/sharing/event_builder.dart#L44) (`['l', 'time-$elapsedSeconds', 'games.vgg.score']`)
- Stats extraction: [community_stats_repository.dart:205-215](lib/nostr/stats/repository/community_stats_repository.dart#L205-L215) (`_extractScore` pattern)
- Home lifecycle observer: [home_page.dart:35-53](lib/home/view/home_page.dart#L35-L53) (existing `WidgetsBindingObserver` reference)
- Storage repository: [game_storage_repository.dart:50-68](lib/core/storage/game_storage_repository.dart#L50-L68) (session save/restore)
