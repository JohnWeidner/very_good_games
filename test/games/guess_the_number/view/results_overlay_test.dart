import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/results_overlay.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/community_stats_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/models/community_stats.dart';

class _MockResultSharingCubit extends MockCubit<ResultSharingState>
    implements ResultSharingCubit {}

class _MockCommunityStatsCubit extends MockCubit<CommunityStatsState>
    implements CommunityStatsCubit {}

class _MockLeaderboardCubit extends MockCubit<LeaderboardState>
    implements LeaderboardCubit {}

void main() {
  group('ResultsOverlay', () {
    late ResultSharingCubit sharingCubit;
    late CommunityStatsCubit statsCubit;
    late LeaderboardCubit leaderboardCubit;

    setUp(() {
      sharingCubit = _MockResultSharingCubit();
      when(() => sharingCubit.state).thenReturn(const ResultSharingState());
      statsCubit = _MockCommunityStatsCubit();
      when(() => statsCubit.state).thenReturn(const CommunityStatsState());
      leaderboardCubit = _MockLeaderboardCubit();
      when(() => leaderboardCubit.state).thenReturn(const LeaderboardState());
      when(
        () => leaderboardCubit.fetchLeaderboard(any()),
      ).thenAnswer((_) async {});
    });

    Widget buildSubject(GameState state) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => MultiBlocProvider(
              providers: [
                BlocProvider<ResultSharingCubit>.value(value: sharingCubit),
                BlocProvider<CommunityStatsCubit>.value(value: statsCubit),
                BlocProvider<LeaderboardCubit>.value(value: leaderboardCubit),
              ],
              child: Scaffold(body: ResultsOverlay(state: state)),
            ),
          ),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    GameState winState({int score = 350}) => GameState(
      cells: List.filled(400, CellState.possible),
      targetNumber: 42,
      status: GameStatus.won,
      score: score,
      questionCount: 5,
      elapsedSeconds: 30,
    );

    GameState lossState() => GameState(
      cells: List.filled(400, CellState.possible),
      targetNumber: 42,
      status: GameStatus.lost,
      score: 0,
      questionCount: 12,
      elapsedSeconds: 300,
    );

    testWidgets('shows "You found it!" on win', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));
      expect(find.text('You found it!'), findsOneWidget);
      expect(find.text('The number was 42'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
      expect(find.text('points'), findsOneWidget);
    });

    testWidgets('shows score breakdown on win', (tester) async {
      await tester.pumpWidget(buildSubject(winState(score: 290)));
      expect(find.text('Questions'), findsOneWidget);
      expect(find.text('-250'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('-60'), findsOneWidget);
    });

    testWidgets('shows star rating on win', (tester) async {
      await tester.pumpWidget(buildSubject(winState(score: 500)));
      // 500 >= 450 -> 3 stars.
      expect(find.byIcon(Icons.star), findsNWidgets(3));
    });

    testWidgets('shows "Time\'s up!" on loss', (tester) async {
      await tester.pumpWidget(buildSubject(lossState()));
      expect(find.text("Time's up!"), findsOneWidget);
      expect(find.text('The number was 42'), findsOneWidget);
      expect(find.text('Score reached zero'), findsOneWidget);
    });

    testWidgets('shows Back to Hub button', (tester) async {
      await tester.pumpWidget(buildSubject(winState(score: 100)));
      expect(find.text('Back to Hub'), findsOneWidget);
    });

    group('Share to Nostr button', () {
      testWidgets('shows Share to Nostr button on win', (tester) async {
        await tester.pumpWidget(buildSubject(winState()));
        expect(find.text('Share to Nostr'), findsOneWidget);
      });

      testWidgets('does not show share button on loss', (tester) async {
        await tester.pumpWidget(buildSubject(lossState()));
        expect(find.text('Share to Nostr'), findsNothing);
      });

      testWidgets('shows Sharing... during publishing', (tester) async {
        when(() => sharingCubit.state).thenReturn(
          const ResultSharingState(status: ResultSharingStatus.publishing),
        );

        await tester.pumpWidget(buildSubject(winState()));
        expect(find.text('Sharing...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows Shared with check on success', (tester) async {
        when(() => sharingCubit.state).thenReturn(
          const ResultSharingState(status: ResultSharingStatus.success),
        );

        await tester.pumpWidget(buildSubject(winState()));
        expect(find.text('Shared'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('shows snackbar on failure', (tester) async {
        when(() => sharingCubit.state).thenReturn(const ResultSharingState());

        whenListen(
          sharingCubit,
          Stream.fromIterable([
            const ResultSharingState(
              status: ResultSharingStatus.failure,
              errorMessage: 'Could not share your result.',
            ),
          ]),
        );

        await tester.pumpWidget(buildSubject(winState()));
        await tester.pump();

        expect(find.text('Could not share your result.'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('shows success snackbar with backup nudge', (tester) async {
        when(() => sharingCubit.state).thenReturn(const ResultSharingState());

        whenListen(
          sharingCubit,
          Stream.fromIterable([
            const ResultSharingState(status: ResultSharingStatus.success),
          ]),
        );

        await tester.pumpWidget(buildSubject(winState()));
        await tester.pump();

        expect(find.textContaining('Result shared!'), findsOneWidget);
        expect(find.textContaining('back up your key'), findsOneWidget);
      });
    });

    group('Community stats', () {
      testWidgets('shows stats when loaded', (tester) async {
        when(() => statsCubit.state).thenReturn(
          const CommunityStatsState(
            status: CommunityStatsStatus.loaded,
            stats: CommunityStats(playerCount: 25, avgScore: 2.5),
          ),
        );

        await tester.pumpWidget(buildSubject(winState()));

        expect(find.text('~25 players, ~3 avg score'), findsOneWidget);
      });

      testWidgets('hides stats when unavailable', (tester) async {
        when(() => statsCubit.state).thenReturn(
          const CommunityStatsState(status: CommunityStatsStatus.unavailable),
        );

        await tester.pumpWidget(buildSubject(winState()));

        expect(find.textContaining('players'), findsNothing);
      });

      testWidgets('hides stats during loading', (tester) async {
        when(() => statsCubit.state).thenReturn(
          const CommunityStatsState(status: CommunityStatsStatus.loading),
        );

        await tester.pumpWidget(buildSubject(winState()));

        expect(find.textContaining('players'), findsNothing);
      });

      testWidgets('shows stats on loss overlay too', (tester) async {
        when(() => statsCubit.state).thenReturn(
          const CommunityStatsState(
            status: CommunityStatsStatus.loaded,
            stats: CommunityStats(playerCount: 10, avgScore: 1.8),
          ),
        );

        await tester.pumpWidget(buildSubject(lossState()));

        expect(find.text('~10 players, ~2 avg score'), findsOneWidget);
      });
    });
  });
}
