import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndk/ndk.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/sharing/cubit/result_sharing_cubit.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';
import 'package:very_good_games/nostr/signing/signing.dart';

class _MockNostrIdentityRepository extends Mock
    implements NostrIdentityRepository {}

class _MockNostrPublishRepository extends Mock
    implements NostrPublishRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeNip01Event extends Fake implements Nip01Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeNip01Event());
  });

  group('ResultSharingCubit', () {
    late NostrIdentityRepository identityRepository;
    late NostrPublishRepository publishRepository;

    const resultArgs = {
      'score': 350,
      'stars': 2,
      'questionCount': 8,
      'elapsedSeconds': 102,
      'date': '2026-04-02',
    };

    setUp(() {
      identityRepository = _MockNostrIdentityRepository();
      publishRepository = _MockNostrPublishRepository();
    });

    ResultSharingCubit buildCubit() => ResultSharingCubit(
      identityRepository: identityRepository,
      publishRepository: publishRepository,
    );

    test('initial state is initial', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(ResultSharingStatus.initial));
    });

    group('share', () {
      blocTest<ResultSharingCubit, ResultSharingState>(
        'emits checkingIdentity when no identity exists',
        setUp: () {
          when(
            () => identityRepository.hasIdentity(),
          ).thenAnswer((_) async => false);
        },
        build: buildCubit,
        act: (cubit) => cubit.share(
          score: resultArgs['score']! as int,
          stars: resultArgs['stars']! as int,
          questionCount: resultArgs['questionCount']! as int,
          elapsedSeconds: resultArgs['elapsedSeconds']! as int,
          date: resultArgs['date']! as String,
        ),
        expect: () => [
          const ResultSharingState(
            status: ResultSharingStatus.checkingIdentity,
          ),
        ],
      );

      blocTest<ResultSharingCubit, ResultSharingState>(
        'emits [publishing, success] when identity exists and publish succeeds',
        setUp: () {
          when(
            () => identityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);

          final signer = _MockNostrSigner();
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'abc123');
          when(
            () => signer.sign(any()),
          ).thenAnswer((_) async => _FakeNip01Event());
          when(
            () => publishRepository.publish(any()),
          ).thenAnswer((_) async => true);
        },
        build: buildCubit,
        act: (cubit) => cubit.share(
          score: 350,
          stars: 2,
          questionCount: 8,
          elapsedSeconds: 102,
          date: '2026-04-02',
        ),
        expect: () => [
          const ResultSharingState(status: ResultSharingStatus.publishing),
          const ResultSharingState(status: ResultSharingStatus.success),
        ],
      );

      blocTest<ResultSharingCubit, ResultSharingState>(
        'emits [publishing, failure] when publish fails',
        setUp: () {
          when(
            () => identityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);

          final signer = _MockNostrSigner();
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'abc123');
          when(
            () => signer.sign(any()),
          ).thenAnswer((_) async => _FakeNip01Event());
          when(
            () => publishRepository.publish(any()),
          ).thenAnswer((_) async => false);
        },
        build: buildCubit,
        act: (cubit) => cubit.share(
          score: 350,
          stars: 2,
          questionCount: 8,
          elapsedSeconds: 102,
          date: '2026-04-02',
        ),
        expect: () => [
          const ResultSharingState(status: ResultSharingStatus.publishing),
          const ResultSharingState(
            status: ResultSharingStatus.failure,
            errorMessage: 'Could not share your result. Tap to retry.',
          ),
        ],
      );

      blocTest<ResultSharingCubit, ResultSharingState>(
        'emits [publishing, failure] when no public key hex available',
        setUp: () {
          when(
            () => identityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);

          final signer = _MockNostrSigner();
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => null);
        },
        build: buildCubit,
        act: (cubit) => cubit.share(
          score: 350,
          stars: 2,
          questionCount: 8,
          elapsedSeconds: 102,
          date: '2026-04-02',
        ),
        expect: () => [
          const ResultSharingState(status: ResultSharingStatus.publishing),
          const ResultSharingState(
            status: ResultSharingStatus.failure,
            errorMessage: 'No identity available',
          ),
        ],
      );
    });

    group('publish', () {
      blocTest<ResultSharingCubit, ResultSharingState>(
        'does nothing when no pending result',
        build: buildCubit,
        act: (cubit) => cubit.publish(),
        expect: () => <ResultSharingState>[],
      );

      blocTest<ResultSharingCubit, ResultSharingState>(
        'emits [publishing, failure] on generic exception',
        setUp: () {
          when(
            () => identityRepository.hasIdentity(),
          ).thenAnswer((_) async => true);
          when(
            () => identityRepository.getSigner(),
          ).thenThrow(Exception('signing failed'));
        },
        build: buildCubit,
        act: (cubit) => cubit.share(
          score: 350,
          stars: 2,
          questionCount: 8,
          elapsedSeconds: 102,
          date: '2026-04-02',
        ),
        expect: () => [
          const ResultSharingState(status: ResultSharingStatus.publishing),
          const ResultSharingState(
            status: ResultSharingStatus.failure,
            errorMessage: 'Exception: signing failed',
          ),
        ],
      );

      blocTest<ResultSharingCubit, ResultSharingState>(
        'publishes pending result after identity setup',
        setUp: () {
          when(
            () => identityRepository.hasIdentity(),
          ).thenAnswer((_) async => false);

          final signer = _MockNostrSigner();
          when(
            () => identityRepository.getSigner(),
          ).thenAnswer((_) async => signer);
          when(
            () => identityRepository.getPublicKeyHex(),
          ).thenAnswer((_) async => 'abc123');
          when(
            () => signer.sign(any()),
          ).thenAnswer((_) async => _FakeNip01Event());
          when(
            () => publishRepository.publish(any()),
          ).thenAnswer((_) async => true);
        },
        build: buildCubit,
        act: (cubit) async {
          // First call sets pending result but emits checkingIdentity.
          await cubit.share(
            score: 350,
            stars: 2,
            questionCount: 8,
            elapsedSeconds: 102,
            date: '2026-04-02',
          );
          // Simulate identity created, then resume.
          await cubit.publish();
        },
        expect: () => [
          const ResultSharingState(
            status: ResultSharingStatus.checkingIdentity,
          ),
          const ResultSharingState(status: ResultSharingStatus.publishing),
          const ResultSharingState(status: ResultSharingStatus.success),
        ],
      );
    });
  });
}
