---
topic: Nostr User Profiles + Package Extraction
date: 2026-04-06
status: complete
---

# Nostr User Profiles + Reusable Identity Package

## Problem Statement

Users currently appear as truncated npubs (e.g., `npub1abc...`) on leaderboards and throughout the app. There's no way to associate a name, picture, or bio with a Nostr identity. Additionally, all Nostr-related code lives inside the app — other developers can't reuse the identity/signing/relay infrastructure.

## Goals

1. Let users **set** their profile: name, picture (URL), about
2. Let the app **read** other users' profiles (for leaderboard display names, avatars)
3. Extract generic Nostr identity functionality into a **reusable package** at `packages/nostr_identity/`

## Key Decisions

### 1. Full Read + Write Profile Support

Users can both edit their own profile (publish kind-0 events) and the app reads other users' profiles (query kind-0 by pubkey). This enables rich leaderboard display and a complete profile editing flow.

### 2. Package Scope: Identity + Profile

The `nostr_identity` package covers:
- **Key management**: generate, import (nsec), store, delete
- **Signer abstraction**: `NostrSigner` interface + `LocalNostrSigner`
- **Profile metadata**: kind-0 read/write (NIP-01)
- **Relay communication**: shared `NdkProvider`, relay config

Out of scope for the package (stays in app):
- Game-specific event building (`EventBuilder`)
- Community stats/leaderboard queries (kind 30042)
- Result sharing UI (`ResultSharingListener`, `ShareResultButton`)
- Game cubits and views

### 3. Package Location: Monorepo

`packages/nostr_identity/` inside the current repo. Easy to develop alongside the app, single PR workflow. Can publish to pub.dev later when the API stabilizes.

### 4. v1 Profile Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | String | Yes | Nickname or full name |
| `picture` | String (URL) | No | Profile image URL |
| `about` | String | No | Short bio |

Additional NIP-01/NIP-24 fields (`display_name`, `nip05`, `banner`, `website`, `lud16`) deferred to v2.

### 5. Profile Picture: URL Now, Upload Later

v1: User pastes an image URL (hosted on nostr.build, imgur, etc.)
v2: In-app image picker with NIP-96 upload to nostr.build or similar.

### 6. Key Storage: Package Owns It

The package manages `FlutterSecureStorage` internally. Consumer apps call `generateKeyPair()` / `importKey()` without worrying about storage details.

### 7. Approach: Extract-and-Build

1. Extract existing `lib/nostr/identity/`, `lib/nostr/signing/`, `lib/nostr/relay/` into `packages/nostr_identity/`
2. Update app imports to use the package
3. Build kind-0 profile support (read + write) in the package
4. Integrate profile data into the app (leaderboard names, profile editing screen)

## Protocol Reference (NIP-01 Kind 0)

Kind 0 is a **replaceable** event — relays store only the latest per pubkey.

**Content format** (stringified JSON):
```json
{
  "name": "<nickname>",
  "about": "<short bio>",
  "picture": "<URL of profile picture>"
}
```

**Reading a profile**: Query `filter: {kinds: [0], authors: [pubkeyHex]}`
**Writing a profile**: Sign and publish a kind-0 event with profile JSON as content. Relays replace the old one automatically.

**Client behavior**:
- Cache profiles locally for known users
- Update cache when newer events are received
- Use fallback (truncated npub) when fields are missing

## Package Structure (Proposed)

```
packages/nostr_identity/
  lib/
    nostr_identity.dart          # barrel file
    src/
      identity/
        nostr_identity_repository.dart  # key lifecycle (generate, import, delete)
      signing/
        nostr_signer.dart               # signer interface
        local_nostr_signer.dart         # local key signer
      profile/
        nostr_profile.dart              # profile model (name, picture, about)
        nostr_profile_repository.dart   # kind-0 read/write + cache
      database/
        nostr_database.dart             # Drift database definition
        profile_dao.dart                # profile table + upsert/query
      relay/
        ndk_provider.dart               # shared NDK instance
        relay_config.dart               # default relay URLs
  test/
    ...
  pubspec.yaml                   # depends on ndk, flutter_secure_storage, drift
```

## App Integration Points

1. **Leaderboard**: Replace `LeaderboardEntry.displayName` (truncated npub) with actual profile name + avatar
2. **Profile screen**: New screen in Settings for editing name, picture URL, about
3. **Profile caching**: Cache fetched profiles to avoid repeated relay queries
4. **Import migration**: Update all `import 'package:very_good_games/nostr/identity/...'` to `import 'package:nostr_identity/...'`

## Refined Decisions (from review)

### 8. Flutter Package (not pure Dart)

The package depends on `ndk` and `flutter_secure_storage`, making it a Flutter package. This is intentional — the target audience is Flutter app developers building Nostr-integrated apps.

### 9. Persistent Profile Cache (Drift/SQLite)

Profiles are cached in a local database (Drift) with upsert semantics, matching divine-mobile's pattern. This enables:
- Instant profile display on app relaunch (no relay roundtrip)
- Batch queries: fetch multiple profiles in one relay request (`authors: [list]`)
- Upsert on newer events: update cache when fresher kind-0 events arrive
- Offline fallback: show cached profiles when relays are unavailable

The package owns the database — consumers don't need to set up their own.

Reference: divine-mobile uses `UserProfilesDao.upsertProfile()` backed by a Drift `UserProfiles` table, with profiles parsed from kind-0 events via `UserProfile.fromNostrEvent()`.

### 10. Profile Fetch Failures

Fallback to truncated npub when profile data is unavailable. The existing `LeaderboardEntry.displayName` pattern already handles this — the package just needs to provide a way to look up profiles by pubkey, returning null when not cached.

## Resolved Questions

- **Cache strategy**: Persistent Drift/SQLite database (not in-memory)
- **Fetch failures**: Fallback to truncated npub (existing pattern)
- **Package widgets**: Data only in v1. App owns profile UI. Widgets deferred to v2.

## Out of Scope (Future)

- NIP-05 verification (DNS-based identity)
- NIP-96 image upload
- NIP-46 bunker/remote signing
- NIP-65 relay discovery
- Lightning address / zaps (lud16)
- `display_name`, `banner`, `website` fields
