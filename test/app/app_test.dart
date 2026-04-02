import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/app/app.dart';
import 'package:very_good_games/app/routes/routes.dart';
import 'package:very_good_games/core/core.dart';

void main() {
  group('App', () {
    late GoRouter router;
    late GameRegistry gameRegistry;
    late GameStorageRepository storageRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageRepository = GameStorageRepository(preferences: prefs);
      gameRegistry = GameRegistry(games: []);
      router = createRouter(gameRegistry);
    });

    testWidgets('renders MaterialApp.router', (tester) async {
      await tester.pumpWidget(
        App(
          router: router,
          gameRegistry: gameRegistry,
          gameStorageRepository: storageRepository,
        ),
      );

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('displays Very Good Games title', (tester) async {
      await tester.pumpWidget(
        App(
          router: router,
          gameRegistry: gameRegistry,
          gameStorageRepository: storageRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Very Good Games'), findsOneWidget);
    });
  });
}
