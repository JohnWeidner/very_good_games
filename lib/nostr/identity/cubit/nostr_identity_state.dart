part of 'nostr_identity_cubit.dart';

/// The status of the Nostr identity.
enum NostrIdentityStatus {
  /// No identity exists.
  none,

  /// Identity operation in progress.
  loading,

  /// Identity is ready with a valid npub.
  ready,

  /// An error occurred during an identity operation.
  error,
}

/// State for [NostrIdentityCubit].
class NostrIdentityState extends Equatable {
  /// Creates a [NostrIdentityState].
  const NostrIdentityState({
    this.status = NostrIdentityStatus.none,
    this.npub,
    this.nsec,
    this.errorMessage,
    this.deletionProgress,
  });

  /// The current identity status.
  final NostrIdentityStatus status;

  /// The public key in bech32 format, available when [status] is
  /// [NostrIdentityStatus.ready].
  final String? npub;

  /// The private key in bech32 format, only set immediately after generation
  /// so the user can back it up.
  final String? nsec;

  /// Error message when [status] is [NostrIdentityStatus.error].
  final String? errorMessage;

  /// Progress message during relay content deletion.
  ///
  /// Non-null while relay deletion is in progress (e.g. "Found 3 results to
  /// delete", "Deletion request sent").
  final String? deletionProgress;

  /// Creates a copy with the given fields replaced.
  ///
  /// Use nullable-function wrappers to explicitly set fields to null,
  /// e.g. `copyWith(npub: () => null)`.
  NostrIdentityState copyWith({
    NostrIdentityStatus? status,
    String? Function()? npub,
    String? nsec,
    String? errorMessage,
    String? Function()? deletionProgress,
  }) {
    return NostrIdentityState(
      status: status ?? this.status,
      npub: npub != null ? npub() : this.npub,
      nsec: nsec,
      errorMessage: errorMessage,
      deletionProgress: deletionProgress != null
          ? deletionProgress()
          : this.deletionProgress,
    );
  }

  @override
  List<Object?> get props => [
    status,
    npub,
    nsec,
    errorMessage,
    deletionProgress,
  ];
}
