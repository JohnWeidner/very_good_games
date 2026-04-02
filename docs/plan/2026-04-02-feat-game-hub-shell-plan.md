---
title: "feat: add game hub shell"
type: feat
date: 2026-04-02
---

## feat: add game hub shell

## Overview

Build the foundational app shell for Very Good Games — a daily puzzle hub. This establishes the project architecture, navigation, theming, state management foundation, daily seed infrastructure, and the game registry contract that all future game modules will plug into. No individual game logic is included; this is purely the structural foundation.

## Problem Statement / Motivation

The project is currently a bare Flutter scaffold (`Hello World`). Before building any game (starting with Guess the Number), we need the app shell that:

1. Defines the **modular architecture** so games can be added independently
2. Provides **navigation** between the home screen and game modules
3. Establishes the **game registry contract** — the interface every game must implement
4. Sets up **daily seed generation** so all players get the same puzzle each day
5. Provides **theming and branding** for a consistent look
6. Tracks **daily completion status and streaks** at the shell level
7. Sets up **VGV-standard tooling** (very_good_analysis, bloc, go_router)

Getting this right first means every subsequent game "just plugs in" without reworking the foundation.

## Proposed Solution

### Architecture

Feature-based modular structure following VGV conventions:

```
lib/
├── app/
│   ├── app.dart                    # App widget (MaterialApp.router)
│   ├── app_bloc_observer.dart      # Bloc observer for debugging
│   └── routes/
│       └── routes.dart             # GoRouter configuration
├── core/
│   ├── daily_seed/
│   │   └── daily_seed.dart         # Deterministic daily seed generator
│   ├── game_registry/
│   │   ├── game_definition.dart    # GameDefinition interface
│   │   └── game_registry.dart      # Registry of available games
│   ├── storage/
│   │   └── game_storage.dart       # Local storage interface (shared_preferences)
│   └── theme/
│       └── app_theme.dart          # App-wide theming
├── home/
│   ├── bloc/
│   │   ├── home_bloc.dart          # Home screen state management
│   │   ├── home_event.dart
│   │   └── home_state.dart
│   └── view/
│       ├── home_page.dart          # Home screen with game tiles
│       └── widgets/
│           └── game_tile.dart      # Individual game card/tile
└── main.dart                       # Entry point
```

### Game Registry Contract

The core abstraction — every game module implements `GameDefinition`:

```dart
/// Contract that every game module must implement to register
/// with the hub shell.
abstract class GameDefinition {
  /// Unique identifier for this game (e.g., 'guess_the_number').
  String get id;

  /// Display name shown on the home screen tile.
  String get name;

  /// Short description shown below the game name.
  String get description;

  /// Icon displayed on the game tile.
  IconData get icon;

  /// The route path for this game (e.g., '/games/guess-the-number').
  String get routePath;

  /// Returns the GoRoute(s) for this game module.
  /// The shell adds these to the router automatically.
  List<RouteBase> get routes;

  /// Returns the current daily status for this game.
  /// The shell calls this to render the tile state.
  Future<DailyGameStatus> getDailyStatus(DateTime date);
}

enum DailyGameStatus { notStarted, inProgress, completed }
```

**Key design decision:** The shell does NOT own in-progress game state. Each game module manages its own session persistence. The shell only queries status (`notStarted | inProgress | completed`) to render tiles.

### Daily Seed Generation

```dart
/// Generates a deterministic seed from a UTC date.
/// All players get the same seed for the same calendar day.
class DailySeed {
  /// Returns the seed for today (UTC).
  static int today() => forDate(DateTime.now().toUtc());

  /// Returns a deterministic seed for a given date.
  /// Uses only year, month, day (UTC) — ignores time.
  static int forDate(DateTime date) {
    final dateString = '${date.year}-${date.month}-${date.day}';
    // Simple hash that produces a consistent int from the date string
    return dateString.hashCode.abs();
  }
}
```

**Decision: UTC, not local time.** This ensures all players worldwide get the same puzzle on the same calendar day. The tradeoff is that the "day" resets at midnight UTC, not midnight local — but consistency across players matters more for a social/competitive game.

### Navigation (go_router)

```dart
GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    // Game routes are injected from the registry
    ...gameRegistry.allGames.expand((game) => game.routes),
  ],
);
```

Games own their internal navigation but the shell owns the top-level router and injects game routes dynamically from the registry.

### Home Screen

Displays a grid/list of game tiles, each showing:
- Game name and icon (from `GameDefinition`)
- Daily status badge (not started / in progress / completed)
- Streak count (if applicable)

The home screen loads game statuses on appear and refreshes when:
- The app returns to foreground (via `WidgetsBindingObserver`)
- The user navigates back from a game
- A date change is detected

### Streak Tracking

The shell owns streak data because it spans across app sessions:

```dart
/// Stored per game in local storage.
class StreakData {
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastCompletedDate; // UTC date only
}
```

When a game reports `completed` status, the shell updates the streak. If `lastCompletedDate` is yesterday (UTC), the streak increments. If it's older, the streak resets to 1.

### Date Change Detection

The shell must handle the day rolling over while the app is open:

1. **On app resume** (`didChangeAppLifecycleState`): Compare stored "last checked date" with current UTC date. If different, refresh all game statuses.
2. **Periodic check**: A simple timer (every 60s) checks for date change while the app is in the foreground. This handles the midnight-while-playing edge case.
3. **On navigation to home**: Always refresh statuses.

## Technical Considerations

### Dependencies to Add

| Package | Purpose |
|---|---|
| `flutter_bloc` | State management (VGV standard) |
| `bloc` | Core bloc library |
| `go_router` | Declarative routing |
| `shared_preferences` | Local storage for streaks/status |
| `equatable` | Value equality for bloc states |
| `very_good_analysis` | VGV lint rules (replaces flutter_lints) |

### Architecture Decisions

- **Shell owns streaks, games own session state.** The shell tracks completion dates and streak counts. Games manage their own in-progress state, save/restore, and internal UI.
- **UTC everywhere for dates.** Daily seeds, streak tracking, and completion timestamps all use UTC date (year/month/day only). No timezone ambiguity.
- **Games register via a list, not auto-discovery.** The `GameRegistry` takes an explicit list of `GameDefinition` instances. No reflection or code generation — simple and debuggable.
- **No onboarding in v1.** First launch goes directly to the home screen. Onboarding/tutorial is a future enhancement.

### Edge Cases

- **Empty state**: If no games are registered, the home screen shows a friendly "Games coming soon" message. Relevant during development.
- **First launch**: No special handling — streak starts at 0, all games show "not started."
- **Returning after multiple days away**: Streak resets on first completion. No penalty, just a fresh start.
- **Date rollover mid-game**: The game module is responsible for checking its own seed validity. The shell refreshes statuses on the next home screen visit.

## Acceptance Criteria

- [ ] Project uses `very_good_analysis` for linting (replaces `flutter_lints`)
- [ ] `GameDefinition` abstract class defined in `lib/core/game_registry/game_definition.dart`
- [ ] `GameRegistry` class holds list of registered games in `lib/core/game_registry/game_registry.dart`
- [ ] `DailySeed` utility generates deterministic seeds from UTC dates in `lib/core/daily_seed/daily_seed.dart`
- [ ] `DailySeed.forDate()` returns identical values for the same date across calls
- [ ] `AppTheme` provides light theme configuration in `lib/core/theme/app_theme.dart`
- [ ] `GoRouter` configured with home route and dynamic game route injection in `lib/app/routes/routes.dart`
- [ ] Home screen displays game tiles from the registry in `lib/home/view/home_page.dart`
- [ ] Game tiles show daily status (`notStarted`, `inProgress`, `completed`) in `lib/home/view/widgets/game_tile.dart`
- [ ] `HomeBloc` manages home screen state (loading games, refreshing statuses) in `lib/home/bloc/home_bloc.dart`
- [ ] App refreshes game statuses on foreground resume via `WidgetsBindingObserver`
- [ ] `StreakData` model and persistence via `shared_preferences` in `lib/core/storage/game_storage.dart`
- [ ] Streak increments on consecutive-day completions, resets after a gap
- [ ] Empty state handled when no games are registered
- [ ] All new classes have corresponding unit tests
- [ ] `main.dart` updated to use the new `App` widget with bloc and router setup

## Success Metrics

- A new game can be added by: (1) implementing `GameDefinition`, (2) adding it to the registry list — no shell changes needed
- All unit tests pass
- `flutter analyze` passes with zero issues under `very_good_analysis`
- Home screen renders correctly with zero games and with a mock game registered

## Dependencies & Risks

**Dependencies:**
- None — this is the first layer of the app, building on a blank scaffold

**Risks:**
- **`GameDefinition` contract may need iteration** once we build the first real game (Guess the Number). The contract is intentionally minimal to reduce this risk — better to add fields later than remove them.
- **`hashCode` for daily seed** — Dart's `String.hashCode` is not guaranteed stable across isolates or Dart versions. Before shipping, we should replace this with a deterministic hash (e.g., simple djb2 or FNV-1a). Acceptable for v1 development but must be addressed before release.

## References & Research

- Brainstorm: [docs/brainstorm/2026-04-02-daily-games-hub-brainstorm-doc.md](docs/brainstorm/2026-04-02-daily-games-hub-brainstorm-doc.md)
- Current scaffold: [lib/main.dart](lib/main.dart)
- VGV conventions: flutter_bloc + go_router + very_good_analysis
- Reference project for Nostr (future): `/Users/john/AndroidStudioProjects/divine-mobile`
