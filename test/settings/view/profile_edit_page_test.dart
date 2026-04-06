import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/profile/profile.dart';
import 'package:very_good_games/settings/view/profile_edit_page.dart';

class _MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

class _MockNostrProfileRepository extends Mock
    implements NostrProfileRepository {}

extension on WidgetTester {
  Future<void> pumpProfileEditPage({
    required ProfileCubit cubit,
    NostrProfile? existingProfile,
  }) async {
    final identityRepo = _MockNostrIdentityRepository();
    final profileRepo = _MockNostrProfileRepository();

    when(identityRepo.getPublicKeyHex).thenAnswer((_) async => 'abc123');
    when(
      () => profileRepo.getProfile('abc123'),
    ).thenAnswer((_) async => existingProfile);

    await pumpWidget(
      MaterialApp(
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<NostrIdentityRepository>(
              create: (_) => identityRepo,
            ),
            RepositoryProvider<NostrProfileRepository>(
              create: (_) => profileRepo,
            ),
          ],
          child: BlocProvider<ProfileCubit>.value(
            value: cubit,
            child: const ProfileEditPage(),
          ),
        ),
      ),
    );
    await pumpAndSettle();
  }
}

void main() {
  group('ProfileEditPage', () {
    late _MockProfileCubit cubit;

    setUp(() {
      cubit = _MockProfileCubit();
      when(() => cubit.state).thenReturn(const ProfileState());
    });

    testWidgets('renders Edit Profile title', (tester) async {
      await tester.pumpProfileEditPage(cubit: cubit);

      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('renders form fields', (tester) async {
      await tester.pumpProfileEditPage(cubit: cubit);

      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Profile Picture URL (optional)'), findsOneWidget);
      expect(find.text('About (optional)'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('pre-populates from existing profile', (tester) async {
      await tester.pumpProfileEditPage(
        cubit: cubit,
        existingProfile: const NostrProfile(
          pubkey: 'abc123',
          name: 'Alice',
          picture: 'https://example.com/pic.jpg',
          about: 'Hello world',
        ),
      );

      expect(find.widgetWithText(TextFormField, 'Alice'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'https://example.com/pic.jpg'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Hello world'), findsOneWidget);
    });

    testWidgets('validates name is required', (tester) async {
      await tester.pumpProfileEditPage(cubit: cubit);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
      verifyNever(
        () => cubit.publishProfile(
          name: any(named: 'name'),
          picture: any(named: 'picture'),
          about: any(named: 'about'),
        ),
      );
    });

    testWidgets('validates picture URL must be https', (tester) async {
      await tester.pumpProfileEditPage(cubit: cubit);

      // Enter a name to pass name validation.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Alice',
      );
      // Enter invalid picture URL.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Profile Picture URL (optional)'),
        'http://insecure.com/pic.jpg',
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Must be an https:// URL'), findsOneWidget);
    });

    testWidgets('calls publishProfile on valid save', (tester) async {
      when(
        () => cubit.publishProfile(
          name: any(named: 'name'),
          picture: any(named: 'picture'),
          about: any(named: 'about'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpProfileEditPage(cubit: cubit);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Name'),
        'Alice',
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(() => cubit.publishProfile(name: 'Alice')).called(1);
    });

    testWidgets('save button exists and is enabled by default', (tester) async {
      await tester.pumpProfileEditPage(cubit: cubit);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });
  });
}
