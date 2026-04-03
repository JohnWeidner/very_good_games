part of 'result_sharing_cubit.dart';

/// The status of the result sharing flow.
enum ResultSharingStatus {
  /// No share action in progress.
  initial,

  /// Checking whether the user has a Nostr identity.
  checkingIdentity,

  /// Publishing the result to relays.
  publishing,

  /// Result successfully published.
  success,

  /// Publishing failed.
  failure,
}

/// State for [ResultSharingCubit].
class ResultSharingState extends Equatable {
  /// Creates a [ResultSharingState].
  const ResultSharingState({
    this.status = ResultSharingStatus.initial,
    this.errorMessage,
  });

  /// The current sharing status.
  final ResultSharingStatus status;

  /// Error message when [status] is [ResultSharingStatus.failure].
  final String? errorMessage;

  /// Creates a copy with the given fields replaced.
  ResultSharingState copyWith({
    ResultSharingStatus? status,
    String? errorMessage,
  }) {
    return ResultSharingState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
