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
- **Identity explainer**: 1-2 screen walkthrough on first identity setup explaining key pairs, Nostr basics, and decentralized identity. Supports the blog's educational narrative.
- **Event kind**: Custom addressable event (kind 30xxx) with a `d` tag of `daily-{number}` (e.g., `daily-42`). Parameterized replaceable -- one result per user per daily.
- **Note format**: Human-readable text content + NIP-32 self-reported labels for machine-readable stats (stars, questions, time, game ID).
- **Relay strategy**: Ship with 2-3 app-default relays. For users who import an existing identity, discover their NIP-65 relay list and merge with app defaults. New (generated) identities use app defaults only.
- **Social read (v1)**: After completing a daily, display player count and average score fetched from relays. No individual results feed -- that's v2 (follow-graph based).
- **Reading without auth**: Nostr relays are public readers. The app can fetch aggregate stats without the user having an identity. Social data is visible from first play.
- **Package structure**: Single `packages/nostr_client/` package with `identity/`, `relay/`, and `events/` subdirectories. Depends on `ndk` and `flutter_secure_storage`.
- **No auto-share**: User must explicitly tap Share. No automatic publishing.

## Event Structure (Draft)

```jsonc
{
  "kind": 30042,  // TBD -- pick an unused kind in the 30000-39999 range
  "tags": [
    ["d", "guess-the-number:daily-42"],
    ["t", "vgg"],
    ["t", "guess-the-number"],
    ["L", "games.vgg.score"],
    ["l", "stars-3", "games.vgg.score"],
    ["l", "questions-8", "games.vgg.score"],
    ["l", "time-102", "games.vgg.score"]
  ],
  "content": "\ud83c\udfaf Very Good Games \u2014 Guess the Number\n\u2b50\u2b50\u2b50 3 Stars\n\ud83d\udcac 8 questions \u00b7 \u23f1 1:42\n\nDaily #42 \u00b7 2026-04-02",
  "created_at": 1743552000,
  "pubkey": "<user's public key>",
  "sig": "<schnorr signature>"
}
```

## Open Questions

- **Exact kind number**: Need to verify which kind numbers in 30000-39999 are not already claimed by other NIPs/apps. May want to register it.
- **Relay defaults**: Which specific relays to ship with? Should consider reliability, geographic distribution, and free tier limits.
- **Key backup UX**: Should v1 prompt users to back up their nsec, or defer that to a later version? Risk: users lose identity if they reinstall.
- **Rate limiting**: Should we throttle publishing to prevent accidental double-publishes, or does the replaceable event kind handle this naturally?
- **Aggregate stats accuracy**: Relay queries for "all events of this kind with this d tag" may not return complete data if results are spread across relays. How to handle incomplete counts?
- **NIP-65 relay list publishing**: When we generate a new identity, should we publish a NIP-65 relay list event for it, or only read NIP-65 for imported identities?
