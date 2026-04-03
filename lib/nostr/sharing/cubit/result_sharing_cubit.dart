import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/sharing/event_builder.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';

part 'result_sharing_state.dart';

/// Manages the share-to-Nostr flow for game results.
///
/// States: initial -> checkingIdentity/publishing -> success/failure.
class ResultSharingCubit extends Cubit<ResultSharingState> {
  /// Creates a [ResultSharingCubit].
  ResultSharingCubit({
    required NostrIdentityRepository identityRepository,
    required NostrPublishRepository publishRepository,
  }) : _identityRepository = identityRepository,
       _publishRepository = publishRepository,
       super(const ResultSharingState());

  final NostrIdentityRepository _identityRepository;
  final NostrPublishRepository _publishRepository;

  /// Cached result data for retry/resume after identity setup.
  _ResultData? _pendingResult;

  /// Initiates the share flow.
  ///
  /// If no identity exists, emits [ResultSharingStatus.checkingIdentity]
  /// so the UI can launch the identity setup flow. Call [publish] after
  /// identity is created.
  Future<void> share({
    required int score,
    required int stars,
    required int questionCount,
    required int elapsedSeconds,
    required String date,
  }) async {
    _pendingResult = _ResultData(
      score: score,
      stars: stars,
      questionCount: questionCount,
      elapsedSeconds: elapsedSeconds,
      date: date,
    );

    final hasIdentity = await _identityRepository.hasIdentity();
    if (!hasIdentity) {
      emit(state.copyWith(status: ResultSharingStatus.checkingIdentity));
      return;
    }

    await publish();
  }

  /// Publishes the pending result to Nostr relays.
  ///
  /// Called directly when identity already exists, or after identity
  /// setup completes.
  Future<void> publish() async {
    final result = _pendingResult;
    if (result == null) return;

    emit(state.copyWith(status: ResultSharingStatus.publishing));

    try {
      final signer = await _identityRepository.getSigner();
      final pubKeyHex = await _identityRepository.getPublicKeyHex();
      if (pubKeyHex == null) {
        emit(
          state.copyWith(
            status: ResultSharingStatus.failure,
            errorMessage: 'No identity available',
          ),
        );
        return;
      }

      final event = EventBuilder.buildGuessTheNumberResult(
        pubKeyHex: pubKeyHex,
        score: result.score,
        stars: result.stars,
        questionCount: result.questionCount,
        elapsedSeconds: result.elapsedSeconds,
        date: result.date,
      );

      final signedEvent = await signer.sign(event);
      final success = await _publishRepository.publish(signedEvent);

      if (success) {
        emit(state.copyWith(status: ResultSharingStatus.success));
      } else {
        emit(
          state.copyWith(
            status: ResultSharingStatus.failure,
            errorMessage: 'Could not share your result. Tap to retry.',
          ),
        );
      }
    } on Exception catch (e) {
      emit(
        state.copyWith(
          status: ResultSharingStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}

class _ResultData {
  const _ResultData({
    required this.score,
    required this.stars,
    required this.questionCount,
    required this.elapsedSeconds,
    required this.date,
  });

  final int score;
  final int stars;
  final int questionCount;
  final int elapsedSeconds;
  final String date;
}
