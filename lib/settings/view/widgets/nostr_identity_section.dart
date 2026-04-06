import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/identity/view/identity_setup_launcher.dart';

/// Settings section for managing Nostr identity.
///
/// Shows different content based on identity state:
/// - No identity: setup prompt with button to start explainer flow
/// - Has identity: npub display with copy, import, and delete options
class NostrIdentitySection extends StatelessWidget {
  /// Creates a [NostrIdentitySection].
  const NostrIdentitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NostrIdentityCubit, NostrIdentityState>(
      builder: (context, state) {
        return switch (state.status) {
          NostrIdentityStatus.none => _NoIdentityView(
            onSetup: () => _startExplainerFlow(context),
          ),
          NostrIdentityStatus.loading => const ListTile(
            title: Text('Nostr Identity'),
            trailing: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          NostrIdentityStatus.ready => _HasIdentityView(
            npub: state.npub!,
            onImport: () => _startExplainerFlow(context),
            onDelete: () => _showDeleteDialog(context),
          ),
          NostrIdentityStatus.error => _NoIdentityView(
            onSetup: () => _startExplainerFlow(context),
          ),
        };
      },
    );
  }

  Future<void> _startExplainerFlow(BuildContext context) async {
    final completed = await IdentitySetupLauncher.launch(context);
    if (completed) {
      await context.read<NostrIdentityCubit>().loadIdentity();
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Identity'),
        content: const Text(
          "We'll try to delete your published results from relays. "
          'This cannot be guaranteed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showDeletionProgress(context);
              context.read<NostrIdentityCubit>().deleteIdentity();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeletionProgress(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocConsumer<NostrIdentityCubit, NostrIdentityState>(
        bloc: context.read<NostrIdentityCubit>(),
        listenWhen: (previous, current) =>
            current.status != NostrIdentityStatus.loading,
        listener: (dialogContext, state) {
          Navigator.of(dialogContext).pop();
        },
        builder: (_, state) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(state.deletionProgress ?? 'Deleting identity...'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoIdentityView extends StatelessWidget {
  const _NoIdentityView({required this.onSetup});

  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Nostr Identity'),
      subtitle: const Text('Set up your identity'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onSetup,
    );
  }
}

class _HasIdentityView extends StatelessWidget {
  const _HasIdentityView({
    required this.npub,
    required this.onImport,
    required this.onDelete,
  });

  final String npub;
  final VoidCallback onImport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Nostr Identity'),
          subtitle: Text(npub, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: npub));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('npub copied to clipboard')),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              TextButton(
                onPressed: onImport,
                child: const Text('Import different key'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onDelete,
                child: const Text('Delete identity'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
