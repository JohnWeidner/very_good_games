---
date: 2026-04-07
topic: optimistic-profile-updates
---

# Optimistic Profile Updates

## What We're Building

When a user saves their Nostr profile (kind-0 event), the UI should update immediately rather than waiting for relay confirmation. Today the profile edit page shows a spinner and blocks until at least one relay responds with an `OK` message, which feels sluggish even though publishes rarely fail.

The change is scoped to profile updates only. The same pattern could be extended to result sharing later, but that's out of scope for this iteration.

## Why This Approach

**Approach A: Optimistic Cubit State** was chosen over a separate "pending sync" state because:

- Nostr kind-0 events are self-authenticating (signed locally) and replaceable (relays keep only the latest per pubkey). The event is valid the moment it's signed — the relay is just distribution.
- Relay failures are rare in practice. The user's pain point is perceived slowness, not actual failures.
- A "pending sync" state would add new enum values, UI states, and test surface for a failure mode the user almost never sees.

The Nostr protocol's `OK` message is the definitive confirmation — re-querying relays after publishing is unnecessary. Most Nostr clients (Damus, Primal, Amethyst) use this same optimistic pattern.

## Key Decisions

- **Scope: profile updates only.** Result sharing and other relay interactions are out of scope.
- **Optimistic Cubit State (Approach A):** `ProfileCubit.publishProfile` will emit the updated profile into state immediately after signing, update the Drift cache, and fire the relay broadcast in the background.
- **Silent retry on failure:** If the background relay publish fails, retry automatically. Only log — no user-facing error unless all retries are exhausted.
- **No re-fetch after publish:** The current code re-fetches the profile from the repository after a successful publish. This is redundant since the repository already cached it. The optimistic approach constructs the updated state from the values it already has.
- **Preserve `toMergedJson` pattern:** The read-then-merge must still happen to preserve unknown fields from other Nostr clients. The optimistic UI shows the user's new `name`/`picture`/`about` immediately; the merge happens as part of the background publish.

## Open Questions

- What's the right retry strategy? Simple fixed-delay retry (e.g., 3 attempts, 5s apart) or exponential backoff? Likely simple retry is sufficient given low failure rates.
- Should we log failed publish attempts for observability, or is it enough to just retry silently?
- If the merge step (read existing profile from relay/cache) fails, should we still attempt to publish with just the new fields, or block until we can merge?
