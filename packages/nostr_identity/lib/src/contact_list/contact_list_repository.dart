import 'package:ndk/ndk.dart' hide ContactList;
import 'package:nostr_identity/src/contact_list/contact_list.dart';
import 'package:nostr_identity/src/relay/ndk_provider.dart';
import 'package:nostr_identity/src/relay/relay_config.dart';

/// Repository for fetching NIP-02 contact lists (kind-3) from relays.
///
/// Uses an in-memory cache with 24-hour staleness. Contact lists change
/// more frequently than profiles so a shorter TTL is appropriate.
class ContactListRepository {
  /// Creates a [ContactListRepository].
  ContactListRepository({required NdkProvider ndkProvider})
    : _ndkProvider = ndkProvider;

  final NdkProvider _ndkProvider;

  static const _staleDuration = Duration(hours: 24);
  static const _relayTimeout = Duration(seconds: 5);

  /// Maximum number of followed pubkeys to retain per contact list.
  ///
  /// Takes from the end of the list per NIP-02 append ordering,
  /// so the most recently followed contacts are kept.
  static const _maxContacts = 150;

  /// In-memory cache keyed by owner pubkey.
  final _cache = <String, ContactList>{};

  /// Fetches the contact list for [pubkeyHex].
  ///
  /// Returns cached if fresh (< 24h), else queries relays.
  /// Returns `null` if not found or relay timeout.
  Future<ContactList?> getContactList(String pubkeyHex) async {
    final cached = _cache[pubkeyHex];
    if (cached != null && _isFresh(cached.fetchedAt)) {
      return cached;
    }

    return _fetchFromRelay(pubkeyHex);
  }

  /// Bypasses cache and re-fetches the contact list from relays.
  Future<ContactList?> forceRefresh(String pubkeyHex) async {
    return _fetchFromRelay(pubkeyHex);
  }

  bool _isFresh(int fetchedAt) {
    final fetched = DateTime.fromMillisecondsSinceEpoch(fetchedAt * 1000);
    return DateTime.now().toUtc().difference(fetched) < _staleDuration;
  }

  Future<ContactList?> _fetchFromRelay(String pubkeyHex) async {
    try {
      final response = _ndkProvider.ndk.requests.query(
        filter: Filter(authors: [pubkeyHex], kinds: [3], limit: 1),
        explicitRelays: defaultRelayUrls,
        cacheRead: false,
        cacheWrite: false,
      );

      final events = await response.future.timeout(_relayTimeout);

      if (events.isEmpty) return null;

      final event = events.first;
      final pTags = event.tags
          .where((t) => t.isNotEmpty && t[0] == 'p' && t.length >= 2)
          .map((t) => t[1])
          .toList();

      // Take from the end (most recently followed per NIP-02 ordering).
      final capped = pTags.length > _maxContacts
          ? pTags.sublist(pTags.length - _maxContacts)
          : pTags;

      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final contactList = ContactList(
        ownerPubkey: pubkeyHex,
        followedPubkeys: capped.toSet(),
        fetchedAt: now,
      );

      _cache[pubkeyHex] = contactList;
      return contactList;
    } on Exception {
      return null;
    }
  }
}
