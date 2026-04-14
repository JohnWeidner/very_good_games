import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/games/chromix/cubit/chromix_cubit.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/view/widgets/chromix_results_overlay.dart';
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
  group('ChromixResultsOverlay', () {
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

    ChromixState winState({
      int score = 8,
      int moveCount = 6,
      int undoCount = 2,
      int optimalMoves = 5,
    }) {
      return ChromixState(
        grid: ChromixGrid(
          cells: List.generate(16, (_) => const ColorCell(ChromixColor.red)),
        ),
        target: const {ChromixColor.red: 16},
        optimalMoves: optimalMoves,
        status: ChromixStatus.won,
        moveCount: moveCount,
        undoCount: undoCount,
        score: score,
      );
    }

    Widget buildSubject(ChromixState state) {
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
              child: ChromixResultsOverlay(state: state),
            ),
          ),
        ),
      );
    }

    testWidgets('shows Puzzle Solved title', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('Puzzle Solved!'), findsOneWidget);
    });

    testWidgets('shows score total', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('8 total'), findsOneWidget);
    });

    testWidgets('shows moves and undos breakdown', (tester) async {
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.text('6 moves, 2 undos, 0:00'), findsOneWidget);
    });

    testWidgets('shows star rating', (tester) async {
      // score 8 with optimalMoves 5 → 2 stars (8 <= 5+3)
      await tester.pumpWidget(buildSubject(winState()));

      expect(find.byIcon(Icons.star), findsNWidgets(2));
      expect(find.byIcon(Icons.star_border), findsOneWidget);
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
