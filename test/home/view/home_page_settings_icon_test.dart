import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/home/view/home_page.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/settings/settings.dart';

class _MockGameRegistry extends Mock implements GameRegistry {
  @override
  List<GameDefinition> get games => [];
}

class _MockGameStorageRepository extends Mock
    implements GameStorageRepository {}

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

void main() {
  group('HomePage settings icon', () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      );
    });

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<GameRegistry>(
              create: (_) => _MockGameRegistry(),
            ),
            RepositoryProvider<GameStorageRepository>(
              create: (_) => _MockGameStorageRepository(),
            ),
            RepositoryProvider<NostrIdentityRepository>(
              create: (_) {
                final mock = _MockNostrIdentityRepository();
                when(() => mock.getPublicKey()).thenAnswer((_) async => null);
                when(() => mock.hasIdentity()).thenAnswer((_) async => false);
                return mock;
              },
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders settings icon in AppBar', (tester) async {
      await pumpApp(tester);

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('tapping settings icon navigates to /settings', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
