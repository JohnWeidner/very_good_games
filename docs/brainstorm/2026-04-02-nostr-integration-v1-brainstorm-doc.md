---
date: 2026-04-02
topic: nostr-integration-v1
---

# Nostr Integration v1 -- Result Sharing

## What We're Building

A Nostr-based social layer for Very Good Games that lets players publish their daily game results to the Nostr network and see aggregate community stats (player count and average score) for each daily puzzle. Identity management (key generation, import, secure storage) lives in a dedicated package, and the app defers identity setup until the user actively wants to share -- keeping the game playable without any authentication.

When a user first sets up their Nostr identity, they see a brief explainer walkthrough (1-2 screens) covering what key pairs are, what Nostr is, and why decentralized identity matters. This supports the "learn by doing" educational goal of the project.

## Why This Approach

We considered three scopes: publish-only (no reading), publish + count, and publish + full feed. We chose **publish + aggregate stats** because it gives a sense of community (how many people played, average score) without requiring a feed UI, profile rendering, or follow-graph logic. A future version will add a feed of results from followed users.

For event format, we chose a **custom addressable kind (30xxx range)** over kind 1 text notes. This avoids polluting users' general Nostr feeds with game posts, gives us one-result-per-daily-per-user semantics via the `d` tag, and makes results machine-queryable for future leaderboards. Self-reported NIP-32 labels on the event provide structured scoring data alongside human-readable content.

## Key Decisions

- **Share UX**: Explicit "Share to Nostr" button on the results overlay, always visible. If no identity exists, tapping it triggers identity setup inline.
- **Identity setup**: Two paths -- (1) dedicated "Nostr Identity" section in settings for proactive setup, (2) inline setup flow when tapping Share for the first time. Both offer "Generate new identity" or "Import existing key (nsec)".
- **Identity explainer**: Multi-screen onboarding flow (2-3 full screens with illustrations) shown once before first identity creation. Covers: what Nostr is, what key pairs are, and why decentralized identity matters. Blocking on first identity setup -- user must complete or dismiss before proceeding. Supports the blog's educational narrative.
- **Event kind**: Custom addressable event (kind 30xxx) with a date-based `d` tag: `guess-the-number:2026-04-02`. Parameterized replaceable -- one result per user per daily. The date format matches the daily seed logic and is human-readable.
- **Note format**: Human-readable text content + NIP-32 self-reported labels for machine-readable stats (stars, questions, time, game ID).
- **Relay strategy**: Ship with 2-3 app-default relays. For users who import an existing identity, discover their NIP-65 relay list and merge with app defaults. New (generated) identities use app defaults only.
- **Aggregate stats**: After completing a daily, the results overlay shows approximate community stats ("100+ players, ~2.5 avg stars"). Stats are computed client-side from a sampled relay query (limit 100 most recent results). Nostr relays return individual events, not aggregates -- the client fetches, deduplicates by pubkey, and computes. The limit-100 sample caps data transfer at ~50KB regardless of player count.
- **Reading without auth**: Nostr relays are public readers. The app can fetch aggregate stats without the user having an identity. Social data is visible from first play.
- **Package structure**: Single `packages/nostr_client/` package with `identity/`, `relay/`, and `events/` subdirectories. Depends on `ndk` (for WebSocket lifecycle, event signing, NIP-65 discovery) and `flutter_secure_storage` (for key storage).
- **No auto-share**: User must explicitly tap Share. No automatic publishing.
- **Error handling (v1)**: Share failures (offline, relay rejection) show a snackbar with a retry option. Aggregate stat fetches fail silently -- the stats section is hidden if no data is available.
- **Settings screen**: A new settings screen (accessible from the home page) is a prerequisite. It hosts the "Nostr Identity" section for proactive identity management (view public key, import/export, delete identity).
- **Game-agnostic event design**: The event format is designed to work across multiple games. The game name appears in the `d` tag (`guess-the-number:2026-04-02`) and `t` tags, while the `l` tag namespace (`games.vgg.score`) is shared. When new games ship, they use the same kind and namespace with their own `d` tag prefix and `t` tag.

## Event Structure (Draft)

```jsonc
{
  "kind": 30042,  // TBD -- pick an unused kind in the 30000-39999 range
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

## Open Questions

- **Exact kind number**: Need to verify which kind numbers in 30000-39999 are not already claimed by other NIPs/apps. May want to register it.
- **Relay defaults**: Which specific relays to ship with? Should consider reliability, geographic distribution, and free tier limits.
- **`ndk` package validation**: The package architecture assumes `ndk` handles WebSocket lifecycle, event signing, and NIP-65 relay list discovery. This needs to be verified before planning — if `ndk` doesn't cover these, the fallback is using the lower-level `nostr` package (LGPL-3.0 license concern) or implementing WebSocket/signing directly with `web_socket_channel` + `pointycastle`.

## Resolved During Brainstorm

- **Rate limiting**: Not needed — addressable (replaceable) events overwrite on re-publish by design.
- **Key backup UX**: Deferred to v2. The threat model (game app, low-value identity) doesn't justify the UX overhead in v1.
- **NIP-65 for generated identities**: Not needed in v1. Generated keys exist only in-app; no external client will discover them.
- **Aggregate stats accuracy**: Handled by showing approximate stats from a limit-100 sample. The UI uses "~" and "+" language to set expectations.
