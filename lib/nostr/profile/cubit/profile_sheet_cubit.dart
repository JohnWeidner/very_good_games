import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:nostr_identity/nostr_identity.dart';

part 'profile_sheet_state.dart';

/// Manages loading a single profile for the profile bottom sheet.
class ProfileSheetCubit extends Cubit<ProfileSheetState> {
  /// Creates a [ProfileSheetCubit].
  ProfileSheetCubit({
    required NostrProfileRepository profileRepository,
    required String pubkeyHex,
  }) : _profileRepository = profileRepository,
       _pubkeyHex = pubkeyHex,
       super(const ProfileSheetState());

  final NostrProfileRepository _profileRepository;
  final String _pubkeyHex;

  /// Loads the profile from cache or relays.
  Future<void> loadProfile() async {
    emit(state.copyWith(status: ProfileSheetStatus.loading));

    try {
      final profile = await _profileRepository.getProfile(_pubkeyHex);
      emit(
        state.copyWith(
          status: ProfileSheetStatus.loaded,
          profile: () => profile,
        ),
      );
    } on Exception {
      emit(state.copyWith(status: ProfileSheetStatus.error));
    }
  }

  /// Force-refreshes the profile from relays (bypasses cache).
  Future<void> refreshProfile() async {
    emit(state.copyWith(status: ProfileSheetStatus.loading));

    try {
      final profile = await _profileRepository.getProfile(
        _pubkeyHex,
        forceRefresh: true,
      );
      emit(
        state.copyWith(
          status: ProfileSheetStatus.loaded,
          profile: () => profile,
        ),
      );
    } on Exception {
      emit(state.copyWith(status: ProfileSheetStatus.error));
    }
  }
}
