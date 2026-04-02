import 'package:flutter/material.dart';

/// The settings screen for Very Good Games.
///
/// Provides access to app configuration including Nostr identity management.
class SettingsPage extends StatelessWidget {
  /// Creates a [SettingsPage].
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('Nostr Identity'),
            subtitle: Text('Set up your identity'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
