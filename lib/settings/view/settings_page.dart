import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/profile/profile.dart';
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => NostrIdentityCubit(
            identityRepository: context.read<NostrIdentityRepository>(),
            deletionRepository: context.read<NostrDeletionRepository>(),
            profileRepository: context.read<NostrProfileRepository>(),
          )..loadIdentity(),
        ),
        BlocProvider(
          create: (context) => ProfileCubit(
            profileRepository: context.read<NostrProfileRepository>(),
            identityRepository: context.read<NostrIdentityRepository>(),
          ),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(children: const [NostrIdentitySection()]),
      ),
    );
  }
}
