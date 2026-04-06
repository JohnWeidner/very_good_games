---
title: "feat: High Score Leaderboard — Part 4: Game Integration"
date: 2026-04-06
type: implementation
status: ready
---

# High Score Leaderboard — Part 4: Game Integration

## Overview

Wire `LeaderboardCubit` into game pages, add `LeaderboardSection` to results overlays for both Guess the Number and Signal games, and ensure `dTag` is accessible from game state. Minimal, focused changes to existing game-specific code.

**Part of:** High Score Leaderboard feature

**Dependencies:** Part 3 (UI widget) must be merged first.

---

## Problem & Scope

The leaderboard widget is built and tested in isolation. This PR connects it into the game flow: provide the cubit at the page level, render the widget in results overlays, and verify that game state exposes the `dTag` needed for leaderboard queries.

### Acceptance Criteria

- [ ] `LeaderboardCubit` provided in `GamePage` via `MultiBlocProvider`
- [ ] `LeaderboardCubit` provided in `SignalPage` via `MultiBlocProvider`
- [ ] `LeaderboardSection` added to `ResultsOverlay` after `CommunityStatsSection`
- [ ] `LeaderboardSection` added to `SignalResultsOverlay` after `CommunityStatsSection`
- [ ] Both overlays pass `dTag` to `LeaderboardSection`
- [ ] Both overlays pass `userPubKeyHex` (from identity) to widget (optional)
- [ ] Game states (GameState, SignalState) have accessible `dTag` field
- [ ] Leaderboard displays in overlay without blocking render
- [ ] Both games render results overlay correctly with leaderboard visible
- [ ] No new dependencies; uses existing game page structure

---

## Technical Architecture

### Changes to Game Pages

#### 1. Guess the Number: `lib/games/guess_the_number/view/game_page.dart`

**Location:** In `MultiBlocProvider` inside `GamePage.build()`, after existing providers (~line 36-64)

**Add:**
```dart
BlocProvider(
  create: (context) => LeaderboardCubit(
    statsRepository: context.read<CommunityStatsRepository>(),
    identityRepository: context.read<NostrIdentityRepository>(),
  ),
),
```

**Full provider block (after changes):**
```dart
MultiBlocProvider(
  providers: [
    BlocProvider(
      create: (context) {
        final storage = context.read<GameStorageRepository>();
        return GameCubit.restore(
              targetNumber: targetNumber,
              dailySeed: dailySeed,
              storageRepository: storage,
            ) ??
            GameCubit(
              targetNumber: targetNumber,
              dailySeed: dailySeed,
              storageRepository: storage,
            );
      },
    ),
    BlocProvider(
      create: (context) => ResultSharingCubit(
        identityRepository: context.read<NostrIdentityRepository>(),
        publishRepository: context.read<NostrPublishRepository>(),
      ),
    ),
    BlocProvider(
      create: (context) => CommunityStatsCubit(
        statsRepository: context.read<CommunityStatsRepository>(),
      ),
    ),
    // ADD THIS NEW PROVIDER:
    BlocProvider(
      create: (context) => LeaderboardCubit(
        statsRepository: context.read<CommunityStatsRepository>(),
        identityRepository: context.read<NostrIdentityRepository>(),
      ),
    ),
  ],
  child: const _GameView(),
)
```

**Imports to add:**
```dart
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
```

#### 2. Signal: `lib/games/signal/view/signal_page.dart`

**Same pattern as above.** Locate `MultiBlocProvider` in `SignalPage.build()` and add the same `BlocProvider` for `LeaderboardCubit` after existing providers.

**Imports to add:**
```dart
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
```

---

### Changes to Results Overlays

#### 1. Guess the Number: `lib/games/guess_the_number/view/widgets/results_overlay.dart`

**Location:** After `CommunityStatsSection()` widget (currently ~line 89)

**Current code:**
```dart
ShareResultButton(onShare: () => _share(context)),
const CommunityStatsSection(),  // <-- ADD AFTER THIS
] else ...[
```

**Add after `CommunityStatsSection()`:**
```dart
const LeaderboardSection(dTag: dTag),
```

**Full snippet (after changes):**
```dart
ShareResultButton(onShare: () => _share(context)),
const CommunityStatsSection(),
const LeaderboardSection(dTag: dTag),  // ADD THIS LINE
const SizedBox(height: 24),
FilledButton(...)
```

**Note:** Verify `dTag` is accessible in `ResultsOverlay` constructor/state. If not already present, add to `GameState`:
```dart
// In GameState (lib/games/guess_the_number/cubit/game_state.dart)
String get dTag => 'guess-the-number:${dateKey()}';  // Use existing dateKey() helper
```

**Imports to add:**
```dart
import 'package:very_good_games/nostr/stats/view/leaderboard_section.dart';
```

#### 2. Signal: `lib/games/signal/view/widgets/signal_results_overlay.dart`

**Same pattern as above.** Locate where `CommunityStatsSection()` is used (~line 77) and add `LeaderboardSection` immediately after.

**Add:**
```dart
const LeaderboardSection(dTag: dTag),
```

**Note:** Verify `dTag` is accessible in `SignalResultsOverlay`. Add to `SignalState` if needed:
```dart
// In SignalState (lib/games/signal/cubit/signal_state.dart)
String get dTag => 'signal:${dateKey()}';  // Use existing dateKey() helper
```

**Imports to add:**
```dart
import 'package:very_good_games/nostr/stats/view/leaderboard_section.dart';
```

---

## Dependencies

**Part 3** (UI Widget) must be merged and available.

No new package dependencies. Uses existing:
- `package:flutter_bloc/flutter_bloc.dart` (already imported in game pages)
- `package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart` (from Part 2)
- `package:very_good_games/nostr/stats/view/leaderboard_section.dart` (from Part 3)
- `package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart` (already available in game pages)
- `package:very_good_games/nostr/stats/repository/community_stats_repository.dart` (already available via context)

---

## Testing Strategy

### Integration Tests

**`test/games/guess_the_number/view/game_page_test.dart`** (extend existing, ~50 LOC)

- [ ] GamePage renders with `LeaderboardCubit` in provider list
- [ ] Results overlay contains `LeaderboardSection` widget
- [ ] LeaderboardSection receives correct `dTag` from overlay
- [ ] Overlay renders without errors (smoke test)

**`test/games/signal/view/signal_page_test.dart`** (extend existing, ~50 LOC)

- [ ] SignalPage renders with `LeaderboardCubit` in provider list
- [ ] Results overlay contains `LeaderboardSection` widget
- [ ] LeaderboardSection receives correct `dTag` from overlay
- [ ] Overlay renders without errors (smoke test)

**Integration flow test:**
1. Start game
2. Complete game (win/loss)
3. Results overlay appears with leaderboard
4. Verify leaderboard fetches and renders (mock relay if needed)

---

## Implementation Checklist

### Game Pages

- [ ] Add import for `LeaderboardCubit` to `game_page.dart`
- [ ] Add import for `LeaderboardCubit` to `signal_page.dart`
- [ ] Add `BlocProvider` for `LeaderboardCubit` in `GamePage.MultiBlocProvider`
- [ ] Add `BlocProvider` for `LeaderboardCubit` in `SignalPage.MultiBlocProvider`

### Results Overlays

- [ ] Add import for `LeaderboardSection` to `results_overlay.dart`
- [ ] Add import for `LeaderboardSection` to `signal_results_overlay.dart`
- [ ] Add `LeaderboardSection(dTag: dTag)` widget after `CommunityStatsSection()` in `ResultsOverlay`
- [ ] Add `LeaderboardSection(dTag: dTag)` widget after `CommunityStatsSection()` in `SignalResultsOverlay`
- [ ] Verify `dTag` is accessible in both overlays (via state or constructor)
- [ ] Add `dTag` getter to `GameState` if missing
- [ ] Add `dTag` getter to `SignalState` if missing

### Testing

- [ ] Create/extend integration tests for both game pages
- [ ] Smoke tests verify overlay renders without errors
- [ ] Leaderboard widget is present in rendered output
- [ ] Tests pass with mocked relay (empty, delayed, failed responses)

### Code Quality

- [ ] Run `dart fix --apply` and `dart format .`
- [ ] All tests pass
- [ ] No lint errors

---

## File Changes Summary

| File | Change | LOC |
|------|--------|-----|
| `lib/games/guess_the_number/view/game_page.dart` | Add BlocProvider | +5 |
| `lib/games/guess_the_number/view/widgets/results_overlay.dart` | Add LeaderboardSection widget | +1 |
| `lib/games/signal/view/signal_page.dart` | Add BlocProvider | +5 |
| `lib/games/signal/view/widgets/signal_results_overlay.dart` | Add LeaderboardSection widget | +1 |
| `lib/games/guess_the_number/cubit/game_state.dart` | Add dTag getter (if missing) | +2 |
| `lib/games/signal/cubit/signal_state.dart` | Add dTag getter (if missing) | +2 |
| **Test files** | Integration tests | ~100 |

**Total new/modified LOC:** ~16 (production), ~100 (tests)

---

## Success Metrics

- ✅ Both game pages render without errors
- ✅ Results overlay displays with leaderboard section visible
- ✅ Leaderboard section fetches data asynchronously
- ✅ No blocking of overlay render (async loading with placeholder)
- ✅ Both games show same leaderboard widget behavior
- ✅ 100% integration test coverage for both games
- ✅ All lint checks pass

---

## Verification Checklist

Before merging, verify:

1. **Guess the Number game:**
   - [ ] Play a round, win, overlay appears
   - [ ] Leaderboard section visible in overlay
   - [ ] Leaderboard shows top 10 or appropriate fallback message
   - [ ] No crashes or errors in console

2. **Signal game:**
   - [ ] Solve puzzle, overlay appears
   - [ ] Leaderboard section visible in overlay
   - [ ] Leaderboard shows top 10 or appropriate fallback message
   - [ ] No crashes or errors in console

3. **Offline testing:**
   - [ ] Disconnect from relays, complete game
   - [ ] Leaderboard shows "unavailable" message gracefully
   - [ ] Overlay still functional (can close, share, etc.)

4. **Code quality:**
   - [ ] `dart fix --apply` runs with no issues
   - [ ] `dart format .` produces no changes
   - [ ] All tests pass (unit + integration)

---

## Notes for Implementation

- **dTag format:** Use `'game-id:YYYY-MM-DD'` pattern. Leverage existing `dateKey()` helper from core utilities.
- **Ordering:** Add `LeaderboardSection` immediately after `CommunityStatsSection`, before spacing/buttons. This groups related stats content together.
- **No breaking changes:** All game functionality remains intact. Leaderboard is additive to existing overlay.
- **Cubit lifetime:** `LeaderboardCubit` is scoped to page level (destroyed when leaving game), so no memory leaks or stale data concerns.

---

## Final Steps

After this PR is merged:
1. The feature is complete and deployed
2. Monitor relay performance; if queries slow, consider adding session-level caching in a future PR
3. Track user feedback on leaderboard engagement
4. Plan v2 enhancements (NIP-05 aliases, pagination, historical leaderboards) based on usage
