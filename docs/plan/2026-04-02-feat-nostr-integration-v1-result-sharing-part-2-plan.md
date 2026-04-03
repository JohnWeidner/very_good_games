---
title: "feat: add Nostr identity management"
type: feat
date: 2026-04-02
---

## feat: add Nostr identity management

## Overview

Add the core Nostr identity layer: key generation, nsec import, secure storage, signer abstraction, identity explainer flow, and the settings identity section. This PR makes identity generation, import, and deletion functional without any publishing. It also introduces the `ndk` and `flutter_secure_storage` dependencies and initializes the `Ndk` instance.

## Problem Statement / Motivation

Before users can share results to Nostr, they need a cryptographic identity (key pair). This PR delivers the full identity lifecycle -- generate, import, view, delete -- with educational onboarding (the explainer flow) and secure key storage. Separating identity from publishing keeps each PR focused and reviewable.

## Proposed Solution

### New Files

```
lib/
  nostr/
    nostr.dart                          # Barrel file
    identity/
      identity.dart                     # Barrel file
      cubit/
        nostr_identity_cubit.dart
        nostr_identity_state.dart
      view/
        identity_explainer_flow.dart     # 2-3 screen onboarding modal
        identity_setup_page.dart         # Generate / Import
        view.dart                        # Barrel file
      repository/
        nostr_identity_repository.dart
    signing/
      signing.dart                       # Barrel file
      nostr_signer.dart                  # Abstract signer interface
      local_nostr_signer.dart            # v1: wraps Bip340EventSigner
    relay/
      relay_config.dart                  # Default relay URLs as constants
  settings/
    view/
      widgets/
        nostr_identity_section.dart      # Identity display + management
        widgets.dart                     # Barrel file
```

### Changes to Existing Files

| File | Change |
|---|---|
| `pubspec.yaml` | Add `ndk: ^0.8.1`, `flutter_secure_storage: ^9.0.0` |
| `lib/app/app.dart` | Create `Ndk` instance, provide `NostrIdentityRepository` via `RepositoryProvider` |
| `lib/settings/view/settings_page.dart` | Replace placeholder `ListTile` with `NostrIdentitySection` widget |

### Architecture

**Signer abstraction**: `NostrSigner` is an abstract interface with a single `sign(Nip01Event)` method. `LocalNostrSigner` wraps `ndk`'s `Bip340EventSigner`. We use a custom interface rather than ndk's `EventSigner` to decouple app code from ndk types -- a signer swap (bunker, hardware) won't require ndk imports in consuming code. `ResultSharingCubit` (PR 3) will depend on `NostrSigner`, enabling future NIP-46 bunker support without changing sharing code.

**Repository**: `NostrIdentityRepository` wraps `flutter_secure_storage` for all key storage (no dual storage with shared_preferences). It exposes:
- `generateKeyPair()` -- creates a new secp256k1 key pair, stores nsec, returns npub
- `importKey(String nsec)` -- validates bech32, stores, returns npub
- `getPublicKey()` -- returns stored npub (derived from nsec), or null if no identity
- `hasIdentity()` -- reads from secure storage, caches result in-memory after first call
- `deleteIdentity()` -- clears stored key, resets in-memory cache
- `getSigner()` -- returns a `LocalNostrSigner` for the stored key

**Identity state**: `NostrIdentityCubit` manages identity lifecycle with states: `none`, `loading`, `ready(npub)`, `error(message)`.

**Relay config**: Default relay URLs stored as a `List<String>` constant in `relay_config.dart`. All users (generated and imported) use the same 3 defaults in v1. NIP-65 relay discovery deferred to v2.

**NDK initialization**: `Ndk` instance created with `MemCacheManager` and `Bip340EventVerifier`. Verify at implementation time that construction does not eagerly open WebSocket connections.

### Identity Explainer Flow

Full-screen modal route (2-3 screens):
1. "What is Nostr?" -- decentralized protocol, no accounts, no deplatforming
2. "Your Key Pair" -- public key = username, private key = password, but no recovery
3. (Optional) "Why This Matters" -- portable identity, own your data

Shown before first identity creation. Re-shows on every share tap until an identity exists (no separate "seen" flag). Dismissing returns to the previous screen with no identity created.

### Identity Management in Settings

`NostrIdentitySection` widget states:
- **No identity**: "Set up your identity" with setup button -> opens explainer flow
- **Has identity**: Shows npub with copy button, "Import different key" option, "Delete identity" option
- **Import**: Paste nsec in obscured text field, bech32 validated, derived npub shown for confirmation. Overwrite confirmation dialog: "This will replace your current identity. Your previous identity cannot be recovered."
- **Delete**: Confirmation dialog: "Your published results will remain on the network but you won't be able to share new results."

### Security

- Private key stored in `flutter_secure_storage` (iOS Keychain, Android EncryptedSharedPreferences)
- Secure storage write failure shows blocking error dialog
- nsec import: bech32 decode + 32-byte length check before storing
- nsec shown at generation time with "save your key" prompt
- Import uses obscured text field

## Acceptance Criteria

### Repository
- [ ] `generateKeyPair()` creates valid secp256k1 key pair and stores nsec in secure storage
- [ ] `importKey()` validates bech32 nsec, rejects invalid input, stores valid keys
- [ ] `getPublicKey()` returns npub when identity exists, null otherwise
- [ ] `hasIdentity()` returns correct boolean
- [ ] `deleteIdentity()` clears key from secure storage
- [ ] `getSigner()` returns a functional `LocalNostrSigner`
- [ ] Secure storage write failure throws an error the cubit can catch
- [ ] Full unit test coverage for `NostrIdentityRepository`

### Signer
- [ ] `NostrSigner` abstract interface with `sign(Nip01Event)` method
- [ ] `LocalNostrSigner` correctly signs events using `Bip340EventSigner`
- [ ] Full unit test coverage for `LocalNostrSigner`

### Cubit
- [ ] `NostrIdentityCubit` emits correct state transitions: none -> loading -> ready/error
- [ ] Cubit calls repository methods and handles errors
- [ ] Full unit test coverage with `bloc_test`

### Explainer Flow
- [ ] 2-3 screen modal renders with educational content
- [ ] User can proceed to identity setup from the last screen
- [ ] Dismissing (back button / swipe) returns without creating identity
- [ ] Widget tests for screen progression and dismissal

### Settings Integration
- [ ] `NostrIdentitySection` shows setup prompt when no identity exists
- [ ] `NostrIdentitySection` shows npub + management when identity exists
- [ ] Import flow validates nsec and shows confirmation dialog for overwrite
- [ ] Delete flow shows confirmation dialog with correct messaging
- [ ] Widget tests for all section states and interactions

### Barrel Files
- [ ] `lib/nostr/nostr.dart`, `lib/nostr/identity/identity.dart`, `lib/nostr/signing/signing.dart`
- [ ] `lib/settings/view/widgets/widgets.dart`

## Dependencies

- **PR 1** must merge first (settings page exists to host the identity section)

## References

- Settings page: `lib/settings/view/settings_page.dart` (from PR 1)
- ndk package: https://pub.dev/packages/ndk (MIT, v0.8.1)
- ndk EventSigner interface: https://dart-nostr.com/
- NIP-19 (bech32 encoding): https://github.com/nostr-protocol/nips/blob/master/19.md
- Parent plan: `docs/plan/2026-04-02-feat-nostr-integration-v1-result-sharing-plan.md`
