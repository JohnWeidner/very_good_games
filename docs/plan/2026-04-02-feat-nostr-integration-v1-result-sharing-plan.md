---
title: "feat: add Nostr result sharing and community stats"
type: feat
date: 2026-04-02
---

## feat: add Nostr result sharing and community stats

> **Note:** This plan has been split into 4 independently-mergeable PRs. The split plans below are the source of truth for implementation. This file serves as a high-level reference and decision log.
>
> - [Part 1](2026-04-02-feat-nostr-integration-v1-result-sharing-part-1-plan.md) -- Settings screen (no dependencies)
> - [Part 2](2026-04-02-feat-nostr-integration-v1-result-sharing-part-2-plan.md) -- Identity management (depends on Part 1)
> - [Part 3](2026-04-02-feat-nostr-integration-v1-result-sharing-part-3-plan.md) -- Result sharing (depends on Part 2)
> - [Part 4](2026-04-02-feat-nostr-integration-v1-result-sharing-part-4-plan.md) -- Community stats (depends on Part 2, independent of Part 3)

## Overview

Add a Nostr-based social layer to Very Good Games that lets players publish daily game results to the Nostr network and view aggregate community stats (player count and average stars) on the results overlay. Identity management (key generation, import, secure storage) is deferred until the user actively wants to share, keeping the game playable without any authentication.

This is the first Nostr integration milestone. It covers publish + aggregate stats only -- no feed UI, profile rendering, or follow-graph logic.

## Event Format (kind 30042)

Custom addressable event with date-based `d` tag for one-result-per-user-per-daily semantics:

```jsonc
{
  "kind": 30042,
  "tags": [
    ["d", "guess-the-number:2026-04-02"],
    ["t", "vgg"],
    ["t", "guess-the-number"],
    ["L", "games.vgg.score"],
    ["l", "stars-3", "games.vgg.score"],
    ["l", "questions-8", "games.vgg.score"],
    ["l", "time-102", "games.vgg.score"]
  ],
  "content": "\ud83c\udfaf Very Good Games \u2014 Guess the Number\n\u2b50\u2b50\u2b50 3 Stars\n\ud83d\udcac 8 questions \u00b7 \u23f1 1:42\n\n2026-04-02",
  "created_at": 1743552000,
  "pubkey": "<user's public key>",
  "sig": "<schnorr signature>"
}
```

## Design Decisions Log

| Decision | Rationale |
|---|---|
| Wins only for sharing | Event format is star-centric (1-3 stars); loss has 0 score and no meaningful star rating |
| Full-screen modal for identity setup | Results overlay is a `Stack` widget, not a route; modal avoids managing multi-screen flows inside a Stack |
| No share after leaving overlay | Simplifies state management; addressable events support re-share if user replays (not currently possible) |
| Explainer reshows until identity exists | Simpler than tracking separate "seen" state; ensures educational content precedes identity creation |
| Blocking error on secure storage failure | Prevents transient identities that fragment user history across pubkeys |
| UTC dates in `d` tag | Matches `DailySeed.forDate()` logic; consistency with game mechanics over local date perception |
| At least 1 relay OK = success | Partial relay failure is the common case with 3 relays; strict all-OK would cause false failures |
| `ndk` over `nostr` package | MIT license (vs LGPL-3.0), actively maintained (v0.8.1 published April 2026), covers all needed capabilities |
| Single app-level `nostr/` directory (not a separate package) | v1 scope is small enough; extract to package when complexity warrants it |
| Custom `NostrSigner` interface (not ndk's `EventSigner`) | Decouples app code from ndk types so a signer swap (bunker, hardware) doesn't require ndk imports in consuming code |
| Key backup nudge after first share | VGV blog recommends surfacing backup prompts at natural pause points rather than deferring entirely |
| Game-specific `EventBuilder` | Only one game exists; generalize when game #2 arrives (YAGNI) |
| Binary relay response handling | Success (at least 1 OK) vs. failure (all fail). Per-category classification deferred to v2 |
| NIP-65 relay discovery deferred to v2 | All users (generated and imported) use 3 default relays. Removes code path from import flow |
| All key data in `flutter_secure_storage` | No dual storage with shared_preferences. `hasIdentity()` reads from secure storage (cached in-memory after first read) |

## Future Considerations (v2+)

- **NIP-46 bunker signing**: Add `BunkerNostrSigner` implementation behind the existing `NostrSigner` interface. Connection via `bunker://` URI (paste or QR scan). Requires handling bunker-unreachable state at share time.
- **NIP-65 relay discovery**: For imported identities, discover their relay list and merge with app defaults.
- **Local outbox queue**: Persist unsigned events locally; sign and publish when connectivity returns.
- **Persistent event cache**: Upgrade from `MemCacheManager` to `ndk_objectbox` for cross-session caching.
- **Key backup flow**: Full export UX (copy nsec, QR code) in Settings.
- **Loss sharing**: If demand exists, add 0-star event format for losses.
- **Result feed**: Show results from followed users (requires NIP-02 follow lists and feed UI).
- **Relay response classification**: Per-category handling (rate-limited, blocked, invalid) with appropriate retry/skip behavior.

## References & Research

- Brainstorm: `docs/brainstorm/2026-04-02-nostr-integration-v1-brainstorm-doc.md`
- Existing results overlay: `lib/games/guess_the_number/view/widgets/results_overlay.dart`
- Daily seed logic: `lib/core/daily_seed/daily_seed.dart`
- Game state model: `lib/games/guess_the_number/cubit/game_state.dart`
- Score calculator: `lib/games/guess_the_number/logic/score_calculator.dart`
- Home page (settings entry point): `lib/home/view/home_page.dart:57`
- Router: `lib/app/routes/routes.dart`
- ndk package: https://pub.dev/packages/ndk (MIT, v0.8.1)
- ndk docs: https://dart-nostr.com/
- NIP-01 (protocol): https://github.com/nostr-protocol/nips/blob/master/01.md
- NIP-32 (labels): https://github.com/nostr-protocol/nips/blob/master/32.md
- NIP-33 (addressable events): https://github.com/nostr-protocol/nips/blob/master/33.md
- NIP-65 (relay lists): https://github.com/nostr-protocol/nips/blob/master/65.md
- NIP-19 (bech32 encoding): https://github.com/nostr-protocol/nips/blob/master/19.md
- Kind registry: https://github.com/nostr-protocol/nips/blob/master/README.md
- Divine-mobile reference: `/Users/john/AndroidStudioProjects/divine-mobile/mobile/packages/nostr_client/`
- VGV blog -- engineering challenges: https://verygood.ventures/blog/building-on-nostr-real-engineering-challenges/
- VGV blog -- what is Nostr: https://verygood.ventures/blog/what-is-nostr/
