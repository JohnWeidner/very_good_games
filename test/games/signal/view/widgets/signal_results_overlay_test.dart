import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/games/signal/cubit/signal_cubit.dart';
import 'package:very_good_games/games/signal/logic/logic.dart';
import 'package:very_good_games/games/signal/view/widgets/signal_results_overlay.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/community_stats_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/contact_list_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';

class _MockResultSharingCubit extends MockCubit<ResultSharingState>
    implements ResultSharingCubit {}

class _MockCommunityStatsCubit extends MockCubit<CommunityStatsState>
    implements CommunityStatsCubit {}

class _MockLeaderboardCubit extends MockCubit<LeaderboardState>
    implements LeaderboardCubit {}

class _MockContactListCubit extends MockCubit<ContactListState>
    implements ContactListCubit {}

class _MockNostrProfileRepository extends Mock
    implements NostrProfileRepository {}

void main() {
  group('SignalResultsOverlay', () {
    late ResultSharingCubit sharingCubit;
    late CommunityStatsCubit statsCubit;
    late LeaderboardCubit leaderboardCubit;
    late ContactListCubit contactListCubit;
    late NostrProfileRepository nostrProfileRepository;

    setUp(() {
      sharingCubit = _MockResultSharingCubit();
      statsCubit = _MockCommunityStatsCubit();
      leaderboardCubit = _MockLeaderboardCubit();
      contactListCubit = _MockContactListCubit();
      nostrProfileRepository = _MockNostrProfileRepository();
      when(() => sharingCubit.state).thenReturn(const ResultSharingState());
      when(() => statsCubit.state).thenReturn(const CommunityStatsState());
      when(() => leaderboardCubit.state).thenReturn(const LeaderboardState());
      when(
        () => leaderboardCubit.fetchLeaderboard(any()),
      ).thenAnswer((_) async {});
      when(() => contactListCubit.state).thenReturn(const ContactListState());
      when(() => contactListCubit.loadFollows()).thenAnswer((_) async {});
      when(
        () => nostrProfileRepository.getProfile(any()),
      ).thenAnswer((_) async => null);
    });

    SignalState winState({int score = 400, int moveCount = 5}) {
      final result = PuzzleGenerator.generate(42);
      final signals = SignalCalculator.calculate(result.puzzle);
      return SignalState(
        grid: result.puzzle,
        towerSignals: signals,
        solutionWallCount: result.solutionWallCount,
        status: SignalStatus.won,
        moveCount: moveCount,
        score: score,
      );
    }

    Widget buildSubject(SignalState state) {
      return MaterialApp(
        home: Scaffold(
          body: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<NostrProfileRepository>.value(
                value: nostrProfileRepository,
              ),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<ResultSharingCubit>.value(value: sharingCubit),
                BlocProvider<CommunityStatsCubit>.value(value: statsCubit),
                BlocProvider<LeaderboardCubit>.value(value: leaderboardCubit),
                BlocProvider<ContactListCubit>.value(value: contactListCubit),
              ],
              child: SignalResultsOverlay(state: state),
            ),
          ),
        ),
      );
    }

    testWidgets('shows Puzzle Solved title', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('Puzzle Solved!'), findsOneWidget);
    });

    testWidgets('shows score and points label', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('400'), findsOneWidget);
      expect(find.text('points'), findsOneWidget);
    });

    testWidgets('shows move count', (tester) async {
      await tester.pumpWidget(buildSubject(winState(moveCount: 7)));

      expect(find.text('7 moves, 0:00'), findsOneWidget);
    });

    testWidgets('shows star rating', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      // 400 → 3 stars.
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNothing);
    });

    testWidgets('shows Share to Nostr button', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('Share to Nostr'), findsOneWidget);
    });

    testWidgets('shows Back to Hub button', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('Back to Hub'), findsOneWidget);
    });
  });
}
