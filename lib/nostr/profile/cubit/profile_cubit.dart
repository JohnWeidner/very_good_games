import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:nostr_identity/nostr_identity.dart';

part 'profile_state.dart';

/// Manages Nostr profile data for display (leaderboard, settings).
///
/// Batch-fetches profiles for leaderboard entries and handles
/// profile publishing for the current user.
class ProfileCubit extends Cubit<ProfileState> {
  /// Creates a [ProfileCubit].
  ProfileCubit({
    required NostrProfileRepository profileRepository,
    required NostrIdentityRepository identityRepository,
  }) : _profileRepository = profileRepository,
       _identityRepository = identityRepository,
       super(const ProfileState());

  final NostrProfileRepository _profileRepository;
  final NostrIdentityRepository _identityRepository;

  /// Batch-fetches profiles for the given [pubkeyHexList].
  ///
  /// Merges results into existing profiles (does not clear previous).
  Future<void> fetchProfiles(List<String> pubkeyHexList) async {
    if (pubkeyHexList.isEmpty) return;

    emit(state.copyWith(status: ProfileStatus.loading));

    try {
      final fetched = await _profileRepository.getProfiles(pubkeyHexList);

      final merged = Map<String, NostrProfile>.of(state.profiles)
        ..addAll(fetched);

      emit(state.copyWith(status: ProfileStatus.loaded, profiles: merged));
    } on Exception {
      emit(state.copyWith(status: ProfileStatus.loaded));
    }
  }

  /// Publishes the current user's profile to relays.
  Future<void> publishProfile({
    required String name,
    String? picture,
    String? about,
  }) async {
    emit(state.copyWith(status: ProfileStatus.publishing));

    try {
      final signer = await _identityRepository.getSigner();
      final pubkeyHex = await _identityRepository.getPublicKeyHex();
      if (pubkeyHex == null) {
        emit(
          state.copyWith(
            status: ProfileStatus.error,
            errorMessage: () => 'No identity available',
          ),
        );
        return;
      }

      final success = await _profileRepository.publishProfile(
        signer: signer,
        pubkeyHex: pubkeyHex,
        name: name,
        picture: picture,
        about: about,
      );

      if (success) {
        // Refresh the user's profile in state.
        final updated = await _profileRepository.getProfile(pubkeyHex);
        final merged = Map<String, NostrProfile>.of(state.profiles);
        if (updated != null) merged[pubkeyHex] = updated;

        emit(state.copyWith(status: ProfileStatus.published, profiles: merged));
      } else {
        emit(
          state.copyWith(
            status: ProfileStatus.error,
            errorMessage: () => 'Could not publish profile. Try again.',
          ),
        );
      }
    } on Exception catch (e) {
      emit(
        state.copyWith(status: ProfileStatus.error, errorMessage: e.toString),
      );
    }
  }

  /// Fetches the current user's own profile from relays.
  ///
  /// Used after key import to load existing profile.
  Future<void> fetchOwnProfile() async {
    try {
      final pubkeyHex = await _identityRepository.getPublicKeyHex();
      if (pubkeyHex == null) return;
      await fetchProfiles([pubkeyHex]);
    } on Exception {
      // Best-effort.
    }
  }
}
