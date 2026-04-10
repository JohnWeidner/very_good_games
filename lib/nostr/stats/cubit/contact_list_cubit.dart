import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:nostr_identity/nostr_identity.dart';

part 'contact_list_state.dart';

/// Manages fetching the current user's NIP-02 contact list (follows).
///
/// Used by the leaderboard to show follow indicators and merge
/// followed users' scores.
class ContactListCubit extends Cubit<ContactListState> {
  /// Creates a [ContactListCubit].
  ContactListCubit({
    required ContactListRepository contactListRepository,
    required NostrIdentityRepository identityRepository,
  }) : _contactListRepository = contactListRepository,
       _identityRepository = identityRepository,
       super(const ContactListState());

  final ContactListRepository _contactListRepository;
  final NostrIdentityRepository _identityRepository;

  /// Loads the current user's follows from relays.
  ///
  /// If the user has no identity, emits [ContactListStatus.unavailable].
  Future<void> loadFollows() async {
    try {
      final hasIdentity = await _identityRepository.hasIdentity();
      if (!hasIdentity) {
        emit(state.copyWith(status: ContactListStatus.unavailable));
        return;
      }

      emit(state.copyWith(status: ContactListStatus.loading));

      final pubkeyHex = await _identityRepository.getPublicKeyHex();
      if (pubkeyHex == null) {
        emit(state.copyWith(status: ContactListStatus.unavailable));
        return;
      }

      final contactList = await _contactListRepository.getContactList(
        pubkeyHex,
      );

      if (contactList != null) {
        emit(
          state.copyWith(
            status: ContactListStatus.loaded,
            followedPubkeys: contactList.followedPubkeys,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ContactListStatus.loaded,
            followedPubkeys: const {},
          ),
        );
      }
    } on Exception {
      emit(state.copyWith(status: ContactListStatus.unavailable));
    }
  }
}
