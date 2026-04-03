import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';

/// Identity setup page with generate and import options.
///
/// Shown after the explainer flow. The user can generate a new key pair
/// or import an existing nsec.
class IdentitySetupPage extends StatefulWidget {
  /// Creates an [IdentitySetupPage].
  const IdentitySetupPage({super.key});

  @override
  State<IdentitySetupPage> createState() => _IdentitySetupPageState();
}

class _IdentitySetupPageState extends State<IdentitySetupPage> {
  final _importController = TextEditingController();
  bool _showImport = false;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Identity')),
      body: BlocConsumer<NostrIdentityCubit, NostrIdentityState>(
        listener: (context, state) {
          if (state.status == NostrIdentityStatus.ready) {
            if (state.nsec != null) {
              _showBackUpKeyDialog(context, state.nsec!);
            } else {
              Navigator.of(context).pop();
            }
          } else if (state.status == NostrIdentityStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'An error occurred'),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state.status == NostrIdentityStatus.loading;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose how to set up your Nostr identity:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => context
                            .read<NostrIdentityCubit>()
                            .generateIdentity(),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Generate New Identity'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => setState(() => _showImport = !_showImport),
                  icon: const Icon(Icons.download),
                  label: const Text('Import Existing Key'),
                ),
                if (_showImport) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _importController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Enter your nsec',
                      hintText: 'nsec1...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            final nsec = _importController.text.trim();
                            if (nsec.isNotEmpty) {
                              context.read<NostrIdentityCubit>().importKey(
                                nsec,
                              );
                            }
                          },
                    child: const Text('Import'),
                  ),
                ],
                if (isLoading) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBackUpKeyDialog(BuildContext context, String nsec) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Your Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This is your private key. Save it somewhere safe — '
              'it cannot be recovered if lost.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              nsec,
              style: Theme.of(
                dialogContext,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: nsec));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('I Saved It'),
          ),
        ],
      ),
    );
  }
}
