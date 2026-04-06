# Leaderboard Scaling Issues

> **Status**: MVP — these issues will emerge at scale. Document tracks known limitations and potential solutions for future iterations.

## Critical Issues

### 1. Event Query Limit (Hard Cap)

**Problem**: `CommunityStatsRepository.fetchLeaderboard()` queries with `limit: 100`, which caps leaderboard visibility to 100 players maximum.

```dart
filter: Filter(kinds: [30042], dTags: [dTag], limit: 100),
```

**When it breaks**: ~50,000+ daily active players per game. At that volume, the top 10 leaderboard becomes a random sample of the first 100 submitted scores, not the actual top 10.

**Potential solutions**:
- **Dynamic limit**: Calculate expected player count, set limit accordingly (loose coupling to player growth)
- **Pagination**: Implement relay cursor pagination to fetch results in batches (requires relay support, complexity)
- **Server-side aggregation**: Compute leaderboard once per day at game close, store as Nostr event or database record (clean, but requires backend)
- **Relay-specific optimization**: Some relays support complex filters or indexing — investigate custom query patterns

**Effort**: Medium to High (depends on chosen approach)

---

### 2. Caching (Single-Instance Only)

**Problem**: In-memory cache in `CommunityStatsRepository._cache` doesn't persist across app restarts or server instances.

```dart
final _cache = <String, CommunityStats>{};
```

**When it breaks**: 
- Multi-server deployments (web, backend API)
- Long-running background tasks
- Mobile app relies on fresh queries every session

**Potential solutions**:
- **Redis/Memcached**: Shared cache layer across instances
- **Local SQLite cache**: On mobile, persist to device storage with TTL
- **Relay-side caching**: Store result as a Nostr event (kind 31000?), query that instead

**Effort**: Low to Medium

---

### 3. Relay Query Timeout

**Problem**: 5-second timeout may be insufficient for relays querying 10k+ events.

```dart
final events = await response.future.timeout(const Duration(seconds: 5));
```

**When it breaks**: Relay performance degrades under load, timeouts increase. At 50k players, queries become consistently slow.

**Potential solutions**:
- **Progressive timeout**: Increase timeout based on event count estimate
- **Relay selection**: Query multiple relays in parallel, use first successful response
- **Streaming results**: Return partial leaderboard as events arrive, rather than waiting for all

**Effort**: Medium

---

### 4. Real-Time Updates

**Problem**: Leaderboard is fetched once per game session. Scores don't update as players finish playing.

**When it breaks**: Players expect live rankings. "You were #5 when you started, now you're #12" should be visible.

**Potential solutions**:
- **Stream events**: Poll relays every 30s during active play
- **Subscriptions**: Use Nostr subscription filters to receive score updates in real-time
- **WebSocket**: Backend maintains subscription, pushes updates to mobile app

**Effort**: High

---

## Low-Priority Issues

### 5. Tie-Breaking Determinism

Current sort: `score DESC, createdAt ASC`. Works for MVP but could be improved with:
- Secondary sort by pubkey (ensures consistent ordering across queries)
- Rank ties handling (multiple players with same score get same rank)

**Effort**: Low (refinement only)

---

## Action Items

- [ ] Add player count monitoring/telemetry (when do we hit 1k? 10k?)
- [ ] Profile relay query performance with realistic event counts
- [ ] Pick server-side aggregation approach if scaling past 10k players
- [ ] Implement configurable query limit as stopgap
- [ ] Document relay API capabilities (pagination, subscriptions, indexing)

---

## References

- Implementation: `lib/nostr/stats/repository/community_stats_repository.dart`
- Models: `lib/nostr/stats/models/leaderboard.dart`
- Tests: `test/nostr/stats/repository/community_stats_repository_test.dart`
