import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/identity/view/identity_setup_launcher.dart';
import 'package:very_good_games/nostr/profile/profile.dart';
import 'package:very_good_games/nostr/stats/cubit/contact_list_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';

/// Displays the leaderboard for a daily game.
///
/// Shows global top scores to all users. When the user has a Nostr identity,
/// loads their follows and merges followed users' scores with a follow
/// indicator icon. Tapping a row opens a profile bottom sheet.
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
    context.read<ContactListCubit>().loadFollows();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Fetch profiles when leaderboard loads.
        BlocListener<LeaderboardCubit, LeaderboardState>(
          listenWhen: (prev, curr) =>
              curr.status == LeaderboardStatus.loaded &&
              curr.leaderboard != null &&
              curr.leaderboard!.entries.isNotEmpty,
          listener: (context, state) {
            final pubkeys = state.leaderboard!.entries
                .map((e) => decodePubkeyHex(e.npub))
                .whereType<String>()
                .toList();
            if (pubkeys.isNotEmpty) {
              context.read<ProfileCubit>().fetchProfiles(pubkeys);
            }
          },
        ),
        // Merge followed scores when contact list loads.
        BlocListener<ContactListCubit, ContactListState>(
          listenWhen: (prev, curr) =>
              curr.status == ContactListStatus.loaded &&
              curr.followedPubkeys.isNotEmpty,
          listener: (context, state) {
            context.read<LeaderboardCubit>().mergeFollowedScores(
              widget.dTag,
              state.followedPubkeys,
            );
          },
        ),
      ],
      child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
        builder: (context, state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Identity setup prompt (above leaderboard, not a gate).
              if (!state.hasIdentity) const _IdentitySetupPrompt(),

              // Loading state.
              if (state.status == LeaderboardStatus.loading)
                const _LoadingPlaceholder(),

              // Loaded state.
              if (state.status == LeaderboardStatus.loaded &&
                  state.leaderboard != null) ...[
                if (state.leaderboard!.isEmpty)
                  const _NoScoresYetMessage()
                else
                  _LeaderboardList(
                    leaderboard: state.leaderboard!,
                    userPubKeyHex: widget.userPubKeyHex,
                  ),
              ],

              // Unavailable or initial state (only if not loading).
              if (state.status == LeaderboardStatus.unavailable)
                const _UnavailableMessage(),
            ],
          );
        },
      ),
    );
  }
}

// Helper widgets

/// Prompts user to set up Nostr identity (shown above leaderboard).
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

/// Renders the leaderboard as a list with tappable rows.
class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.leaderboard, this.userPubKeyHex});

  final Leaderboard leaderboard;
  final String? userPubKeyHex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userNpub = _encodeUserNpub();

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              // Header row.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        'Rank',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Player',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        'Score',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              // Data rows.
              for (final entry in leaderboard.entries)
                _LeaderboardRow(
                  entry: entry,
                  profileState: profileState,
                  isCurrentUser: userNpub != null && entry.npub == userNpub,
                ),
            ],
          ),
        );
      },
    );
  }

  String? _encodeUserNpub() {
    if (userPubKeyHex == null) return null;
    try {
      return Nip19.encodePubKey(userPubKeyHex!);
    } on Exception {
      return null;
    }
  }
}

/// A single tappable leaderboard row.
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.profileState,
    required this.isCurrentUser,
  });

  final LeaderboardEntry entry;
  final ProfileState profileState;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        final pubkeyHex = decodePubkeyHex(entry.npub);
        if (pubkeyHex != null) {
          ProfileBottomSheet.show(
            context,
            pubkeyHex: pubkeyHex,
            isFollowed: entry.isFollowed,
            isCurrentUser: isCurrentUser,
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentUser ? theme.colorScheme.primaryContainer : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '${entry.rank}',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _resolveDisplayName(),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.isFollowed)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.how_to_reg,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                '${entry.score}',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveDisplayName() {
    final hexKey = decodePubkeyHex(entry.npub);
    if (hexKey != null) {
      final profile = profileState.profiles[hexKey];
      if (profile != null) return profile.displayName;
    }
    return entry.displayName;
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
