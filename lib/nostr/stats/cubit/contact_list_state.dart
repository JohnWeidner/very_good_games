part of 'contact_list_cubit.dart';

/// Status of contact list fetching.
enum ContactListStatus {
  /// Not yet fetched.
  initial,

  /// Fetching from relays.
  loading,

  /// Contact list loaded (may be empty if user has no follows).
  loaded,

  /// Unavailable (no identity or fetch failed).
  unavailable,
}

/// State for [ContactListCubit].
class ContactListState extends Equatable {
  /// Creates a [ContactListState].
  const ContactListState({
    this.status = ContactListStatus.initial,
    this.followedPubkeys = const {},
  });

  /// Current loading/result status.
  final ContactListStatus status;

  /// Hex pubkeys the current user follows (from kind-3).
  final Set<String> followedPubkeys;

  /// Creates a copy with optional field overrides.
  ContactListState copyWith({
    ContactListStatus? status,
    Set<String>? followedPubkeys,
  }) {
    return ContactListState(
      status: status ?? this.status,
      followedPubkeys: followedPubkeys ?? this.followedPubkeys,
    );
  }

  @override
  List<Object> get props => [status, followedPubkeys];
}
