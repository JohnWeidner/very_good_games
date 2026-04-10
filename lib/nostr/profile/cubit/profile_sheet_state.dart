part of 'profile_sheet_cubit.dart';

/// Status of profile sheet loading.
enum ProfileSheetStatus {
  /// Not yet fetched.
  initial,

  /// Fetching profile from cache/relays.
  loading,

  /// Profile loaded (may be null if not found).
  loaded,

  /// An error occurred.
  error,
}

/// State for [ProfileSheetCubit].
class ProfileSheetState extends Equatable {
  /// Creates a [ProfileSheetState].
  const ProfileSheetState({
    this.status = ProfileSheetStatus.initial,
    this.profile,
  });

  /// Current loading status.
  final ProfileSheetStatus status;

  /// The loaded profile, available when [status] is
  /// [ProfileSheetStatus.loaded].
  final NostrProfile? profile;

  /// Creates a copy with optional field overrides.
  ///
  /// Uses `NostrProfile? Function()?` wrapper for nullable [profile]
  /// so callers can explicitly set it to null.
  ProfileSheetState copyWith({
    ProfileSheetStatus? status,
    NostrProfile? Function()? profile,
  }) {
    return ProfileSheetState(
      status: status ?? this.status,
      profile: profile != null ? profile() : this.profile,
    );
  }

  @override
  List<Object?> get props => [status, profile];
}
