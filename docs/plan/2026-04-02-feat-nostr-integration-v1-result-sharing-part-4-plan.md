---
title: "feat: add community stats on results overlay"
type: feat
date: 2026-04-02
---

## feat: add community stats on results overlay

## Overview

Add aggregate community stats (player count and average stars) to the results overlay. Stats are fetched from Nostr relays without requiring user identity (public relay reads), displayed asynchronously, and hidden silently on failure. A `CommunityStatsRepository` wraps `Ndk` relay queries for testability.

## Problem Statement / Motivation

Players complete daily puzzles in isolation. Showing community stats ("~25 players, ~2.5 avg stars") on the results overlay creates a sense of shared experience and motivates engagement -- even before a user sets up a Nostr identity or shares their own result.

## Proposed Solution

### New Files

```
lib/
  nostr/
    stats/
      stats.dart                        # Barrel file
      cubit/
        community_stats_cubit.dart
        community_stats_state.dart
      repository/
        community_stats_repository.dart  # Wraps Ndk relay read operations
      models/
        community_stats.dart             # Simple data class (playerCount, avgStars)
```

### Changes to Existing Files

| File | Change |
|---|---|
| `lib/games/guess_the_number/view/widgets/results_overlay.dart` | Add stats display section (both win and loss overlays) |
| `lib/games/guess_the_number/view/game_page.dart` | Provide `CommunityStatsCubit` via `BlocProvider` |
| `lib/app/app.dart` | Provide `CommunityStatsRepository` via `RepositoryProvider` |

### Architecture

**`CommunityStatsRepository`**: Wraps `Ndk` relay read operations. Exposes `fetchStats(String dTag)` which:
1. Queries relays with filter: `kinds: [30042]`, `#d: [dTag]`, `limit: 100`
2. Collects events until EOSE or timeout (5s)
3. Deduplicates by pubkey (keeps latest `created_at` per pubkey)
4. Extracts star count from NIP-32 `l` tags (`stars-{n}` under `games.vgg.score`)
5. Returns `CommunityStats(playerCount, avgStars)` or null on failure

This keeps `CommunityStatsCubit` testable -- mock the repository, not `Ndk`.

**`CommunityStats`**: Simple Equatable data class with `playerCount` (int) and `avgStars` (double).

**`CommunityStatsCubit`**: States: `initial`, `loading`, `loaded(CommunityStats)`, `unavailable`. Triggered when the results overlay mounts. Calls `CommunityStatsRepository.fetchStats()` with the current daily's `d` tag.

**Session caching**: `CommunityStatsRepository` caches results in memory keyed by `d` tag. Past days' results are immutable and cached aggressively. Current day's results are cached for the session (no TTL -- refresh on next app launch).

### Stats Display

- Renders below the score breakdown (win) or below "Score reached zero" (loss)
- Shows: "~{playerCount} players, ~{avgStars} avg stars"
- Uses "~" prefix for approximate language
- Renders asynchronously: overlay appears immediately, stats section fades in when data arrives
- Reserved space collapses if fetch fails or returns 0 results (no layout shift, no error message)

### Performance

- **Lazy**: Relay connection opened only when stats are fetched, not at app startup
- **Capped**: `limit: 100` caps data transfer at ~50-100KB
- **Cached**: In-memory cache avoids re-querying for previously viewed days

## Acceptance Criteria

### Stats Repository
- [ ] `fetchStats()` queries relays with correct filter (kind 30042, matching `d` tag, limit 100)
- [ ] Deduplicates events by pubkey, keeps latest `created_at`
- [ ] Extracts star count from NIP-32 labels correctly
- [ ] Returns `CommunityStats` with accurate player count and average stars
- [ ] Returns null on fetch failure or timeout (5s)
- [ ] Caches results in memory by `d` tag
- [ ] Full unit test coverage (mock `Ndk`)

### Stats Cubit
- [ ] Emits correct state transitions: initial -> loading -> loaded/unavailable
- [ ] Triggers fetch on initialization with correct `d` tag
- [ ] Depends on `CommunityStatsRepository`, not `Ndk` directly
- [ ] Full unit test coverage with `bloc_test`

### Stats Data Model
- [ ] `CommunityStats` is Equatable with `playerCount` and `avgStars` fields

### Results Overlay
- [ ] Stats section visible on both win and loss overlays
- [ ] Stats display uses approximate language ("~25 players", "~2.5 avg stars")
- [ ] Stats render asynchronously -- overlay appears immediately, stats fade in
- [ ] No stats section shown when fetch fails or returns 0 results (no error, no empty state)
- [ ] Widget tests for: loading state, loaded state, unavailable state (hidden)

## Dependencies

- **PR 2** must merge first (provides `Ndk` instance and relay config)
- Independent of PR 3 (result sharing)

## References

- Results overlay: `lib/games/guess_the_number/view/widgets/results_overlay.dart`
- Game page: `lib/games/guess_the_number/view/game_page.dart`
- Daily seed (for `d` tag date): `lib/core/daily_seed/daily_seed.dart`
- Relay config: `lib/nostr/relay/relay_config.dart` (from PR 2)
- Parent plan: `docs/plan/2026-04-02-feat-nostr-integration-v1-result-sharing-plan.md`
