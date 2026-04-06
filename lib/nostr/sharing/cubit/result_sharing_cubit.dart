import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ndk/ndk.dart';
import 'package:very_good_games/core/daily_seed/date_key.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_publish_repository.dart';

part 'result_sharing_state.dart';

/// A function that builds a Nostr event given the author's public key hex
/// and the date string.
typedef EventBuilderFn =
    Nip01Event Function({required String pubKeyHex, required String date});

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

  /// Cached event builder for retry/resume after identity setup.
  EventBuilderFn? _pendingEventBuilder;

  /// Initiates the share flow with a game-specific [eventBuilder].
  ///
  /// If no identity exists, emits [ResultSharingStatus.checkingIdentity]
  /// so the UI can launch the identity setup flow. Call [publish] after
  /// identity is created.
  Future<void> share({required EventBuilderFn eventBuilder}) async {
    _pendingEventBuilder = eventBuilder;

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
    final eventBuilder = _pendingEventBuilder;
    if (eventBuilder == null) return;

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

      final event = eventBuilder(pubKeyHex: pubKeyHex, date: utcDateKey());
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
