---
title: "feat: High Score Leaderboard — Part 3: UI Widget"
date: 2026-04-06
type: implementation
status: ready
---

# High Score Leaderboard — Part 3: UI Widget

## Overview

Implement `LeaderboardSection` widget with full state-driven rendering: loading skeleton, identity setup prompt, leaderboard table with user highlight, "no scores yet" message, and graceful offline fallback. Self-contained presentation layer that depends on cubit but not on game-specific code.

**Part of:** High Score Leaderboard feature

**Dependencies:** Part 2 (state management) must be merged first.

---

## Problem & Scope

The UI needs to display leaderboard data with clear visual states for loading, identity setup, success, and failure. This PR provides a complete, tested widget that encapsulates all rendering logic.

### Acceptance Criteria

- [ ] `LeaderboardSection` widget accepts `dTag` (required) and `userPubKey` (optional)
- [ ] Shows identity setup prompt if `state.hasIdentity=false`
- [ ] Fetches leaderboard on first build via `WidgetsBinding.addPostFrameCallback()`
- [ ] Shows loading skeleton while `status=loading`
- [ ] Shows "No scores yet" when leaderboard is empty
- [ ] Shows leaderboard table for valid data with 3 columns (rank, player, score)
- [ ] Highlights user's row if present in top 10 (background color)
- [ ] Shows "Leaderboard unavailable" when `status=unavailable`
- [ ] Displays truncated npub as player name (fallback for v1; alias deferred to v2)
- [ ] All widget tests pass (state transitions, UI rendering, user interaction)
- [ ] Follows VGV conventions: stateless widget, BlocBuilder, helper widgets

---

## Technical Architecture

### Main Widget: `lib/nostr/stats/view/leaderboard_section.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/nostr/identity/view/identity_setup_launcher.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';

/// Displays the top 10 leaderboard entries for a daily game.
///
/// Wraps [BlocBuilder<LeaderboardCubit>] and renders different UI based on state:
/// - Identity setup prompt if user has no Nostr identity
/// - Loading skeleton while fetching
/// - Leaderboard table with rank, player name, score
/// - User's entry highlighted if in top 10
/// - "No scores yet" message for empty leaderboards
/// - "Unavailable" message if relays offline
///
/// Call [LeaderboardCubit.fetchLeaderboard(dTag)] manually or provide context
/// where cubit is already instantiated.
class LeaderboardSection extends StatelessWidget {
  /// Creates a [LeaderboardSection].
  const LeaderboardSection({
    required this.dTag,
    this.userPubKeyHex,
    super.key,
  });

  /// Game ID and date tag (e.g., 'guess-the-number:2026-04-06').
  final String dTag;

  /// Current user's public key (hex) for highlighting user's entry.
  /// If null, user's row won't be highlighted.
  final String? userPubKeyHex;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        // Fetch leaderboard on first build
        if (state.status == LeaderboardStatus.initial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.read<LeaderboardCubit>().fetchLeaderboard(dTag);
            }
          });
        }

        // Identity setup required
        if (!state.hasIdentity) {
          return _IdentitySetupPrompt();
        }

        // Loading state
        if (state.status == LeaderboardStatus.loading) {
          return _LoadingPlaceholder();
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
            userPubKeyHex: userPubKeyHex,
          );
        }

        // Unavailable state
        return _UnavailableMessage();
      },
    );
  }
}

// Helper widgets

/// Prompts user to set up Nostr identity to participate in leaderboard.
class _IdentitySetupPrompt extends StatelessWidget {
  const _IdentitySetupPrompt();

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
                onPressed: () => IdentitySetupLauncher.launch(context),
                child: const Text('Set Up Identity'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder shown while fetching leaderboard data.
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'Loading leaderboard...',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Message shown when leaderboard has no entries yet.
class _NoScoresYetMessage extends StatelessWidget {
  const _NoScoresYetMessage();

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

/// Renders the leaderboard table with rank, player, score columns.
class _LeaderboardTable extends StatelessWidget {
  const _LeaderboardTable({
    required this.leaderboard,
    this.userPubKeyHex,
  });

  final Leaderboard leaderboard;
  final String? userPubKeyHex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1),    // Rank
          1: FlexColumnWidth(3),    // Player
          2: FlexColumnWidth(1),    // Score
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
                color: _isUserEntry(entry)
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

  /// Whether the entry belongs to the current user.
  bool _isUserEntry(LeaderboardEntry entry) {
    if (userPubKeyHex == null) return false;
    // Compare hex pubkey against entry's npub (which is bech32 encoded)
    // Decode npub to hex for comparison
    final entryPubKeyHex = Nip19.decodePubKey(entry.npub);
    return entryPubKeyHex == userPubKeyHex;
  }
}

/// Cell in the leaderboard table.
class _TableCell extends StatelessWidget {
  const _TableCell(
    this.text, {
    this.isHeader = false,
  });

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

/// Message shown when leaderboard is unavailable (relay offline).
class _UnavailableMessage extends StatelessWidget {
  const _UnavailableMessage();

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

---

## Dependencies

**Part 2** (State Management) must be merged and available.

Imports:
- `package:flutter/material.dart` (framework)
- `package:flutter_bloc/flutter_bloc.dart` (BlocBuilder)
- `package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart` (from Part 2)
- `package:very_good_games/nostr/stats/models/leaderboard.dart` (from Part 1)
- `package:very_good_games/nostr/identity/view/identity_setup_launcher.dart` (existing)
- `package:ndk/ndk.dart` (Nip19 for pubkey decoding)

---

## Testing Strategy

### Widget Tests

**`test/nostr/stats/view/leaderboard_section_test.dart`** (~200 LOC)

- [ ] Shows identity setup prompt when `state.hasIdentity=false`
- [ ] Identity setup button calls `IdentitySetupLauncher.launch()`
- [ ] Fetches leaderboard on first build (via postFrameCallback)
- [ ] Shows loading placeholder while `status=loading`
- [ ] Shows "No scores yet" when leaderboard.isEmpty
- [ ] Shows "Unavailable" when `status=unavailable`
- [ ] Renders table with correct column headers (Rank, Player, Score)
- [ ] Renders all entries with correct rank, displayName, score
- [ ] Highlights user's row when `userPubKeyHex` matches entry pubkey
- [ ] Does not highlight row when `userPubKeyHex` is null
- [ ] Displays truncated npub when no alias (v1 fallback)
- [ ] Table updates when state changes (new leaderboard emitted)

**Test setup example:**
```dart
testWidgets('LeaderboardSection shows identity prompt when hasIdentity=false',
    (WidgetTester tester) async {
  final mockCubit = MockLeaderboardCubit();
  when(() => mockCubit.state).thenReturn(
    const LeaderboardState(hasIdentity: false),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<LeaderboardCubit>.value(
        value: mockCubit,
        child: const Scaffold(
          body: LeaderboardSection(dTag: 'test:2026-04-06'),
        ),
      ),
    ),
  );

  expect(find.text('Set up your identity to get ranked on the leaderboard'),
      findsOneWidget);
  expect(find.byType(FilledButton), findsOneWidget);
});
```

---

## Implementation Checklist

- [ ] Create `lib/nostr/stats/view/leaderboard_section.dart`
- [ ] Create main `LeaderboardSection` widget class
- [ ] Create helper widgets: `_IdentitySetupPrompt`, `_LoadingPlaceholder`, `_NoScoresYetMessage`, `_LeaderboardTable`, `_TableCell`, `_UnavailableMessage`
- [ ] Implement `_isUserEntry()` logic with pubkey comparison
- [ ] Add postFrameCallback for initial fetch
- [ ] Import Nip19 from ndk for pubkey decoding
- [ ] Create `test/nostr/stats/view/leaderboard_section_test.dart`
- [ ] Widget tests cover all state transitions and rendering paths
- [ ] Update `lib/nostr/stats/view/` barrel file (create if doesn't exist) to export `leaderboard_section.dart`
- [ ] Run `dart fix --apply` and `dart format .`
- [ ] All tests pass

---

## Success Metrics

- ✅ Widget renders all states correctly (identity prompt, loading, loaded, unavailable)
- ✅ User's row highlights when pubkey matches
- ✅ Table displays truncated npub for player names
- ✅ Loading and empty states are user-friendly
- ✅ 100% widget test coverage for all rendering paths
- ✅ Code follows VGV conventions (stateless widget, BlocBuilder, helper widget pattern)

---

## Notes for Implementation

- **Pubkey comparison**: Entry stores `npub` (bech32), but `userPubKeyHex` is hex. Use `Nip19.decodePubKey(npub)` to convert for comparison.
- **Identity setup launcher**: Uses existing `IdentitySetupLauncher.launch(context)` pattern; don't duplicate the flow.
- **Table layout**: `FlexColumnWidth` keeps columns proportional; adjust ratios if design requires different sizing.
- **Loading state**: Simple text placeholder is acceptable for <2s relay queries; no animation needed.

---

## Next Steps

Once this PR is merged:
1. Part 4 integrates this widget into game results overlays
2. Tests both games end-to-end
