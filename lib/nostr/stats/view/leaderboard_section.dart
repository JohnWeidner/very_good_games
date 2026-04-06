import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/identity/view/identity_setup_launcher.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';

/// Displays the top 10 leaderboard entries for a daily game.
///
/// Fetches leaderboard on first build via [initState], then renders
/// different UI based on cubit state: identity setup prompt, loading
/// skeleton, leaderboard table with user highlight, "no scores yet"
/// message, or "unavailable" fallback.
class LeaderboardSection extends StatefulWidget {
  /// Creates a [LeaderboardSection].
  const LeaderboardSection({required this.dTag, this.userPubKeyHex, super.key});

  /// Game ID and date tag (e.g., 'guess-the-number:2026-04-06').
  final String dTag;

  /// Current user's public key (hex) for highlighting user's entry.
  /// If null, user's row won't be highlighted.
  final String? userPubKeyHex;

  @override
  State<LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<LeaderboardSection> {
  @override
  void initState() {
    super.initState();
    context.read<LeaderboardCubit>().fetchLeaderboard(widget.dTag);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        // Identity setup required
        if (!state.hasIdentity) {
          return const _IdentitySetupPrompt();
        }

        // Loading state
        if (state.status == LeaderboardStatus.loading) {
          return const _LoadingPlaceholder();
        }

        // Loaded state
        if (state.status == LeaderboardStatus.loaded &&
            state.leaderboard != null) {
          final leaderboard = state.leaderboard!;

          if (leaderboard.isEmpty) {
            return const _NoScoresYetMessage();
          }

          return _LeaderboardTable(
            leaderboard: leaderboard,
            userPubKeyHex: widget.userPubKeyHex,
          );
        }

        // Unavailable or initial state
        return const _UnavailableMessage();
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Renders the leaderboard table with rank, player, score columns.
class _LeaderboardTable extends StatelessWidget {
  const _LeaderboardTable({required this.leaderboard, this.userPubKeyHex});

  final Leaderboard leaderboard;
  final String? userPubKeyHex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Encode user's hex pubkey to npub once for comparison.
    final userNpub = _encodeUserNpub();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(), // Rank
          1: FlexColumnWidth(3), // Player
          2: FlexColumnWidth(), // Score
        },
        children: [
          // Header row
          const TableRow(
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
                color: userNpub != null && entry.npub == userNpub
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

  /// Encodes [userPubKeyHex] to npub for string comparison.
  /// Returns null if no user key or encoding fails.
  String? _encodeUserNpub() {
    if (userPubKeyHex == null) return null;
    try {
      return Nip19.encodePubKey(userPubKeyHex!);
    } on Exception {
      return null;
    }
  }
}

/// Cell in the leaderboard table.
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
