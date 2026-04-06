---
name: High Score Leaderboard Feature
description: Per-game leaderboards fetched from Nostr, displayed in results overlay, sorted by highest score
type: brainstorm
---

# High Score Leaderboard Feature Brainstorm

## Problem Statement

Currently, players see only aggregate community stats (player count + average score) after completing a game. There's no way to see individual top scores or rank against other players, limiting the competitive and social aspects of the app.

## Solution Overview

Add **per-game leaderboards** showing the top 10 highest scores for each game, fetched from Nostr relay data (where players publicly share results). Display the leaderboard in the game results overlay, alongside existing community stats.

---

## Key Decisions

### 1. Scope: Per-Game Leaderboards
**Decision:** Show separate top 10 lists for each game (Guess the Number, Signal) rather than a global leaderboard.

**Why:** Games have different scoring systems and difficulty curves. A global score mixing both games would be meaningless. Per-game leaderboards are directly comparable.

**How to apply:** Create leaderboard queries filtered by game `d` tag (e.g., `"guess-the-number:2026-04-06"`).

---

### 2. Ranking Metric: Highest Score
**Decision:** Rank players by score (descending), no secondary sort.

**Why:** Score is the primary achievement metric in both games. It's already calculated and published in Nostr events. Ties are acceptable (multiple players with same score show in relay order).

**How to apply:** Sort `leaderboard.entries` by `score` descending; take top 10.

---

### 3. Data Source: Nostr Relays (Public)
**Decision:** Fetch leaderboard data from shared Nostr events (same events that drive community stats).

**Why:** Aligns with the app's Nostr-first social design. No centralized database needed. Players already publish events; we just need to query them.

**How to apply:** Reuse kind 30042 event querying in `CommunityStatsRepository`.

---

### 4. UI Placement: Results Overlay
**Decision:** Display leaderboard below the score breakdown in the game results overlay (where `CommunityStatsSection` currently lives).

**Why:** Results overlay is the natural context — players want to know "how did I do against others?" right after playing. Lightweight, no new screen needed.

**How to apply:** Add `LeaderboardSection` widget to `guess_the_number/view/widgets/results_overlay.dart` and `signal/view/widgets/signal_results_overlay.dart`.

---

### 5. Leaderboard Columns: Rank, Player Name, Score
**Decision:** Show three columns per entry:
- **Rank** (1st, 2nd, 3rd, …, 10th)
- **Player Name** (display alias if available; fallback to truncated npub)
- **Score** (numeric)

No star rating column.

**Why:** Minimalist, readable table. Star rating is derivative of score (already implicit). Rank shows position clearly. Player names should be friendly aliases where possible.

**Note on Aliases:** Alias resolution (NIP-05 or other identity standards) adds complexity. If fetching aliases significantly impacts performance or scope, this can be deferred to a future phase. For v1, if aliases are not available, display truncated npub as fallback.

**How to apply:** Build a `LeaderboardTable` widget with three-column layout. Fetch alias data alongside leaderboard entries where feasible.

---

### 6. Entry Count: Top 10
**Decision:** Display exactly top 10 entries, static list (no pagination or expand/collapse).

**Tie-breaking:** If multiple players have the same score, sort by event creation time (earliest first). This ensures deterministic, reproducible rankings.

**Why:** Balances comprehensiveness (enough to see where you rank) with visual weight (fits in overlay without excessive scrolling). Deterministic ranking is crucial for user experience consistency.

**How to apply:** Query limit = 10; sort by (score DESC, createdAt ASC); render as vertically scrollable list within overlay if needed.

---

### 7. Polish: Four Success Criteria

#### 7a. Fast Loading (Cached/Placeholder)
**Decision:** Show a skeleton or "Loading…" placeholder while fetching. Query relays fresh on each results screen (no app-session caching in v1).

**Why:** Relay queries can take 1–2 seconds. Players shouldn't wait to see their score. Fresh queries ensure leaderboard reflects latest data. 

**Caching concern:** Querying fresh each time may strain relay performance at scale. If this becomes a bottleneck, implement session-level caching in a future phase (e.g., cache for 30s per results screen).

**How to apply:** Use `LeaderboardCubit` with `initial → loading → loaded/unavailable` states; show placeholder in `loading` state. Set relay timeout to 5 seconds.

#### 7b. Graceful Offline Handling
**Decision:** If relays unreachable, show "Leaderboard unavailable" message instead of error.

**Why:** Offline is common; errors are jarring. Silent graceful degradation.

**How to apply:** Catch relay exceptions; emit `unavailable` state; render empty card.

#### 7c. Highlight User's Own Score & Identity Requirement
**Decision:** If the current player is in the top 10, highlight their entry (different background color or border).

If the player has not set up a Nostr identity, display a message on the results screen: "Set up your identity to get ranked on the leaderboard" (with link/button to identity setup).

**Why:** Personal context — "did I make the top 10?" is the first thing players check. Identity setup is required to join the social leaderboard; users should understand this requirement.

**How to apply:** 
- Compare player pubkey (from `NostrIdentityRepository`) to each leaderboard entry; add visual highlight
- Check `NostrIdentityRepository.hasIdentity()` in `LeaderboardSection`; show identity setup message if false

#### 7d. "No Scores Yet" for New Games
**Decision:** Show a friendly message if the leaderboard has zero entries (game just launched).

**Why:** Avoids empty table confusion; encourages first players to participate.

**How to apply:** Check `leaderboard.entries.isEmpty`; render message card instead of table.

---

## Architecture & Implementation Approach

### Chosen: Approach 1 — Extend CommunityStatsRepository

#### Rationale
- Reuses existing relay querying, event parsing, deduplication logic
- Single in-memory cache per `dTag` (game + date)
- Minimal code duplication
- Follows established pattern in codebase

#### New Files
- `lib/nostr/stats/models/leaderboard.dart` — `Leaderboard` model + `LeaderboardEntry` (fields: npub, score, gameId, createdAt)
- `lib/nostr/stats/cubit/leaderboard_cubit.dart` + `lib/nostr/stats/cubit/leaderboard_state.dart` — Bloc/Cubit for leaderboard state + UI updates
- `lib/nostr/sharing/view/leaderboard_section.dart` — Widget for display in results overlay (includes identity setup message if no identity)

#### Modified Files
- `lib/nostr/stats/repository/community_stats_repository.dart` — Add `fetchLeaderboard(dTag, {limit})` method
- `lib/games/guess_the_number/view/widgets/results_overlay.dart` — Add `LeaderboardSection` to results card
- `lib/games/signal/view/widgets/signal_results_overlay.dart` — Add `LeaderboardSection` to results card
- `lib/app/app.dart` — Provide `LeaderboardCubit` in `MultiRepositoryProvider`

#### Data Flow
```
GameResultsOverlay (has dTag)
  ↓
LeaderboardSection (BlocBuilder<LeaderboardCubit>)
  ↓
LeaderboardCubit.fetchLeaderboard(dTag)
  ↓
CommunityStatsRepository.fetchLeaderboard(dTag)
  ↓ (queries relays, parses events, sorts)
Leaderboard(entries: [LeaderboardEntry, …])
  ↓
LeaderboardTable (renders 3-column table + highlights user)
```

---

## Edge Cases & Success Criteria

### Edge Cases Handled
1. **Zero entries** → "No leaderboard yet" message
2. **User not in top 10** → No highlight, table displays normally
3. **User has no identity** → Show identity setup message instead of highlight
4. **Relay timeout (5s)** → "Leaderboard unavailable" (no error UI)
5. **Multiple games with different scoring** → Per-game `d` tags keep them separated
6. **Identical scores** → Sort by event creation time (earliest first) for deterministic ranking

### Success Criteria
- [ ] Leaderboard appears in results overlay on game completion
- [ ] Shows top 10 entries with rank, player name, score
- [ ] User's entry highlighted if in top 10
- [ ] Loads asynchronously without blocking overlay
- [ ] Graceful "unavailable" message when relays offline
- [ ] "No scores yet" message for new games
- [ ] Works for both Guess the Number and Signal games
- [ ] No new dependencies (uses existing `ndk` + `very_good_analysis`)

---

## Constraints & Assumptions

### Constraints
- **Relay availability:** Depends on public Nostr relays staying responsive (5-second timeout)
- **Event format:** Assumes `kind 30042` events with `l:score-*` labels (already published by app)
- **Player identity / Aliases:** Ideally display user-friendly aliases (NIP-05 or other methods) instead of raw npubs. Alias resolution may add complexity:
  - **If feasible in v1:** Include alias fetching alongside leaderboard queries
  - **If too complex:** Defer to future phase; display truncated npub as fallback for v1

### Assumptions
- Players have already played games and published results (non-empty relay data)
- Scoring system is stable (no retroactive changes to ScoreCalculator)
- Date key format (`YYYY-MM-DD`) remains consistent for `d` tag construction

---

## Out of Scope (v1)

- [ ] Global leaderboard across all games
- [ ] Historical leaderboards (previous days)
- [ ] Player profiles or stats history
- [ ] NIP-05 identity aliases
- [ ] Filtering/sorting options (star rating, time, etc.)
- [ ] Pagination beyond top 10

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Relay queries slow results overlay | Load asynchronously with placeholder; don't block render |
| Offline relays break feature | Graceful "unavailable" fallback |
| Player pubkey exposure | npub is already public (Nostr design); no privacy leak |
| Score inflation or spam | Rely on Nostr event verification + deduplication (per pubkey) |

---

## Next Steps

1. **Plan:** Create detailed implementation plan with file breakdown and test strategy
2. **Create Branch:** `feature/leaderboard` or `feature/high-score-table`
3. **Implement:** Models → Repository → Cubit → UI
4. **Test:** Unit tests for cubit, mock relay tests, widget tests for table
5. **Review:** Architecture review + code review before merge
