import 'package:equatable/equatable.dart';

/// A user's NIP-02 contact list (kind-3) parsed from a relay event.
class ContactList extends Equatable {
  /// Creates a [ContactList].
  const ContactList({
    required this.ownerPubkey,
    required this.followedPubkeys,
    required this.fetchedAt,
  });

  /// Hex pubkey of the contact list owner.
  final String ownerPubkey;

  /// Hex pubkeys from kind-3 `p` tags.
  final Set<String> followedPubkeys;

  /// Unix seconds when this contact list was fetched.
  final int fetchedAt;

  @override
  List<Object> get props => [ownerPubkey, followedPubkeys, fetchedAt];
}
