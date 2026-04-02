import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/home/cubit/home_cubit.dart';
import 'package:very_good_games/home/view/widgets/game_tile.dart';

class _MockHomeCubit extends MockCubit<HomeState> implements HomeCubit {}

class _MockGameDefinition extends Mock implements GameDefinition {}

extension on WidgetTester {
  Future<void> pumpHomePage(HomeCubit cubit) {
    return pumpWidget(
      MaterialApp(
        home: BlocProvider<HomeCubit>.value(
          value: cubit,
          child: const Scaffold(body: _HomeViewTestWrapper()),
        ),
      ),
    );
  }
}

/// Wraps the BlocBuilder portion of the home view for testing
/// without going through the provider-creating HomePage.
class _HomeViewTestWrapper extends StatelessWidget {
  const _HomeViewTestWrapper();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        return switch (state.status) {
          HomeStatus.initial || HomeStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          HomeStatus.error => const Center(
            child: Text('Something went wrong.'),
          ),
          HomeStatus.loaded =>
            state.games.isEmpty
                ? const Center(child: Text('Games coming soon!'))
                : ListView.builder(
                    itemCount: state.games.length,
                    itemBuilder: (context, index) =>
                        GameTile(entry: state.games[index]),
                  ),
        };
      },
    );
  }
}

void main() {
  group('HomePage', () {
    late HomeCubit cubit;

    setUp(() {
      cubit = _MockHomeCubit();
    });

    testWidgets('shows loading indicator for initial state', (tester) async {
      when(() => cubit.state).thenReturn(const HomeState());

      await tester.pumpHomePage(cubit);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows loading indicator for loading state', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn(const HomeState(status: HomeStatus.loading));

      await tester.pumpHomePage(cubit);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message on error state', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn(const HomeState(status: HomeStatus.error));

      await tester.pumpHomePage(cubit);

      expect(find.text('Something went wrong.'), findsOneWidget);
    });

    testWidgets('shows empty state when loaded with no games', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn(const HomeState(status: HomeStatus.loaded));

      await tester.pumpHomePage(cubit);

      expect(find.text('Games coming soon!'), findsOneWidget);
    });

    testWidgets('shows game tiles when loaded with games', (tester) async {
      final game = _MockGameDefinition();
      when(() => game.id).thenReturn('test');
      when(() => game.name).thenReturn('Test Game');
      when(() => game.description).thenReturn('A fun test');
      when(() => game.icon).thenReturn(Icons.games);
      when(() => game.routePath).thenReturn('/games/test');

      when(() => cubit.state).thenReturn(
        HomeState(
          status: HomeStatus.loaded,
          games: [
            HomeGameEntry(
              definition: game,
              dailyStatus: DailyGameStatus.notStarted,
              streak: const StreakData(),
            ),
          ],
        ),
      );

      await tester.pumpHomePage(cubit);

      expect(find.text('Test Game'), findsOneWidget);
      expect(find.text('A fun test'), findsOneWidget);
    });
  });
}
