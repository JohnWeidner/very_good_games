import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';
import 'package:very_good_games/settings/settings.dart';

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

class _MockNostrDeletionRepository extends Mock
    implements NostrDeletionRepository {}

extension on WidgetTester {
  Future<void> pumpSettingsPage() {
    final repository = _MockNostrIdentityRepository();
    when(() => repository.getPublicKey()).thenAnswer((_) async => null);
    when(() => repository.hasIdentity()).thenAnswer((_) async => false);

    return pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<NostrIdentityRepository>(
            create: (_) => repository,
          ),
          RepositoryProvider<NostrDeletionRepository>(
            create: (_) => _MockNostrDeletionRepository(),
          ),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
  }
}

void main() {
  group('SettingsPage', () {
    testWidgets('renders Settings title in AppBar', (tester) async {
      await tester.pumpSettingsPage();
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders Nostr Identity section', (tester) async {
      await tester.pumpSettingsPage();
      await tester.pumpAndSettle();

      expect(find.text('Nostr Identity'), findsOneWidget);
      expect(find.text('Set up your identity'), findsOneWidget);
    });
  });
}
