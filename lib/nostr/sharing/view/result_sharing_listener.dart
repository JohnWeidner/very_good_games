import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/nostr/identity/view/identity_setup_launcher.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';

/// Listens to [ResultSharingCubit] state changes and shows appropriate
/// feedback (snackbars, identity setup flow).
///
/// Shared across all game results overlays.
class ResultSharingListener extends StatelessWidget {
  /// Creates a [ResultSharingListener].
  const ResultSharingListener({required this.child, super.key});

  /// The child widget to wrap.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ResultSharingCubit, ResultSharingState>(
      listener: (context, sharingState) {
        if (sharingState.status == ResultSharingStatus.checkingIdentity) {
          _launchIdentitySetup(context);
        } else if (sharingState.status == ResultSharingStatus.success) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Result shared! Remember to back up your key '
                  'in Settings.',
                ),
              ),
            );
        } else if (sharingState.status == ResultSharingStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                sharingState.errorMessage ?? 'Could not share your result.',
              ),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => context.read<ResultSharingCubit>().publish(),
              ),
            ),
          );
        }
      },
      child: child,
    );
  }

  Future<void> _launchIdentitySetup(BuildContext context) async {
    final completed = await IdentitySetupLauncher.launch(context);
    if (completed) {
      await context.read<ResultSharingCubit>().publish();
    }
  }
}
