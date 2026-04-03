import 'package:flutter/material.dart';

/// Full-screen modal onboarding flow explaining Nostr identity.
///
/// Shown before first identity creation. Consists of 2 screens:
/// 1. "What is Nostr?" — decentralized protocol overview
/// 2. "Your Key Pair" — public/private key explanation
///
/// The user can proceed to identity setup from the last screen
/// or dismiss to return without creating an identity.
class IdentityExplainerFlow extends StatefulWidget {
  /// Creates an [IdentityExplainerFlow].
  const IdentityExplainerFlow({super.key});

  @override
  State<IdentityExplainerFlow> createState() => _IdentityExplainerFlowState();
}

class _IdentityExplainerFlowState extends State<IdentityExplainerFlow> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pageCount = 2;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Nostr')),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: const [_WhatIsNostrPage(), _YourKeyPairPage()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PageIndicator(
                  currentPage: _currentPage,
                  pageCount: _pageCount,
                ),
                if (_currentPage < _pageCount - 1)
                  FilledButton(onPressed: _nextPage, child: const Text('Next'))
                else
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Set Up Identity'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatIsNostrPage extends StatelessWidget {
  const _WhatIsNostrPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.language, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'What is Nostr?',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Nostr is a decentralized protocol for social communication. '
            'There are no accounts to create, no companies that control '
            'your data, and no risk of being deplatformed.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _YourKeyPairPage extends StatelessWidget {
  const _YourKeyPairPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Your Key Pair',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your identity is a cryptographic key pair. Your public key '
            '(npub) is like a username — share it freely. Your private '
            'key (nsec) is like a password — but there is no recovery '
            'if you lose it.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.currentPage, required this.pageCount});

  final int currentPage;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentPage;
        return Container(
          width: isActive ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        );
      }),
    );
  }
}
