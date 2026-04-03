import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';
import 'package:very_good_games/settings/view/widgets/widgets.dart';

/// The settings screen for Very Good Games.
///
/// Provides access to app configuration including Nostr identity management.
class SettingsPage extends StatelessWidget {
  /// Creates a [SettingsPage].
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NostrIdentityCubit(
        identityRepository: context.read<NostrIdentityRepository>(),
        deletionRepository: context.read<NostrDeletionRepository>(),
      )..loadIdentity(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(children: const [NostrIdentitySection()]),
      ),
    );
  }
}
