import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Full-screen modal onboarding flow explaining Nostr identity.
///
/// Shown before first identity creation. Consists of 5 screens:
/// 1. "What is Nostr?" — decentralized protocol overview
/// 2. "You Own Your Identity" — no accounts, self-sovereignty
/// 3. "Digital Signatures" — how signing replaces accounts
/// 4. "Public vs. Private" — npub vs nsec
/// 5. "One ID or Many" — identity flexibility and safety
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

  static const _pageCount = 5;

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
      appBar: AppBar(
        title: const Text('About Nostr'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: const [
                _WhatIsNostrPage(),
                _YouOwnYourIdentityPage(),
                _DigitalSignaturesPage(),
                _PublicVsPrivatePage(),
                _OneIdOrManyPage(),
              ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.language, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'What is Nostr?',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'It\u2019s not an app or company; it\u2019s \u2026',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const MarkdownBody(
            data:
                '- **An open protocol** \u2014 a shared set of rules that '
                'anyone can build apps on top of, like how email is a '
                'protocol with many different apps\n'
                '- **A network of relays** \u2014 independent servers run '
                'by different people that store and pass around messages',
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _YouOwnYourIdentityPage extends StatelessWidget {
  const _YouOwnYourIdentityPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.key, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'You Own Your Identity',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'On Nostr, there are no \u201caccounts\u201d owned by a '
            'company. You are your own master.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _DigitalSignaturesPage extends StatelessWidget {
  const _DigitalSignaturesPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.draw, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Digital Signatures',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Instead of having user accounts, Nostr works by having '
            'every note \u201csigned\u201d to prove the signer has '
            'the nsec that created that note.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _PublicVsPrivatePage extends StatelessWidget {
  const _PublicVsPrivatePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.visibility, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Public vs. Private',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'When anyone sees one of your notes, they won\u2019t see '
            'your secret key (nsec), they will only see your public '
            'ID (npub).',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const MarkdownBody(
            data:
                '- **Public** \u2014 Your npub is visible to everyone, '
                'like a username\n'
                '- **Private** \u2014 Your nsec is hidden, like a '
                'password with no reset',
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _OneIdOrManyPage extends StatelessWidget {
  const _OneIdOrManyPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.fingerprint, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'One ID or Many \u2014 You Decide.',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const MarkdownBody(
            data:
                '**Freedom of Identity**\n\n'
                'You can create a new ID for every site you visit, '
                'or use one single ID to stay connected everywhere.\n\n'
                '**The Power of One**\n\n'
                'If you want a single identity that never changes, '
                'just use the same nsec across different apps. Your '
                'followers and posts will follow you.\n\n'
                '**The Golden Rule**\n\n'
                'To keep your permanent ID safe, write your nsec down '
                'and store it with your important physical documents. '
                'There is no \u201cReset Password\u201d button here.',
          ),
          const SizedBox(height: 48),
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
