import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:very_good_games/nostr/identity/repository/nostr_identity_repository.dart';

part 'nostr_identity_state.dart';

/// Manages the Nostr identity lifecycle.
///
/// Emits state transitions: none -> loading -> ready/error.
class NostrIdentityCubit extends Cubit<NostrIdentityState> {
  /// Creates a [NostrIdentityCubit].
  NostrIdentityCubit({required NostrIdentityRepository identityRepository})
    : _identityRepository = identityRepository,
      super(const NostrIdentityState());

  final NostrIdentityRepository _identityRepository;

  /// Loads the current identity from secure storage.
  Future<void> loadIdentity() async {
    emit(state.copyWith(status: NostrIdentityStatus.loading));

    try {
      final npub = await _identityRepository.getPublicKey();
      if (npub != null) {
        emit(state.copyWith(status: NostrIdentityStatus.ready, npub: npub));
      } else {
        emit(state.copyWith(status: NostrIdentityStatus.none, clearNpub: true));
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
          npub: result.npub,
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

  /// Imports a key from a bech32-encoded nsec string.
  Future<void> importKey(String nsec) async {
    emit(state.copyWith(status: NostrIdentityStatus.loading));

    try {
      final npub = await _identityRepository.importKey(nsec);
      emit(state.copyWith(status: NostrIdentityStatus.ready, npub: npub));
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
  Future<void> deleteIdentity() async {
    emit(state.copyWith(status: NostrIdentityStatus.loading));

    try {
      await _identityRepository.deleteIdentity();
      emit(const NostrIdentityState());
    } on Exception catch (e) {
      emit(
        state.copyWith(
          status: NostrIdentityStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
