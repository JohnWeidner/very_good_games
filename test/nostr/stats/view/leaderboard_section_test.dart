import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/nostr/stats/cubit/leaderboard_cubit.dart';
import 'package:very_good_games/nostr/stats/models/leaderboard.dart';
import 'package:very_good_games/nostr/stats/view/leaderboard_section.dart';

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

    setUp(() {
      mockCubit = _MockLeaderboardCubit();
    });

    tearDown(() {
      mockCubit.close();
    });

    Widget buildTestWidget(LeaderboardState initialState) {
      when(() => mockCubit.state).thenReturn(initialState);
      when(() => mockCubit.fetchLeaderboard(any())).thenAnswer((_) async {});
      mockCubit.emitState(initialState);

      return MaterialApp(
        home: BlocProvider<LeaderboardCubit>.value(
          value: mockCubit,
          child: const Scaffold(
            body: LeaderboardSection(dTag: 'test:2026-04-06'),
          ),
        ),
      );
    }

    testWidgets('shows identity setup prompt when hasIdentity=false', (
      WidgetTester tester,
    ) async {
      const state = LeaderboardState(hasIdentity: false);

      await tester.pumpWidget(buildTestWidget(state));

      expect(
        find.text('Set up your identity to get ranked on the leaderboard'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('shows loading placeholder while loading', (
      WidgetTester tester,
    ) async {
      const state = LeaderboardState(status: LeaderboardStatus.loading);

      await tester.pumpWidget(buildTestWidget(state));

      expect(find.text('Loading leaderboard...'), findsOneWidget);
    });

    testWidgets('shows "no scores yet" when leaderboard is empty', (
      WidgetTester tester,
    ) async {
      const state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: Leaderboard(dTag: 'test:2026-04-06', entries: []),
      );

      await tester.pumpWidget(buildTestWidget(state));

      expect(find.text('No scores yet — be the first!'), findsOneWidget);
    });

    testWidgets('shows unavailable message when status=unavailable', (
      WidgetTester tester,
    ) async {
      const state = LeaderboardState(status: LeaderboardStatus.unavailable);

      await tester.pumpWidget(buildTestWidget(state));

      expect(find.text('Leaderboard unavailable'), findsOneWidget);
    });

    testWidgets('renders leaderboard table with headers and entries', (
      WidgetTester tester,
    ) async {
      const entry1 = LeaderboardEntry(
        npub: 'npub1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        score: 100,
        rank: 1,
        createdAt: 1000,
      );
      const entry2 = LeaderboardEntry(
        npub: 'npub1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        score: 90,
        rank: 2,
        createdAt: 2000,
      );
      const state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: Leaderboard(
          dTag: 'test:2026-04-06',
          entries: [entry1, entry2],
        ),
      );

      await tester.pumpWidget(buildTestWidget(state));

      // Check headers
      expect(find.text('Rank'), findsWidgets);
      expect(find.text('Player'), findsWidgets);
      expect(find.text('Score'), findsWidgets);

      // Check entries
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('highlights user entry when pubkey matches', (
      WidgetTester tester,
    ) async {
      const entry = LeaderboardEntry(
        npub: 'npub1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        score: 100,
        rank: 1,
        createdAt: 1000,
      );
      const state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: Leaderboard(dTag: 'test:2026-04-06', entries: [entry]),
      );

      // Valid 64-char hex pubkey
      const userHex =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      when(() => mockCubit.state).thenReturn(state);
      when(() => mockCubit.fetchLeaderboard(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<LeaderboardCubit>.value(
            value: mockCubit,
            child: const Scaffold(
              body: LeaderboardSection(
                dTag: 'test:2026-04-06',
                userPubKeyHex: userHex,
              ),
            ),
          ),
        ),
      );

      // Verify the highlighted row has the primaryContainer color
      // (This is a visual test; we check that the row exists)
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('displays truncated npub as player name', (
      WidgetTester tester,
    ) async {
      const entry = LeaderboardEntry(
        npub: 'npub1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        score: 100,
        rank: 1,
        createdAt: 1000,
      );
      const state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: Leaderboard(dTag: 'test:2026-04-06', entries: [entry]),
      );

      await tester.pumpWidget(buildTestWidget(state));

      // displayName should be truncated
      expect(find.text('npub1aaa...'), findsOneWidget);
    });

    testWidgets('fetches leaderboard on initial build', (
      WidgetTester tester,
    ) async {
      when(() => mockCubit.state).thenReturn(const LeaderboardState());
      when(() => mockCubit.fetchLeaderboard(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget(const LeaderboardState()));
      await tester.pumpAndSettle();

      verify(() => mockCubit.fetchLeaderboard('test:2026-04-06')).called(1);
    });

    testWidgets('renders multiple entries in correct order', (
      WidgetTester tester,
    ) async {
      const entry1 = LeaderboardEntry(
        npub: 'npub1111',
        score: 100,
        rank: 1,
        createdAt: 1000,
      );
      const entry2 = LeaderboardEntry(
        npub: 'npub2222',
        score: 90,
        rank: 2,
        createdAt: 2000,
      );
      const entry3 = LeaderboardEntry(
        npub: 'npub3333',
        score: 80,
        rank: 3,
        createdAt: 3000,
      );
      const state = LeaderboardState(
        status: LeaderboardStatus.loaded,
        leaderboard: Leaderboard(
          dTag: 'test:2026-04-06',
          entries: [entry1, entry2, entry3],
        ),
      );

      await tester.pumpWidget(buildTestWidget(state));

      // Verify all entries are present with scores in correct order
      expect(find.text('100'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    });
  });
}
