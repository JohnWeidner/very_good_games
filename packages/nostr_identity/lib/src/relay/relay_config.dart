/// Default relay URLs used for all Nostr operations in v1.
///
/// All users (generated and imported identities) use these same relays.
/// NIP-65 relay discovery is deferred to v2.
const defaultRelayUrls = <String>[
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.nostr.band',
];
