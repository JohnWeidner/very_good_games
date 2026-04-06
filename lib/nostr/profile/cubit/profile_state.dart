part of 'profile_cubit.dart';

/// Status of profile operations.
enum ProfileStatus {
  /// Not yet fetched.
  initial,

  /// Fetching profiles from cache/relays.
  loading,

  /// Profiles loaded.
  loaded,

  /// Publishing profile to relays.
  publishing,

  /// Publish succeeded.
  published,

  /// An error occurred.
  error,
}

/// State for [ProfileCubit].
class ProfileState extends Equatable {
  /// Creates a [ProfileState].
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profiles = const {},
    this.errorMessage,
  });

  /// Current operation status.
  final ProfileStatus status;

  /// Loaded profiles keyed by hex pubkey.
  final Map<String, NostrProfile> profiles;

  /// Error message when [status] is [ProfileStatus.error].
  final String? errorMessage;

  /// Creates a copy with optional field overrides.
  ///
  /// Uses nullable-function wrapper for [errorMessage] so callers can
  /// explicitly clear it (e.g., `copyWith(errorMessage: () => null)`).
  ProfileState copyWith({
    ProfileStatus? status,
    Map<String, NostrProfile>? profiles,
    String? Function()? errorMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profiles: profiles ?? this.profiles,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, profiles, errorMessage];
}
