import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/home/cubit/home_cubit.dart';
import 'package:very_good_games/home/view/widgets/game_tile.dart';

/// The home screen of Very Good Games.
///
/// Displays a list of available daily games with their status and streaks.
/// Refreshes when the app returns to the foreground.
class HomePage extends StatelessWidget {
  /// Creates a [HomePage].
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeCubit(
        gameRegistry: context.read<GameRegistry>(),
        storageRepository: context.read<GameStorageRepository>(),
      )..loadGames(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<HomeCubit>().loadGames();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Very Good Games'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: BlocBuilder<HomeCubit, HomeState>(
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
                  ? const _EmptyState()
                  : _GameList(games: state.games),
          };
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Games coming soon!',
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _GameList extends StatelessWidget {
  const _GameList({required this.games});

  final List<HomeGameEntry> games;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: games.length,
      itemBuilder: (context, index) => GameTile(entry: games[index]),
    );
  }
}
