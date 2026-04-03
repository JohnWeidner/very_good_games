import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/identity/view/identity_setup_page.dart';

class _MockNostrIdentityCubit extends MockCubit<NostrIdentityState>
    implements NostrIdentityCubit {}

extension on WidgetTester {
  Future<void> pumpSetupPage(NostrIdentityCubit cubit) {
    return pumpWidget(
      MaterialApp(
        home: BlocProvider<NostrIdentityCubit>.value(
          value: cubit,
          child: const IdentitySetupPage(),
        ),
      ),
    );
  }
}

void main() {
  group('IdentitySetupPage', () {
    late NostrIdentityCubit cubit;

    setUp(() {
      cubit = _MockNostrIdentityCubit();
      when(() => cubit.state).thenReturn(const NostrIdentityState());
    });

    testWidgets('renders generate and import buttons', (tester) async {
      await tester.pumpSetupPage(cubit);

      expect(find.text('Generate New Identity'), findsOneWidget);
      expect(find.text('Import Existing Key'), findsOneWidget);
    });

    testWidgets('tapping generate calls generateIdentity', (tester) async {
      when(() => cubit.generateIdentity()).thenAnswer((_) async {});

      await tester.pumpSetupPage(cubit);
      await tester.tap(find.text('Generate New Identity'));

      verify(() => cubit.generateIdentity()).called(1);
    });

    testWidgets('tapping import shows nsec text field', (tester) async {
      await tester.pumpSetupPage(cubit);

      await tester.tap(find.text('Import Existing Key'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your nsec'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
    });

    testWidgets('shows loading indicator during loading state', (tester) async {
      when(() => cubit.state).thenReturn(
        const NostrIdentityState(status: NostrIdentityStatus.loading),
      );

      await tester.pumpSetupPage(cubit);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error snackbar on error state', (tester) async {
      when(() => cubit.state).thenReturn(const NostrIdentityState());

      whenListen(
        cubit,
        Stream.fromIterable([
          const NostrIdentityState(
            status: NostrIdentityStatus.error,
            errorMessage: 'Invalid nsec key',
          ),
        ]),
      );

      await tester.pumpSetupPage(cubit);
      await tester.pump();

      expect(find.text('Invalid nsec key'), findsOneWidget);
    });

    testWidgets('renders Set Up Identity title in AppBar', (tester) async {
      await tester.pumpSetupPage(cubit);

      expect(find.text('Set Up Identity'), findsOneWidget);
    });

    testWidgets('import button calls importKey with entered text', (
      tester,
    ) async {
      when(() => cubit.importKey(any())).thenAnswer((_) async {});

      await tester.pumpSetupPage(cubit);

      await tester.tap(find.text('Import Existing Key'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nsec1abc');
      await tester.tap(find.text('Import'));

      verify(() => cubit.importKey('nsec1abc')).called(1);
    });

    testWidgets('shows backup key dialog after generation', (tester) async {
      when(() => cubit.state).thenReturn(const NostrIdentityState());

      whenListen(
        cubit,
        Stream.fromIterable([
          const NostrIdentityState(
            status: NostrIdentityStatus.ready,
            npub: 'npub1test',
            nsec: 'nsec1backupkey',
          ),
        ]),
      );

      await tester.pumpSetupPage(cubit);
      await tester.pump();

      expect(find.text('Save Your Key'), findsOneWidget);
      expect(find.text('nsec1backupkey'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('I Saved It'), findsOneWidget);
    });
  });
}
