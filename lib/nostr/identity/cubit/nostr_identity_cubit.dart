import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/sharing/repository/nostr_deletion_repository.dart';

part 'nostr_identity_state.dart';

/// Manages the Nostr identity lifecycle.
///
/// Emits state transitions: none -> loading -> ready/error.
class NostrIdentityCubit extends Cubit<NostrIdentityState> {
  /// Creates a [NostrIdentityCubit].
  NostrIdentityCubit({
    required NostrIdentityRepository identityRepository,
    required NostrDeletionRepository deletionRepository,
    NostrProfileRepository? profileRepository,
  }) : _identityRepository = identityRepository,
       _deletionRepository = deletionRepository,
       _profileRepository = profileRepository,
       super(const NostrIdentityState());

  final NostrIdentityRepository _identityRepository;
  final NostrDeletionRepository _deletionRepository;
  final NostrProfileRepository? _profileRepository;

  /// Loads the current identity from secure storage.
  Future<void> loadIdentity() async {
    emit(state.copyWith(status: NostrIdentityStatus.loading));

    try {
      final npub = await _identityRepository.getPublicKey();
      if (npub != null) {
        emit(
          state.copyWith(status: NostrIdentityStatus.ready, npub: () => npub),
        );
      } else {
        emit(
          state.copyWith(status: NostrIdentityStatus.none, npub: () => null),
        );
      }
    } on Exception catch (e) {
      emit(
        state.copyWith(
          status: NostrIdentityStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Generates a new key pair and stores it.
  ///
  /// On success, emits [NostrIdentityStatus.ready] with the npub and
  /// the nsec so the user can back it up.
  Future<void> generateIdentity() async {
    emit(state.copyWith(status: NostrIdentityStatus.loading));

    try {
      final result = await _identityRepository.generateKeyPair();
      emit(
        state.copyWith(
          status: NostrIdentityStatus.ready,
          npub: () => result.npub,
          nsec: result.nsec,
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          status: NostrIdentityStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Clears the nsec from state after the user has backed it up.
  void clearNsec() {
    emit(state.copyWith());
  }

  /// Imports a key from a bech32-encoded nsec string.
  Future<void> importKey(String nsec) async {
    emit(state.copyWith(status: NostrIdentityStatus.loading));

    try {
      final npub = await _identityRepository.importKey(nsec);
      emit(state.copyWith(status: NostrIdentityStatus.ready, npub: () => npub));

      // Best-effort: fetch existing profile from relays.
      final pubkeyHex = await _identityRepository.getPublicKeyHex();
      if (pubkeyHex != null) {
        await _profileRepository?.getProfile(pubkeyHex);
      }
    } on FormatException {
      emit(
        state.copyWith(
          status: NostrIdentityStatus.error,
          errorMessage: 'Invalid nsec key',
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          status: NostrIdentityStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Deletes the stored identity.
  ///
  /// Attempts best-effort NIP-09 relay content deletion before removing
  /// the local key. The local key is always deleted regardless of relay
  /// outcome.
  Future<void> deleteIdentity() async {
    emit(state.copyWith(status: NostrIdentityStatus.loading));

    try {
      // Obtain signer and pubkey before deleting the local key.
      final signer = await _identityRepository.getSigner();
      final pubKeyHex = await _identityRepository.getPublicKeyHex();

      if (pubKeyHex != null) {
        emit(
          state.copyWith(
            deletionProgress: () => 'Searching for published results...',
          ),
        );

        final eventIds = await _deletionRepository.queryUserEvents(pubKeyHex);

        if (eventIds.isNotEmpty) {
          emit(
            state.copyWith(
              deletionProgress: () =>
                  'Deleting ${eventIds.length} '
                  '${eventIds.length == 1 ? 'result' : 'results'} '
                  'from relays...',
            ),
          );

          await _deletionRepository.deleteEvents(
            eventIds: eventIds,
            signer: signer,
            pubKeyHex: pubKeyHex,
          );
        }
      }
      // Clear cached profile.
      if (pubKeyHex != null) {
        await _profileRepository?.deleteProfile(pubKeyHex);
      }
    } on StateError {
      // getSigner() throws StateError when no identity exists.
    } on Exception {
      // Best-effort: proceed to local key deletion regardless.
    }

    try {
      await _identityRepository.deleteIdentity();
      emit(const NostrIdentityState());
    } on Exception catch (e) {
      emit(
        state.copyWith(
          status: NostrIdentityStatus.error,
          errorMessage: e.toString(),
          deletionProgress: () => null,
        ),
      );
    }
  }
}
