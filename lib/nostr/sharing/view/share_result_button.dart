import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';

/// A button that shares game results to Nostr.
///
/// Shows loading/success/failure states via [ResultSharingCubit].
/// The [onShare] callback should call `ResultSharingCubit.share()` with
/// the appropriate event builder.
class ShareResultButton extends StatelessWidget {
  /// Creates a [ShareResultButton].
  const ShareResultButton({required this.onShare, super.key});

  /// Called when the user taps "Share to Nostr".
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResultSharingCubit, ResultSharingState>(
      builder: (context, sharingState) {
        return switch (sharingState.status) {
          ResultSharingStatus.success => FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check),
            label: const Text('Shared'),
          ),
          ResultSharingStatus.publishing ||
          ResultSharingStatus.checkingIdentity => FilledButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: const Text('Sharing...'),
          ),
          _ => FilledButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share),
            label: const Text('Share to Nostr'),
          ),
        };
      },
    );
  }
}
