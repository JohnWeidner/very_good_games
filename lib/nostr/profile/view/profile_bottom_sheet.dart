import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:very_good_games/nostr/profile/cubit/profile_sheet_cubit.dart';

/// Shows a modal bottom sheet displaying a Nostr user's profile.
///
/// Call [show] to open the sheet for a given [pubkeyHex].
class ProfileBottomSheet extends StatelessWidget {
  /// Creates a [ProfileBottomSheet].
  const ProfileBottomSheet({
    required this.pubkeyHex,
    required this.isFollowed,
    required this.isCurrentUser,
    super.key,
  });

  /// Hex-encoded public key of the profile to display.
  final String pubkeyHex;

  /// Whether this user is followed by the current user.
  final bool isFollowed;

  /// Whether this is the current user's own profile.
  final bool isCurrentUser;

  /// Opens the profile bottom sheet.
  static void show(
    BuildContext context, {
    required String pubkeyHex,
    required bool isFollowed,
    required bool isCurrentUser,
  }) {
    final profileRepository = context.read<NostrProfileRepository>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => ProfileSheetCubit(
          profileRepository: profileRepository,
          pubkeyHex: pubkeyHex,
        )..loadProfile(),
        child: ProfileBottomSheet(
          pubkeyHex: pubkeyHex,
          isFollowed: isFollowed,
          isCurrentUser: isCurrentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return BlocBuilder<ProfileSheetCubit, ProfileSheetState>(
          builder: (context, state) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle.
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (state.status == ProfileSheetStatus.loading)
                      _LoadingPlaceholder(pubkeyHex: pubkeyHex)
                    else
                      _ProfileContent(
                        pubkeyHex: pubkeyHex,
                        profile: state.profile,
                        isFollowed: isFollowed,
                        isCurrentUser: isCurrentUser,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder({required this.pubkeyHex});

  final String pubkeyHex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.person,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 120,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 14,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 180,
          height: 14,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.pubkeyHex,
    required this.profile,
    required this.isFollowed,
    required this.isCurrentUser,
  });

  final String pubkeyHex;
  final NostrProfile? profile;
  final bool isFollowed;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName =
        profile?.displayName ?? NostrProfile(pubkey: pubkeyHex).displayName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar.
        CircleAvatar(
          radius: 40,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          backgroundImage: profile?.picture != null
              ? NetworkImage(profile!.picture!)
              : null,
          onBackgroundImageError: profile?.picture != null
              ? (_, __) {} // Fallback handled by child.
              : null,
          child: profile?.picture == null
              ? Icon(
                  Icons.person,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        const SizedBox(height: 12),

        // Name.
        Text(
          displayName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Following badge.
        if (isFollowed && !isCurrentUser)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Chip(
              avatar: Icon(Icons.how_to_reg, size: 16),
              label: Text('Following'),
              visualDensity: VisualDensity.compact,
            ),
          ),

        // About.
        if (profile?.about != null && profile!.about!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              profile!.about!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),

        // NIP-05.
        if (profile?.nip05 != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    profile!.nip05!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Lightning address.
        if (profile?.lud16 != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    profile!.lud16!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // View on Nostr button.
        OutlinedButton.icon(
          onPressed: () => _openOnNostr(pubkeyHex),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('View on Nostr'),
        ),

        const SizedBox(height: 12),

        // Updated ago + refresh.
        _UpdatedRow(profile: profile),
      ],
    );
  }

  Future<void> _openOnNostr(String pubkeyHex) async {
    final npub = Nip19.encodePubKey(pubkeyHex);
    final uri = Uri.parse('https://njump.me/$npub');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _UpdatedRow extends StatelessWidget {
  const _UpdatedRow({required this.profile});

  final NostrProfile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastFetched = profile?.lastFetchedAt;
    final timeAgo = lastFetched != null ? _formatTimeAgo(lastFetched) : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (timeAgo != null)
          Text(
            'Updated $timeAgo',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          visualDensity: VisualDensity.compact,
          tooltip: 'Refresh profile',
          onPressed: () => context.read<ProfileSheetCubit>().refreshProfile(),
        ),
      ],
    );
  }

  static String _formatTimeAgo(int unixSeconds) {
    final fetchedAt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final diff = DateTime.now().toUtc().difference(fetchedAt);

    if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'}'
          ' ago';
    }
    return 'just now';
  }
}
