import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/games/cascade/cubit/cascade_cubit.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/view/widgets/cascade_results_overlay.dart';
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
  group('CascadeResultsOverlay', () {
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

    CascadeState winState({int score = 100, int attempts = 1}) {
      return CascadeState(
        board: CascadeBoard(
          levers: const [Lever(row: 1, col: 2, direction: LeverDirection.left)],
          binOrder: const [0, 1, 2],
        ),
        initialLevers: const [
          Lever(row: 1, col: 2, direction: LeverDirection.left),
        ],
        status: CascadeStatus.won,
        attempts: attempts,
        score: score,
      );
    }

    Widget buildSubject(CascadeState state, {VoidCallback? onViewPuzzle}) {
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
              child: CascadeResultsOverlay(
                state: state,
                onViewPuzzle: onViewPuzzle,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows Puzzle Solved title', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('Puzzle Solved!'), findsOneWidget);
    });

    testWidgets('shows score', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('100 points'), findsOneWidget);
    });

    testWidgets('shows attempt count', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('1 attempt'), findsOneWidget);
    });

    testWidgets('shows plural attempts', (tester) async {
      await tester.pumpWidget(buildSubject(winState(attempts: 3)));

      expect(find.text('3 attempts'), findsOneWidget);
    });

    testWidgets('shows star rating', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      // 1 attempt = 3 stars
      expect(find.byIcon(Icons.star), findsNWidgets(3));
    });

    testWidgets('shows Share to Nostr button', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('Share to Nostr'), findsOneWidget);
    });

    testWidgets('shows Back to Hub button', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('Back to Hub'), findsOneWidget);
    });

    testWidgets('shows View Puzzle button when callback provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(winState(), onViewPuzzle: () {}));

      expect(find.text('View Puzzle'), findsOneWidget);
    });

    testWidgets('hides View Puzzle button when callback is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('View Puzzle'), findsNothing);
    });
  });
}
