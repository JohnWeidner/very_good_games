import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:very_good_games/core/core.dart';

part 'home_state.dart';

/// Manages the home screen state — loading game statuses from the registry.
class HomeCubit extends Cubit<HomeState> {
  /// Creates a [HomeCubit].
  HomeCubit({
    required GameRegistry gameRegistry,
    required GameStorageRepository storageRepository,
  }) : _gameRegistry = gameRegistry,
       _storageRepository = storageRepository,
       super(const HomeState());

  final GameRegistry _gameRegistry;
  final GameStorageRepository _storageRepository;

  /// Loads the daily status and streak for each registered game.
  Future<void> loadGames() async {
    emit(state.copyWith(status: HomeStatus.loading));

    try {
      final now = DateTime.now().toUtc();
      final entries = <HomeGameEntry>[];

      for (final game in _gameRegistry.games) {
        final dailyStatus = await game.getDailyStatus(now);
        final streak = _storageRepository.getStreak(game.id);

        entries.add(
          HomeGameEntry(
            definition: game,
            dailyStatus: dailyStatus,
            streak: streak,
          ),
        );
      }

      emit(state.copyWith(status: HomeStatus.loaded, games: entries));
    } on Exception {
      emit(state.copyWith(status: HomeStatus.error));
    }
  }
}
