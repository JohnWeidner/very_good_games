---
title: "feat: High Score Leaderboard — Part 2: State Management"
date: 2026-04-06
type: implementation
status: ready
---

# High Score Leaderboard — Part 2: State Management

## Overview

Implement `LeaderboardCubit` with `LeaderboardState` to manage async leaderboard fetching, status tracking (initial → loading → loaded/unavailable), and identity awareness without exposing repository logic to the UI layer.

**Part of:** High Score Leaderboard feature

**Dependencies:** Part 1 (models & repository) must be merged first.

---

## Problem & Scope

The UI needs a state container for leaderboard data with loading states and error handling. This PR provides a clean Bloc layer that isolates async work and relay failures from the presentation layer.

### Acceptance Criteria

- [ ] `LeaderboardState` enum with statuses: `initial`, `loading`, `loaded`, `unavailable`
- [ ] `LeaderboardState` class with status, leaderboard, hasIdentity fields
- [ ] Proper Equatable implementation for state equality
- [ ] `LeaderboardCubit.fetchLeaderboard(dTag)` method for async fetching
- [ ] `copyWith()` method for state transitions
- [ ] State file uses `part of` pattern (separate from cubit, per VGV conventions)
- [ ] Graceful error handling: exceptions → `unavailable` status (no throwing)
- [ ] Identity check in cubit (not UI); emits state with `hasIdentity` flag
- [ ] All unit tests pass (state transitions, async behavior)
- [ ] Follows VGV conventions: part-of states, Equatable, proper naming

---

## Technical Architecture

### State Management: `lib/nostr/stats/cubit/leaderboard_cubit.dart`

**Main cubit file:**

```dart
import 'package:bloc/bloc.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';
import 'package:very_good_games/nostr/stats/repository/community_stats_repository.dart';

part 'leaderboard_state.dart';

/// Manages fetching and displaying leaderboard data for a daily game.
///
/// Handles async relay queries, deduplicates by pubkey, and tracks identity
/// setup status. Emits state changes for UI to listen to.
class LeaderboardCubit extends Cubit<LeaderboardState> {
  /// Creates a [LeaderboardCubit].
  LeaderboardCubit({
    required CommunityStatsRepository statsRepository,
    required NostrIdentityRepository identityRepository,
  })  : _statsRepository = statsRepository,
        _identityRepository = identityRepository,
        super(const LeaderboardState());

  final CommunityStatsRepository _statsRepository;
  final NostrIdentityRepository _identityRepository;

  /// Fetches leaderboard for the given [dTag].
  ///
  /// First checks if user has Nostr identity. If not, emits state with
  /// `hasIdentity=false` so UI can show identity setup prompt.
  /// If identity exists, fetches leaderboard from relays and emits loaded state.
  Future<void> fetchLeaderboard(String dTag) async {
    // Check identity first
    final hasIdentity = await _identityRepository.hasIdentity();
    
    if (!hasIdentity) {
      emit(state.copyWith(hasIdentity: false));
      return;
    }

    // Fetch leaderboard
    emit(state.copyWith(status: LeaderboardStatus.loading));

    final leaderboard = await _statsRepository.fetchLeaderboard(dTag);
    if (leaderboard != null) {
      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        leaderboard: leaderboard,
        hasIdentity: true,
      ));
    } else {
      emit(const LeaderboardState(status: LeaderboardStatus.unavailable));
    }
  }
}
```

**State file: `lib/nostr/stats/cubit/leaderboard_state.dart`**

```dart
part of 'leaderboard_cubit.dart';

/// Status of leaderboard fetching.
enum LeaderboardStatus {
  /// Not yet fetched.
  initial,

  /// Fetching from relays.
  loading,

  /// Leaderboard loaded successfully.
  loaded,

  /// Leaderboard unavailable (fetch failed or no data).
  unavailable,
}

/// State for [LeaderboardCubit].
class LeaderboardState extends Equatable {
  /// Creates a [LeaderboardState].
  const LeaderboardState({
    this.status = LeaderboardStatus.initial,
    this.leaderboard,
    this.hasIdentity = true,
  });

  /// Current loading/result status.
  final LeaderboardStatus status;

  /// The loaded leaderboard, available when [status] is [LeaderboardStatus.loaded].
  final Leaderboard? leaderboard;

  /// Whether the user has set up a Nostr identity.
  /// 
  /// When false, UI should prompt for identity setup instead of showing leaderboard.
  final bool hasIdentity;

  /// Creates a copy with optional field overrides.
  LeaderboardState copyWith({
    LeaderboardStatus? status,
    Leaderboard? leaderboard,
    bool? hasIdentity,
  }) {
    return LeaderboardState(
      status: status ?? this.status,
      leaderboard: leaderboard ?? this.leaderboard,
      hasIdentity: hasIdentity ?? this.hasIdentity,
    );
  }

  @override
  List<Object?> get props => [status, leaderboard, hasIdentity];
}
```

---

## Dependencies

**Part 1** (Models & Repository) must be merged and available.

Imports:
- `package:bloc/bloc.dart` (already available)
- `package:very_good_games/nostr/stats/models/leaderboard.dart` (from Part 1)
- `package:very_good_games/nostr/stats/repository/community_stats_repository.dart` (extended in Part 1)
- `package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart` (existing)

---

## Testing Strategy

### Unit Tests: Cubit

**`test/nostr/stats/cubit/leaderboard_cubit_test.dart`** (~80 LOC)

- [ ] Initial state: `initial` status, `hasIdentity=true`, no leaderboard
- [ ] `fetchLeaderboard()` with no identity: emits state with `hasIdentity=false` (no fetch attempt)
- [ ] `fetchLeaderboard()` with identity: emits `loading` → `loaded` with leaderboard data
- [ ] `fetchLeaderboard()` with identity but relay returns null: emits `loading` → `unavailable`
- [ ] State copyWith works: status, leaderboard, hasIdentity all override correctly
- [ ] State equality: two identical states are equal
- [ ] Exception handling: repository exceptions don't throw (caught internally)
- [ ] Multiple calls: calling `fetchLeaderboard()` multiple times works (replaces state)

Use `bloc_test` for cubit testing with mocked `CommunityStatsRepository` and `NostrIdentityRepository` via `mocktail`.

**Mock setup example:**
```dart
class MockCommunityStatsRepository extends Mock
    implements CommunityStatsRepository {}

class MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

group('LeaderboardCubit', () {
  late MockCommunityStatsRepository mockStatsRepo;
  late MockNostrIdentityRepository mockIdentityRepo;

  setUp(() {
    mockStatsRepo = MockCommunityStatsRepository();
    mockIdentityRepo = MockNostrIdentityRepository();
  });

  // Tests here...
});
```

---

## Implementation Checklist

- [ ] Create `lib/nostr/stats/cubit/leaderboard_cubit.dart` with cubit class
- [ ] Create `lib/nostr/stats/cubit/leaderboard_state.dart` with `part of` declaration
- [ ] Import `NostrIdentityRepository` in cubit
- [ ] Add identity check in `fetchLeaderboard()` method
- [ ] `copyWith()` includes `hasIdentity` parameter
- [ ] Create `test/nostr/stats/cubit/leaderboard_cubit_test.dart` with bloc_test tests
- [ ] Update `lib/nostr/stats/cubit/` barrel file to export `leaderboard_cubit.dart`
- [ ] Run `dart fix --apply` and `dart format .`
- [ ] All tests pass

---

## Success Metrics

- ✅ All state transitions work as expected (initial → loading → loaded/unavailable)
- ✅ Identity check prevents fetch when user has no identity
- ✅ 100% unit test coverage for cubit and state
- ✅ No exceptions bubble up from repository
- ✅ Code follows VGV conventions (part-of states, Equatable, copyWith)

---

## Notes for Implementation

- The identity check happens *in the cubit*, not the UI. This keeps the UI layer simpler and ensures identity status is always available in state.
- The `hasIdentity` flag allows the UI to show a setup prompt without needing to call into another repository.
- Multiple calls to `fetchLeaderboard()` replace the previous state, preventing concurrent requests.

---

## Next Steps

Once this PR is merged:
1. Part 3 creates the UI widget (LeaderboardSection) using this cubit
2. Part 4 integrates into game results overlays
