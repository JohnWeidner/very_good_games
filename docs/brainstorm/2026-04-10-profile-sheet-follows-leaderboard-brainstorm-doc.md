---
date: 2026-04-10
topic: profile-sheet-follows-leaderboard
---

# Profile View & Follows-Aware Leaderboard

## What We're Building

A profile bottom sheet that opens when tapping a leaderboard row, displaying another user's Nostr profile (name, avatar, about, NIP-05, Lightning address), a "last updated" timestamp, a manual refresh button, and a "View on Nostr" external link. The app is read-only for profile and social data — users manage their identity and social graph in their preferred Nostr client.

Alongside this, the leaderboard becomes follows-aware: it reads the current user's NIP-02 contact list (kind-3 event) from relays, queries game scores for followed users, and merges them into a single deduplicated list with global top scores. Followed users are marked with a subtle indicator icon. The profile cache staleness extends from 24 hours to 7 days, since manual refresh is now available.

## Why This Approach

Three approaches were considered:

1. **Profile sheet only** — Smallest scope but misses the leaderboard improvement. The profile sheet has limited value without social context.
2. **Profile sheet + follows-aware leaderboard (chosen)** — Delivers the full value. The leaderboard becomes interesting because users see scores from people they know alongside global top performers. The kind-3 contact list is read-only from relays, keeping scope manageable.
3. **Full social foundation** — Adds in-app follow/unfollow, zap integration, and activity feeds. Too much scope — publishing kind-3 events risks overwriting a user's follow list, and the app is a puzzle game, not a social client.

The guiding principle: the app is a *window* into Nostr social data, not a Nostr client. Read from relays, link out for actions.

## Key Decisions

- **Profile view is a modal bottom sheet**: Keeps the user in the results overlay context. A full-page navigation would break flow and require state restoration. The sheet is a "quick peek" that matches the use case.
- **Read-only + external link**: Profile data is displayed but not editable (except the user's own profile in Settings). A "View on Nostr" link opens the user's npub in a web client (e.g., njump.me). Future social actions (follow, message) would also deep-link out rather than being built in-app.
- **Profile fields displayed**: Name, picture/avatar, about/bio, NIP-05 verification identifier, and Lightning address (lud16). NIP-05 and lud16 are already preserved in `rawJson` — they just need to be extracted and displayed. No new kind-0 fields need to be parsed or stored.
- **"Updated X ago" + refresh button**: A subtle timestamp at the bottom of the profile card shows when data was last fetched from a relay. A refresh icon button forces a fresh relay fetch regardless of cache age. This gives users control over freshness without auto-refreshing every time.
- **Follow status shown on profile sheet**: A "Following" badge appears on the profile sheet if the viewed user is in the current user's kind-3 contact list. Read-only — no in-app follow/unfollow action.
- **Cache staleness extended to 7 days**: With manual refresh available, aggressive auto-refreshing is unnecessary. A daily-play app doesn't need sub-day profile freshness. This cuts relay traffic ~7x.
- **Follows source is kind-3 from relays**: The user's NIP-02 contact list is fetched from relays (read-only). Users manage who they follow in their dedicated Nostr client. No in-app follow management. The contact list should also be cached (kind-3 changes infrequently).
- **Single merged leaderboard list**: No tabs or sections. Global top scores and followed users' scores are merged into one deduplicated list, sorted by score. Followed users get a subtle indicator icon (e.g., person-check) next to their name. This treats the leaderboard as "interesting scores we found" rather than an authoritative ranking — appropriate given relay data is best-effort.

## Open Questions

- Which web client should the "View on Nostr" link open? Options: njump.me (web, universal), primal.net (web, popular), or a configurable/user-selectable option. Simplest is njump.me since it works without an account.
- Should NIP-05 and lud16 be promoted to first-class fields on `NostrProfile` (parsed from `rawJson` on construction), or extracted on-demand in the profile sheet UI? First-class fields are cleaner but widen the model.
- How many followed users' scores should be fetched? If a user follows 500 people, querying all of them is expensive. A reasonable cap (e.g., most recent 50-100 contacts) may be needed.
- Should the kind-3 contact list be cached in Drift alongside profiles, or in a separate lightweight store? It's a single event per user, so the storage strategy is simple either way.
- What happens when the user has no identity (no Nostr keys)? The leaderboard currently shows global scores only. With follows integration, it should gracefully degrade: show global scores, no follow indicators, and tapping a row still opens the profile sheet (just without a "Following" badge).
- The current `_staleDuration` is a private constant in `NostrProfileRepository`. Should it become a configurable parameter (injected or constructor argument) to support the 7-day change cleanly, or just change the constant?
