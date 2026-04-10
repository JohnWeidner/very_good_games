import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/profile/profile.dart';
import 'package:very_good_games/nostr/stats/cubit/contact_list_cubit.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';
import 'package:very_good_games/nostr/stats/view/leaderboard_section.dart';

class _MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

class _MockContactListCubit extends MockCubit<ContactListState>
    implements ContactListCubit {}

class _MockNostrProfileRepository extends Mock
    implements NostrProfileRepository {}

class _MockLeaderboardCubit extends Mock implements LeaderboardCubit {
  final _stateController = StreamController<LeaderboardState>.broadcast();

  @override
  Stream<LeaderboardState> get stream => _stateController.stream;

  void emitState(LeaderboardState state) {
    _stateController.add(state);
  }

  @override
  Future<void> close() async {
    await _stateController.close();
  }
}

void main() {
  group('LeaderboardSection', () {
    late _MockLeaderboardCubit mockCubit;
    late _MockProfileCubit mockProfileCubit;
    late _MockContactListCubit mockContactListCubit;
    late _MockNostrProfileRepository mockProfileRepository;

    setUp(() {
      mockCubit = _MockLeaderboardCubit();
      mockProfileCubit = _MockProfileCubit();
      mockContactListCubit = _MockContactListCubit();
      mockProfileRepository = _MockNostrProfileRepository();
      when(() => mockProfileCubit.state).thenReturn(const ProfileState());
      when(
        () => mockContactListCubit.state,
      ).thenReturn(const ContactListState());
      when(() => mockContactListCubit.loadFollows()).thenAnswer((_) async {});
      when(
        () => mockProfileRepository.getProfile(any()),
      ).thenAnswer((_) async => null);
    });

    tearDown(() {
      mockCubit.close();
    });

    Widget buildTestWidget(LeaderboardState initialState) {
      when(() => mockCubit.state).thenReturn(initialState);
      when(() => mockCubit.fetchLeaderboard(any())).thenAnswer((_) async {});
      mockCubit.emitState(initialState);

      return MaterialApp(
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<NostrProfileRepository>.value(
              value: mockProfileRepository,
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<LeaderboardCubit>.value(value: mockCubit),
              BlocProvider<ProfileCubit>.value(value: mockProfileCubit),
              BlocProvider<ContactListCubit>.value(value: mockContactListCubit),
            ],
            child: const Scaffold(
              body: LeaderboardSection(dTag: 'test:2026-04-06'),
            ),
          ),
        ),
      );
    }

    testWidgets('shows identity setup prompt when hasIdentity=false '
        'and still shows leaderboard', (tester) async {
      final npub = Nip19.encodePubKey('a' * 64);
      final state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        hasIdentity: false,
        leaderboard: Leaderboard(
          dTag: 'test:2026-04-06',
          entries: [
            LeaderboardEntry(npub: npub, score: 100, rank: 1, createdAt: 1000),
          ],
        ),
      );

      await tester.pumpWidget(buildTestWidget(state));

      // Both prompt AND leaderboard visible.
      expect(
        find.text('Set up your identity to get ranked on the leaderboard'),
        findsOneWidget,
      );
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('shows loading placeholder while loading', (tester) async {
      const state = LeaderboardState(status: LeaderboardStatus.loading);

      await tester.pumpWidget(buildTestWidget(state));

      expect(find.text('Loading leaderboard...'), findsOneWidget);
    });

    testWidgets('shows "no scores yet" when leaderboard is empty', (
      tester,
    ) async {
      const state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: Leaderboard(dTag: 'test:2026-04-06', entries: []),
      );

      await tester.pumpWidget(buildTestWidget(state));

      expect(find.text('No scores yet — be the first!'), findsOneWidget);
    });

    testWidgets('shows unavailable message when status=unavailable', (
      tester,
    ) async {
      const state = LeaderboardState(status: LeaderboardStatus.unavailable);

      await tester.pumpWidget(buildTestWidget(state));

      expect(find.text('Leaderboard unavailable'), findsOneWidget);
    });

    testWidgets('renders leaderboard with headers and entries', (tester) async {
      final npubA = Nip19.encodePubKey('a' * 64);
      final npubB = Nip19.encodePubKey('b' * 64);
      final state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: Leaderboard(
          dTag: 'test:2026-04-06',
          entries: [
            LeaderboardEntry(npub: npubA, score: 100, rank: 1, createdAt: 1000),
            LeaderboardEntry(npub: npubB, score: 90, rank: 2, createdAt: 2000),
          ],
        ),
      );

      await tester.pumpWidget(buildTestWidget(state));

      expect(find.text('Rank'), findsOneWidget);
      expect(find.text('Player'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('shows follow indicator for followed entries', (tester) async {
      final npub = Nip19.encodePubKey('a' * 64);
      final state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: Leaderboard(
          dTag: 'test:2026-04-06',
          entries: [
            LeaderboardEntry(
              npub: npub,
              score: 100,
              rank: 1,
              createdAt: 1000,
              isFollowed: true,
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestWidget(state));

      expect(find.byIcon(Icons.how_to_reg), findsOneWidget);
    });

    testWidgets('tapping row opens profile bottom sheet', (tester) async {
      final npub = Nip19.encodePubKey('a' * 64);
      final state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: Leaderboard(
          dTag: 'test:2026-04-06',
          entries: [
            LeaderboardEntry(npub: npub, score: 100, rank: 1, createdAt: 1000),
          ],
        ),
      );

      await tester.pumpWidget(buildTestWidget(state));

      // Tap the row (InkWell).
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // A modal bottom sheet should appear.
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('fetches leaderboard and loads follows on initial build', (
      tester,
    ) async {
      when(() => mockCubit.state).thenReturn(const LeaderboardState());
      when(() => mockCubit.fetchLeaderboard(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget(const LeaderboardState()));
      await tester.pumpAndSettle();

      verify(() => mockCubit.fetchLeaderboard('test:2026-04-06')).called(1);
      verify(() => mockContactListCubit.loadFollows()).called(1);
    });
  });
}
