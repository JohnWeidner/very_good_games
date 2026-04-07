import 'dart:async';
import 'dart:convert';

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
  bool _publishInFlight = false;

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
  ///
  /// Uses optimistic updates — emits the updated profile into state
  /// immediately after caching locally, then publishes to relays
  /// in the background with retry.
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

      if (_publishInFlight) return;
      _publishInFlight = true;

      // Build optimistic profile from inputs, preserving unknown fields.
      final existing = state.profiles[pubkeyHex];
      final mergedJson = (existing ?? NostrProfile(pubkey: pubkeyHex))
          .toMergedJson(name: name, picture: picture, about: about);
      final optimisticProfile = NostrProfile(
        pubkey: pubkeyHex,
        name: mergedJson['name'] as String?,
        picture: mergedJson['picture'] as String?,
        about: mergedJson['about'] as String?,
        rawJson: jsonEncode(mergedJson),
        createdAt: existing?.createdAt,
      );

      // Cache optimistic profile locally so re-opens read updated values.
      await _profileRepository.cacheProfile(optimisticProfile);

      // Emit published with optimistic profile — UI pops instantly.
      final merged = Map<String, NostrProfile>.of(state.profiles)
        ..[pubkeyHex] = optimisticProfile;
      emit(state.copyWith(status: ProfileStatus.published, profiles: merged));

      // Fire background publish (unawaited).
      unawaited(
        _backgroundPublish(
          signer: signer,
          pubkeyHex: pubkeyHex,
          name: name,
          picture: picture,
          about: about,
        ),
      );
    } on Exception catch (e) {
      _publishInFlight = false;
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

  Future<void> _backgroundPublish({
    required NostrSigner signer,
    required String pubkeyHex,
    required String? name,
    String? picture,
    String? about,
  }) async {
    try {
      const maxAttempts = 3;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        final success = await _profileRepository.publishProfile(
          signer: signer,
          pubkeyHex: pubkeyHex,
          name: name,
          picture: picture,
          about: about,
        );
        if (success) return;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
      // All retries exhausted — Drift cache has optimistic values;
      // next publish will re-merge.
    } on Exception {
      // Silent failure — logged by repository.
    } finally {
      _publishInFlight = false;
    }
  }
}
