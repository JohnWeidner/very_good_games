import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/nostr/identity/cubit/nostr_identity_cubit.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/settings/view/widgets/nostr_identity_section.dart';

class _MockNostrIdentityCubit extends MockCubit<NostrIdentityState>
    implements NostrIdentityCubit {}

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

extension on WidgetTester {
  Future<void> pumpSection(NostrIdentityCubit cubit) {
    return pumpWidget(
      MaterialApp(
        home: RepositoryProvider<NostrIdentityRepository>(
          create: (_) => _MockNostrIdentityRepository(),
          child: BlocProvider<NostrIdentityCubit>.value(
            value: cubit,
            child: const Scaffold(body: NostrIdentitySection()),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('NostrIdentitySection', () {
    late NostrIdentityCubit cubit;

    setUp(() {
      cubit = _MockNostrIdentityCubit();
    });

    testWidgets('shows setup prompt when no identity', (tester) async {
      when(() => cubit.state).thenReturn(const NostrIdentityState());

      await tester.pumpSection(cubit);

      expect(find.text('Nostr Identity'), findsOneWidget);
      expect(find.text('Set up your identity'), findsOneWidget);
    });

    testWidgets('shows loading indicator during loading', (tester) async {
      when(() => cubit.state).thenReturn(
        const NostrIdentityState(status: NostrIdentityStatus.loading),
      );

      await tester.pumpSection(cubit);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows npub when identity is ready', (tester) async {
      when(() => cubit.state).thenReturn(
        const NostrIdentityState(
          status: NostrIdentityStatus.ready,
          npub: 'npub1testkey123',
        ),
      );

      await tester.pumpSection(cubit);

      expect(find.text('npub1testkey123'), findsOneWidget);
      expect(find.text('Import different key'), findsOneWidget);
      expect(find.text('Delete identity'), findsOneWidget);
    });

    testWidgets('shows copy icon when identity is ready', (tester) async {
      when(() => cubit.state).thenReturn(
        const NostrIdentityState(
          status: NostrIdentityStatus.ready,
          npub: 'npub1testkey123',
        ),
      );

      await tester.pumpSection(cubit);

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('shows delete confirmation dialog', (tester) async {
      when(() => cubit.state).thenReturn(
        const NostrIdentityState(
          status: NostrIdentityStatus.ready,
          npub: 'npub1testkey123',
        ),
      );

      await tester.pumpSection(cubit);
      await tester.tap(find.text('Delete identity'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Identity'), findsOneWidget);
      expect(
        find.textContaining('Your published results will remain'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('cancel in delete dialog dismisses dialog', (tester) async {
      when(() => cubit.state).thenReturn(
        const NostrIdentityState(
          status: NostrIdentityStatus.ready,
          npub: 'npub1testkey123',
        ),
      );

      await tester.pumpSection(cubit);
      await tester.tap(find.text('Delete identity'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed, npub still visible.
      expect(find.text('npub1testkey123'), findsOneWidget);
      verifyNever(() => cubit.deleteIdentity());
    });

    testWidgets('confirm delete calls deleteIdentity', (tester) async {
      when(() => cubit.state).thenReturn(
        const NostrIdentityState(
          status: NostrIdentityStatus.ready,
          npub: 'npub1testkey123',
        ),
      );
      when(() => cubit.deleteIdentity()).thenAnswer((_) async {});

      await tester.pumpSection(cubit);
      await tester.tap(find.text('Delete identity'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => cubit.deleteIdentity()).called(1);
    });

    testWidgets('shows setup prompt on error state', (tester) async {
      when(() => cubit.state).thenReturn(
        const NostrIdentityState(
          status: NostrIdentityStatus.error,
          errorMessage: 'Something went wrong',
        ),
      );

      await tester.pumpSection(cubit);

      expect(find.text('Set up your identity'), findsOneWidget);
    });
  });
}
