import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/home/cubit/home_cubit.dart';

class _MockGameDefinition extends Mock implements GameDefinition {}

void main() {
  group('HomeCubit', () {
    late GameRegistry gameRegistry;
    late GameStorageRepository storageRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageRepository = GameStorageRepository(preferences: prefs);
    });

    HomeCubit buildCubit({List<GameDefinition> games = const []}) {
      gameRegistry = GameRegistry(games: games);
      return HomeCubit(
        gameRegistry: gameRegistry,
        storageRepository: storageRepository,
      );
    }

    test('initial state is correct', () {
      final cubit = buildCubit();

      expect(cubit.state, equals(const HomeState()));
    });

    group('loadGames', () {
      blocTest<HomeCubit, HomeState>(
        'emits [loading, loaded] with empty list when no games registered',
        build: buildCubit,
        act: (cubit) => cubit.loadGames(),
        expect: () => [
          const HomeState(status: HomeStatus.loading),
          const HomeState(status: HomeStatus.loaded),
        ],
      );

      blocTest<HomeCubit, HomeState>(
        'emits [loading, loaded] with game entries',
        build: () {
          final game = _MockGameDefinition();
          when(() => game.id).thenReturn('test');
          when(() => game.name).thenReturn('Test');
          when(() => game.description).thenReturn('A test game');
          when(() => game.icon).thenReturn(const IconData(0));
          when(() => game.routePath).thenReturn('/games/test');
          when(
            () => game.getDailyStatus(any()),
          ).thenAnswer((_) async => DailyGameStatus.notStarted);
          return buildCubit(games: [game]);
        },
        act: (cubit) => cubit.loadGames(),
        expect: () => [
          const HomeState(status: HomeStatus.loading),
          isA<HomeState>()
              .having((s) => s.status, 'status', HomeStatus.loaded)
              .having((s) => s.games, 'games', hasLength(1)),
        ],
      );

      blocTest<HomeCubit, HomeState>(
        'emits [loading, error] when game throws',
        build: () {
          final game = _MockGameDefinition();
          when(() => game.getDailyStatus(any())).thenThrow(Exception('fail'));
          return buildCubit(games: [game]);
        },
        act: (cubit) => cubit.loadGames(),
        expect: () => [
          const HomeState(status: HomeStatus.loading),
          const HomeState(status: HomeStatus.error),
        ],
      );
    });
  });

  group('HomeState', () {
    test('supports value equality', () {
      expect(const HomeState(), equals(const HomeState()));
    });

    test('copyWith returns same state when no arguments', () {
      const state = HomeState();

      expect(state.copyWith(), equals(state));
    });

    test('copyWith replaces status', () {
      const state = HomeState();

      expect(
        state.copyWith(status: HomeStatus.loaded),
        equals(const HomeState(status: HomeStatus.loaded)),
      );
    });
  });
}
