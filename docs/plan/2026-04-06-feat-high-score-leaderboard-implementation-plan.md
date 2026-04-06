---
title: "feat: High Score Leaderboard Implementation Plan"
date: 2026-04-06
type: implementation
status: ready
---

> **Note:** This plan has been split into 4 independent parts. See the `-part-1` through `-part-4` files in this directory. Each part can be reviewed and merged independently, with clear dependencies documented.

# High Score Leaderboard Implementation Plan

## Overview

Implement per-game leaderboards showing top 10 highest scores fetched from Nostr relays. Display in game results overlays with player identity awareness, graceful offline handling, and async loading with visual feedback.

**Related brainstorm:** [2026-04-06-high-score-leaderboard-brainstorm-doc.md](../../brainstorm/2026-04-06-high-score-leaderboard-brainstorm-doc.md)

---

## Problem & Motivation

Currently, players see only aggregate community stats (player count + average score) after games. No way to see individual top scores or rank competitively, limiting social engagement.

**Success metric:** Players can see how their score ranks against the top 10 for each daily game.

---

## Scope & Acceptance Criteria

### Must Have

- [ ] Leaderboard appears in results overlay after game completion
- [ ] Shows exactly top 10 entries (rank, player name, score)
- [ ] Data fetched from Nostr relay kind 30042 events (same as community stats)
- [ ] Deterministic ranking: sort by score DESC, then event creation time ASC (tie-breaking)
- [ ] Loads asynchronously without blocking overlay render
- [ ] User's entry highlighted if in top 10 and identity is set up
- [ ] Identity requirement message if user has no identity
- [ ] Works for both Guess the Number and Signal games
- [ ] Graceful "unavailable" message when relays offline (no error UI)
- [ ] "No scores yet" message for games with zero leaderboard entries

### Nice to Have

- [ ] Player names (aliases) instead of raw npubs (deferred to future if too complex)
- [ ] Visual polish: skeleton loader or animated placeholder

### Out of Scope

- [ ] Global leaderboard across games
- [ ] Historical leaderboards (previous days)
- [ ] Filtering, sorting, or pagination options
- [ ] NIP-05 identity resolution (v1)

---

## Technical Architecture

### Data Flow

```
GamePage (has dTag)
  ├─ creates LeaderboardCubit via BlocProvider
  └─ ResultsOverlay (Guess the Number)
      └─ LeaderboardSection (BlocBuilder<LeaderboardCubit>)
          └─ LeaderboardTable (renders 3-column table)

Similarly for Signal game at SignalPage → SignalResultsOverlay → LeaderboardSection
```

### New Models & Types

#### `lib/nostr/stats/models/leaderboard.dart`

```dart
// Immutable model for a single leaderboard entry
class LeaderboardEntry extends Equatable {
  final String npub;           // User's public key (bech32)
  final int score;             // Score value
  final String? alias;         // Display name (future: NIP-05 resolved)
  final int rank;              // 1-10
  final int createdAt;         // Nostr event timestamp (for deterministic sorting)
  
  String get displayName => alias ?? _truncateNpub(npub);
  static String _truncateNpub(String npub) => '${npub.substring(0, 8)}...';
}

// Container for leaderboard results
class Leaderboard extends Equatable {
  final String dTag;           // Date + game ID (e.g., 'guess-the-number:2026-04-06')
  final List<LeaderboardEntry> entries;  // Top 10, sorted
  
  bool get isEmpty => entries.isEmpty;
  bool containsUser(String userPubKey) => 
    entries.any((e) => e.npub == userPubKey);
  LeaderboardEntry? findUserEntry(String userPubKey) =>
    entries.firstWhereOrNull((e) => e.npub == userPubKey);
}
```

### Repository Extension

#### `lib/nostr/stats/repository/community_stats_repository.dart` (extend)

Add method:

```dart
/// Fetches the top [limit] leaderboard entries for [dTag], sorted by score DESC
/// then createdAt ASC (deterministic tie-breaking).
///
/// Returns null if no events found or relays unavailable.
Future<Leaderboard?> fetchLeaderboard(
  String dTag, {
  int limit = 10,
}) async {
  try {
    // Reuse same query pattern as fetchStats
    final response = _ndkProvider.ndk.requests.query(
      filter: Filter(kinds: [30042], dTags: [dTag], limit: 100),
      explicitRelays: defaultRelayUrls,
      cacheRead: false,
      cacheWrite: false,
    );

    final events = await response.future.timeout(const Duration(seconds: 5));

    if (events.isEmpty) return null;

    // Deduplicate by pubkey (keep latest)
    final byPubkey = <String, Nip01Event>{};
    for (final event in events) {
      final existing = byPubkey[event.pubKey];
      if (existing == null || event.createdAt > existing.createdAt) {
        byPubkey[event.pubKey] = event;
      }
    }

    // Extract scores, build entries
    final entries = <LeaderboardEntry>[];
    for (final event in byPubkey.values) {
      final score = _extractScore(event);
      if (score != null) {
        entries.add(LeaderboardEntry(
          npub: Nip19.encodePubKey(event.pubKey),
          score: score,
          createdAt: event.createdAt,
          rank: 0, // Set after sorting
        ));
      }
    }

    if (entries.isEmpty) return null;

    // Sort: score DESC, then createdAt ASC
    entries.sort((a, b) {
      final scoreComp = b.score.compareTo(a.score);
      if (scoreComp != 0) return scoreComp;
      return a.createdAt.compareTo(b.createdAt);
    });

    // Take top N and assign ranks
    final top = entries.take(limit).toList();
    for (var i = 0; i < top.length; i++) {
      top[i] = top[i].copyWith(rank: i + 1);
    }

    return Leaderboard(dTag: dTag, entries: top);
  } on Exception {
    return null;
  }
}
```

### State Management

#### `lib/nostr/stats/cubit/leaderboard_cubit.dart` + `leaderboard_state.dart`

```dart
// State enum
enum LeaderboardStatus { initial, loading, loaded, unavailable }

// State class (using part-of pattern per CLAUDE.md conventions)
class LeaderboardState extends Equatable {
  const LeaderboardState({
    this.status = LeaderboardStatus.initial,
    this.leaderboard,
  });

  final LeaderboardStatus status;
  final Leaderboard? leaderboard;

  LeaderboardState copyWith({
    LeaderboardStatus? status,
    Leaderboard? leaderboard,
  }) {
    return LeaderboardState(
      status: status ?? this.status,
      leaderboard: leaderboard ?? this.leaderboard,
    );
  }

  @override
  List<Object?> get props => [status, leaderboard];
}

// Cubit
class LeaderboardCubit extends Cubit<LeaderboardState> {
  LeaderboardCubit({required CommunityStatsRepository statsRepository})
    : _statsRepository = statsRepository,
      super(const LeaderboardState());

  final CommunityStatsRepository _statsRepository;

  /// Fetches leaderboard for [dTag].
  Future<void> fetchLeaderboard(String dTag) async {
    emit(state.copyWith(status: LeaderboardStatus.loading));

    final leaderboard = await _statsRepository.fetchLeaderboard(dTag);
    if (leaderboard != null) {
      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        leaderboard: leaderboard,
      ));
    } else {
      emit(const LeaderboardState(status: LeaderboardStatus.unavailable));
    }
  }
}
```

### UI Widget

#### `lib/nostr/sharing/view/leaderboard_section.dart`

```dart
/// Displays top 10 leaderboard entries for a daily game.
/// 
/// Wraps [BlocBuilder<LeaderboardCubit>] and shows:
/// - Identity setup message if user has no Nostr identity
/// - Loading skeleton while fetching
/// - Leaderboard table with rank, player name, score
/// - User's entry highlighted if in top 10
/// - "No scores yet" message if empty
/// - "Unavailable" message if relays offline
///
/// Caller must provide [dTag] (game ID + date) and optionally [userPubKey].
class LeaderboardSection extends StatelessWidget {
  const LeaderboardSection({
    required this.dTag,
    this.userPubKey,
    super.key,
  });

  /// Game ID and date tag (e.g., 'guess-the-number:2026-04-06')
  final String dTag;

  /// Current user's public key (hex) for highlighting. If null, cubit will fetch from repository.
  final String? userPubKey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        // Check identity setup on first load
        if (state.status == LeaderboardStatus.initial) {
          _checkAndFetchLeaderboard(context);
        }

        // Show identity setup message if needed
        if (state.status != LeaderboardStatus.loading &&
            state.status != LeaderboardStatus.loaded) {
          return _IdentitySetupPrompt();
        }

        // Loading state
        if (state.status == LeaderboardStatus.loading) {
          return _LeaderboardSkeleton();
        }

        // Loaded state
        if (state.status == LeaderboardStatus.loaded &&
            state.leaderboard != null) {
          final leaderboard = state.leaderboard!;

          if (leaderboard.isEmpty) {
            return _NoScoresYetMessage();
          }

          return _LeaderboardTable(
            leaderboard: leaderboard,
            userPubKey: userPubKey,
          );
        }

        // Unavailable state
        return _UnavailableMessage();
      },
    );
  }

  void _checkAndFetchLeaderboard(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      // Check if user has identity; if not, skip fetching
      final identityRepo = context.read<NostrIdentityRepository>();
      final hasIdentity = await identityRepo.hasIdentity();

      if (context.mounted) {
        context.read<LeaderboardCubit>().fetchLeaderboard(dTag);
      }
    });
  }
}

// Helper widgets
class _IdentitySetupPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set up your identity to get ranked on the leaderboard',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    IdentitySetupLauncher.launch(context),
                child: const Text('Set Up Identity'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Loading leaderboard...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTable extends StatelessWidget {
  const _LeaderboardTable({
    required this.leaderboard,
    this.userPubKey,
  });

  final Leaderboard leaderboard;
  final String? userPubKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1),  // Rank
          1: FlexColumnWidth(3),  // Player
          2: FlexColumnWidth(1),  // Score
        },
        children: [
          // Header row
          TableRow(
            children: [
              _TableCell('Rank', isHeader: true),
              _TableCell('Player', isHeader: true),
              _TableCell('Score', isHeader: true),
            ],
          ),
          // Data rows
          for (final entry in leaderboard.entries)
            TableRow(
              decoration: BoxDecoration(
                color: userPubKey != null &&
                        Nip19.decodePubKey(entry.npub) == userPubKey
                    ? theme.colorScheme.primaryContainer
                    : null,
              ),
              children: [
                _TableCell('${entry.rank}'),
                _TableCell(entry.displayName),
                _TableCell('${entry.score}'),
              ],
            ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text, {this.isHeader = false});

  final String text;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: isHeader
            ? theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)
            : theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _NoScoresYetMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'No scores yet — be the first!',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.6),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _UnavailableMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'Leaderboard unavailable',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.6),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
```

### Integration Points

#### 1. Results Overlays

Add `LeaderboardSection` to both:

**`lib/games/guess_the_number/view/widgets/results_overlay.dart`** (after `CommunityStatsSection`):
```dart
const LeaderboardSection(dTag: dTag),  // dTag is from state
```

**`lib/games/signal/view/widgets/signal_results_overlay.dart`** (after `CommunityStatsSection`):
```dart
const LeaderboardSection(dTag: dTag),  // dTag is from state
```

#### 2. Game Pages

Provide `LeaderboardCubit` at page level (both games):

**`lib/games/guess_the_number/view/game_page.dart`** (in `MultiBlocProvider`):
```dart
BlocProvider(
  create: (context) => LeaderboardCubit(
    statsRepository: context.read<CommunityStatsRepository>(),
  ),
),
```

**`lib/games/signal/view/signal_page.dart`** (in `MultiBlocProvider`):
```dart
BlocProvider(
  create: (context) => LeaderboardCubit(
    statsRepository: context.read<CommunityStatsRepository>(),
  ),
),
```

#### 3. Barrel Files

Update barrel exports:

- `lib/nostr/stats/models/` → add `leaderboard.dart`
- `lib/nostr/stats/cubit/` → add `leaderboard_cubit.dart`
- `lib/nostr/sharing/view/` → add `leaderboard_section.dart`

---

## Testing Strategy

### Unit Tests: Models

**`test/nostr/stats/models/leaderboard_test.dart`**

- [ ] `LeaderboardEntry.displayName` returns alias if available, truncated npub otherwise
- [ ] `Leaderboard.isEmpty` returns true/false correctly
- [ ] `Leaderboard.containsUser()` finds user by pubkey
- [ ] Equatable equality works for both models

### Unit Tests: Repository

**`test/nostr/stats/repository/community_stats_repository_test.dart`** (extend existing)

- [ ] `fetchLeaderboard()` returns top 10 entries sorted by score DESC
- [ ] Tie-breaking: identical scores sorted by createdAt ASC
- [ ] Deduplication: keeps latest event per pubkey
- [ ] Rank assignment: assigns 1-10
- [ ] Empty results: returns null
- [ ] Timeout (5s): returns null gracefully
- [ ] Exception handling: returns null on any error
- [ ] Cache: does NOT cache leaderboard (fresh query each time)

Use `mocktail` for mocking `NdkProvider` and relay responses.

### Cubit Tests

**`test/nostr/stats/cubit/leaderboard_cubit_test.dart`**

- [ ] Initial state: `initial` status, no leaderboard
- [ ] `fetchLeaderboard()` emits `loading` → `loaded` with data
- [ ] `fetchLeaderboard()` emits `loading` → `unavailable` on null result
- [ ] State copyWith works correctly

Use `bloc_test` for cubit testing.

### Widget Tests

**`test/nostr/sharing/view/leaderboard_section_test.dart`**

- [ ] Shows identity setup prompt if user has no identity
- [ ] Fetches leaderboard on first build (postFrameCallback)
- [ ] Shows loading skeleton while status=loading
- [ ] Shows "No scores yet" when leaderboard.isEmpty
- [ ] Shows "Unavailable" when status=unavailable
- [ ] Renders leaderboard table with correct columns (rank, player, score)
- [ ] Highlights user's row if in top 10 and pubkey provided
- [ ] Displays truncated npub when no alias available

Use `flutter_test` with `MockBuildContext` and `BlocBuilder` mocking.

---

## Dependencies & Risk Mitigation

### No New Dependencies

Uses existing: `ndk`, `flutter_bloc`, `equatable`.

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Relay queries slow overlay | Load asynchronously with placeholder; don't block render |
| Offline relays break feature | Graceful "unavailable" fallback; no error UI |
| Player pubkey exposure | npub already public (Nostr design); no privacy leak |
| Incorrect tie-breaking | Sort by (score DESC, createdAt ASC) in repository; test thoroughly |
| Missing dTag in results overlay | Ensure GameState/SignalState have dTag accessible; verify at integration |

---

## Success Metrics

- ✅ Leaderboard fetches in <2s (5s timeout provides safety margin)
- ✅ No visual delays to overlay appearance (async loading)
- ✅ 0 crashes from relay failures (all exceptions caught, state="unavailable")
- ✅ User's entry highlights correctly when in top 10
- ✅ Works for both Guess the Number and Signal without duplication
- ✅ All unit + widget tests pass
- ✅ Code follows VGV conventions (barrel files, part-of states, immutable models)

---

## Implementation Order

1. **Models** → LeaderboardEntry, Leaderboard
2. **Repository** → CommunityStatsRepository.fetchLeaderboard()
3. **State Management** → LeaderboardCubit + LeaderboardState
4. **UI** → LeaderboardSection widget + helper widgets
5. **Integration** → Add to overlays + provide cubits in game pages
6. **Testing** → Unit tests + widget tests
7. **Polish** → Barrel exports, docs, formatting

---

## Files to Create

- [ ] `lib/nostr/stats/models/leaderboard.dart` — Models (200 LOC)
- [ ] `lib/nostr/stats/cubit/leaderboard_cubit.dart` — Cubit + state (80 LOC)
- [ ] `lib/nostr/sharing/view/leaderboard_section.dart` — UI widget (400 LOC)

## Files to Modify

- [ ] `lib/nostr/stats/repository/community_stats_repository.dart` — Add fetchLeaderboard() (~70 LOC)
- [ ] `lib/games/guess_the_number/view/widgets/results_overlay.dart` — Add LeaderboardSection (1 line)
- [ ] `lib/games/signal/view/widgets/signal_results_overlay.dart` — Add LeaderboardSection (1 line)
- [ ] `lib/games/guess_the_number/view/game_page.dart` — Provide LeaderboardCubit (5 lines)
- [ ] `lib/games/signal/view/signal_page.dart` — Provide LeaderboardCubit (5 lines)
- [ ] Barrel files (3 files, 1 line each)

## Test Files to Create

- [ ] `test/nostr/stats/models/leaderboard_test.dart` (~100 LOC)
- [ ] `test/nostr/stats/repository/community_stats_repository_test.dart` (extend, ~150 LOC for leaderboard tests)
- [ ] `test/nostr/stats/cubit/leaderboard_cubit_test.dart` (~80 LOC)
- [ ] `test/nostr/sharing/view/leaderboard_section_test.dart` (~200 LOC)

---

## Assumptions & Constraints

### Assumptions

- `GameState` and `SignalState` have `dTag` field accessible to overlay
- Nostr events use kind 30042 with score extraction logic already proven
- Date key format (`YYYY-MM-DD`) is stable
- Relay timeout of 5 seconds is acceptable for user experience

### Constraints

- Must not introduce new package dependencies
- Must follow VGV conventions: equatable models, part-of states, barrel files
- Relay availability is best-effort; graceful degradation required

---

## Future Extensions (Out of Scope v1)

- NIP-05 alias resolution with caching
- Global leaderboards (cross-game)
- Historical leaderboards (weekly, monthly)
- Pagination or expand-all in overlay
- Player profiles from Nostr
