import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/profile/cubit/profile_sheet_cubit.dart';
import 'package:very_good_games/nostr/profile/view/profile_bottom_sheet.dart';

class _MockProfileSheetCubit extends MockCubit<ProfileSheetState>
    implements ProfileSheetCubit {}

void main() {
  group('ProfileBottomSheet', () {
    late _MockProfileSheetCubit mockCubit;

    setUp(() {
      mockCubit = _MockProfileSheetCubit();
    });

    Widget buildSubject({bool isFollowed = false, bool isCurrentUser = false}) {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<ProfileSheetCubit>.value(
            value: mockCubit,
            child: ProfileBottomSheet(
              pubkeyHex:
                  'abc123def456abc123def456abc123de'
                  'f456abc123def456abc123def456abc1',
              isFollowed: isFollowed,
              isCurrentUser: isCurrentUser,
            ),
          ),
        ),
      );
    }

    testWidgets('shows loading placeholder when loading', (tester) async {
      when(
        () => mockCubit.state,
      ).thenReturn(const ProfileSheetState(status: ProfileSheetStatus.loading));

      await tester.pumpWidget(buildSubject());

      // Should show person icon placeholder.
      expect(find.byIcon(Icons.person), findsOneWidget);
      // Should NOT show name text or View on Nostr button.
      expect(find.text('View on Nostr'), findsNothing);
    });

    testWidgets('shows profile content when loaded', (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProfileSheetState(
          status: ProfileSheetStatus.loaded,
          profile: NostrProfile(
            pubkey:
                'abc123def456abc123def456abc123de'
                'f456abc123def456abc123def456abc1',
            name: 'Alice',
            about: 'Hello world',
            nip05: 'alice@example.com',
            lud16: 'alice@getalby.com',
            lastFetchedAt: 1000,
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('alice@getalby.com'), findsOneWidget);
      expect(find.text('View on Nostr'), findsOneWidget);
    });

    testWidgets('shows following badge when isFollowed is true', (
      tester,
    ) async {
      when(() => mockCubit.state).thenReturn(
        const ProfileSheetState(
          status: ProfileSheetStatus.loaded,
          profile: NostrProfile(
            pubkey:
                'abc123def456abc123def456abc123de'
                'f456abc123def456abc123def456abc1',
            name: 'Bob',
          ),
        ),
      );

      await tester.pumpWidget(buildSubject(isFollowed: true));

      expect(find.text('Following'), findsOneWidget);
      expect(find.byIcon(Icons.how_to_reg), findsOneWidget);
    });

    testWidgets('hides following badge for current user', (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProfileSheetState(
          status: ProfileSheetStatus.loaded,
          profile: NostrProfile(
            pubkey:
                'abc123def456abc123def456abc123de'
                'f456abc123def456abc123def456abc1',
            name: 'Me',
          ),
        ),
      );

      await tester.pumpWidget(
        buildSubject(isFollowed: true, isCurrentUser: true),
      );

      expect(find.text('Following'), findsNothing);
    });

    testWidgets('shows truncated pubkey when profile is null', (tester) async {
      when(
        () => mockCubit.state,
      ).thenReturn(const ProfileSheetState(status: ProfileSheetStatus.loaded));

      await tester.pumpWidget(buildSubject());

      // Should show truncated hex key as display name.
      expect(find.text('abc123de...f456abc1'), findsOneWidget);
    });

    testWidgets('hides optional fields when null', (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProfileSheetState(
          status: ProfileSheetStatus.loaded,
          profile: NostrProfile(
            pubkey:
                'abc123def456abc123def456abc123de'
                'f456abc123def456abc123def456abc1',
            name: 'Alice',
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());

      // NIP-05 and lud16 icons should not appear.
      expect(find.byIcon(Icons.verified_outlined), findsNothing);
      expect(find.byIcon(Icons.bolt), findsNothing);
    });

    testWidgets('refresh button triggers refreshProfile', (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProfileSheetState(
          status: ProfileSheetStatus.loaded,
          profile: NostrProfile(
            pubkey:
                'abc123def456abc123def456abc123de'
                'f456abc123def456abc123def456abc1',
            name: 'Alice',
            lastFetchedAt: 1000,
          ),
        ),
      );
      when(() => mockCubit.refreshProfile()).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      verify(() => mockCubit.refreshProfile()).called(1);
    });
  });
}
