---
date: 2026-04-03
topic: relay-content-deletion
---

# Relay Content Deletion on Identity Delete

## What We're Building

When a user deletes their Nostr identity, we should attempt to delete their published game results from relays before removing the local key. Currently we only clear the nsec from secure storage — published kind 30042 events remain on relays indefinitely.

The deletion flow will: query relays for the user's events, send NIP-09 (kind 5) deletion requests, show progress, then delete the local key regardless of relay outcome.

## Why This Approach

**Approaches considered:**

1. **NIP-09 only** (chosen) — Query our kind 30042 events, batch-delete with kind 5, then delete local key. Simple, covers our single event kind.
2. **NIP-09 + NIP-62** — Also broadcast a "request to vanish" (kind 62). Overkill for a game app with one event kind.
3. **Warning only** — Just warn that relay content persists. Simplest but doesn't respect user intent.

NIP-09 is the right level: it's the standard Nostr deletion mechanism, relays are expected to honor it, and we only have one event kind to clean up.

## Key Decisions

- **NIP-09 (kind 5) only**: No NIP-62 vanish request. We only publish kind 30042 events, so a single kind 5 deletion event covers everything.
- **Batch by kind (like divine)**: Query all user events, create one kind 5 event with multiple `e` tags for all 30042 events. Not per-event — one deletion event covers all.
- **Progress indicator**: Show "Deleting 3 of 5 results..." during the deletion flow, not just a spinner.
- **Standard confirmation dialog**: Update existing delete dialog messaging to mention relay deletion. No "type DELETE" friction.
- **Best-effort, always delete local key**: If relay deletion partially fails, still delete the local nsec. The user wanted to delete — honor that. Show a warning if relay cleanup was incomplete.
- **Sign before delete**: Must sign the kind 5 event with the nsec *before* deleting it from secure storage.

## Technical Notes from Divine Reference

- Divine queries with `Filter(authors: [pubkey], limit: 10000)` and groups by kind
- Kind 5 event tags: `['e', eventId]` for each event + `['k', '30042']` for the kind
- Success = at least 1 relay accepts (same as our publish pattern)
- Divine uses `Ndk` for both query and broadcast — we already have lazy Ndk in `NostrPublishRepository`

## Open Questions

- Should we share the `Ndk` instance between `NostrPublishRepository`, `CommunityStatsRepository`, and the new deletion logic? Or keep them independent with their own lazy instances?
- Should deletion logic live in `NostrIdentityRepository` (it owns the key lifecycle) or in a separate `NostrDeletionRepository`?
