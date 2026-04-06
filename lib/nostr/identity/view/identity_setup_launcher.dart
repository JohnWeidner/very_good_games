import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/identity/view/identity_explainer_flow.dart';
import 'package:very_good_games/nostr/identity/view/identity_setup_page.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';

/// Launches the identity explainer → setup flow.
///
/// Returns `true` if the user completed identity setup, `false` if
/// they cancelled or dismissed.
class IdentitySetupLauncher {
  /// Launches the full identity setup flow (explainer → key setup).
  ///
  /// Returns `true` if setup was completed and the context is still mounted.
  static Future<bool> launch(BuildContext context) async {
    final proceed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const IdentityExplainerFlow(),
      ),
    );

    if (!(proceed ?? false) || !context.mounted) return false;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => NostrIdentityCubit(
            identityRepository: context.read<NostrIdentityRepository>(),
            deletionRepository: context.read<NostrDeletionRepository>(),
            profileRepository: context.read<NostrProfileRepository>(),
          ),
          child: const IdentitySetupPage(),
        ),
      ),
    );

    return context.mounted;
  }
}
