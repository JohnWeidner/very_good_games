---
title: "refactor(nostr): generalize event builder and result sharing for multi-game support"
type: refactor
date: 2026-04-03
---

## refactor(nostr): generalize event builder and result sharing for multi-game support

## Overview

Refactor the Nostr sharing infrastructure to support multiple games. The current `EventBuilder` and `ResultSharingCubit` are hardcoded to Guess the Number. This PR generalizes them so any game can share results without modifying shared code.

This is a backward-compatible refactor — existing Guess the Number behavior is unchanged.

## Problem Statement / Motivation

The `EventBuilder` class has a comment: *"This is intentionally game-specific. Generalize when game #2 arrives."* Game #2 (Signal) has arrived. The current `ResultSharingCubit.share()` method accepts Guess the Number-specific named parameters (`questionCount`, `elapsedSeconds`). Signal has different result data (move count, grid size). Rather than adding game-specific parameters for each new game, generalize the cubit to accept a pre-built event.

## Proposed Solution

### Approach: Cubit accepts `Nip01Event` directly

The simplest generalization: change `ResultSharingCubit.share()` to accept a pre-built `Nip01Event` instead of game-specific parameters. Each game's UI builds its own event via `EventBuilder` and passes it to the cubit. The cubit handles identity checking, signing, and publishing — it never needs to know about game-specific data.

**Before:**
```
ResultsOverlay → ResultSharingCubit.share(score, stars, questionCount, elapsedSeconds, date)
  → EventBuilder.buildGuessTheNumberResult(...)
  → sign + publish
```

**After:**
```
ResultsOverlay → EventBuilder.buildGuessTheNumberResult(...) → Nip01Event
  → ResultSharingCubit.share(event)
  → sign + publish
```

This is a one-method signature change on the cubit, not a new abstraction layer.

### Tasks

#### EventBuilder Changes (`lib/nostr/sharing/event_builder.dart`)

- [ ] Keep existing `buildGuessTheNumberResult` method (no changes)
- [ ] Add `buildSignalResult` static method:
  - Parameters: `pubKeyHex`, `score`, `stars`, `moveCount`, `gridSize` (5 or 6), `date`
  - d-tag: `signal:YYYY-MM-DD`
  - Tags: `['t', 'vgg']`, `['t', 'signal']`, `['L', 'games.vgg.score']`, `['l', 'score-N', 'games.vgg.score']`, `['l', 'moves-N', 'games.vgg.score']`, `['l', 'grid-NxN', 'games.vgg.score']`
  - Content: human-readable summary (e.g., "📡 Very Good Games — Signal\n📡 350 points · ⭐⭐⭐ 3 Stars\n🧱 12 moves · 📐 5x5\n\n2026-04-03")

#### ResultSharingCubit Changes (`lib/nostr/sharing/cubit/result_sharing_cubit.dart`)

- [ ] Change `share()` signature to accept an `Nip01Event` (unsigned) instead of game-specific parameters
- [ ] Remove `_ResultData` private class — no longer needed
- [ ] Store the pending `Nip01Event` directly for retry/resume after identity setup
- [ ] `publish()` signs and publishes the stored event — logic remains the same
- [ ] Update `result_sharing_state.dart` if needed (likely no changes)

#### Guess the Number Migration

- [ ] Update `ResultsOverlay._share()` in [results_overlay.dart](lib/games/guess_the_number/view/widgets/results_overlay.dart):
  - Build the event via `EventBuilder.buildGuessTheNumberResult(...)` in the widget
  - Need to get `pubKeyHex` at call site — retrieve from `NostrIdentityRepository` or pass `null` and let cubit fill it in
  - **Alternative (simpler)**: have `share()` accept event-building parameters plus a builder callback: `share(Nip01Event Function(String pubKeyHex) builder)`. This way the caller provides a function that receives the pub key and returns the event. The cubit calls it after identity check.
- [ ] Verify existing Guess the Number sharing behavior is identical (same event content, same tags, same relay publish flow)

#### CommunityStatsRepository — No Changes Needed

The existing `CommunityStatsRepository.fetchStats(String dTag)` already accepts an arbitrary d-tag string. Signal calls it with `'signal:$date'` and it works out of the box. No changes required.

#### Tests

- [ ] Unit tests for `EventBuilder.buildSignalResult` — verify d-tag, all tags, content format
- [ ] `bloc_test` for updated `ResultSharingCubit.share()` — identity check flow, publish flow, retry flow
- [ ] Verify all existing `ResultSharingCubit` tests still pass (update to new signature)
- [ ] Verify existing `EventBuilder.buildGuessTheNumberResult` tests unchanged
- [ ] Widget test for Guess the Number `ResultsOverlay` still works with new sharing flow
- [ ] All tests pass with `very_good_analysis` v7.0.0

## Technical Considerations

### pubKeyHex Availability at Event Build Time

`EventBuilder` methods require `pubKeyHex` to construct the event. But at call time in the results overlay, identity may not exist yet (the cubit handles the identity-check flow). Two approaches:

1. **Builder callback**: `share(Nip01Event Function(String pubKeyHex) eventBuilder)` — cubit resolves identity, gets pubKeyHex, calls the builder, then signs and publishes. Clean separation.
2. **Two-phase**: caller passes a partial event without pubKey, cubit fills it in. Messier.

Recommend approach 1 (builder callback). It keeps event construction in the caller while letting the cubit handle identity resolution.

### Backward Compatibility

The `share()` signature change is a breaking API change for the cubit. All callers must update. Currently there is one caller: `ResultsOverlay._share()` in Guess the Number. After Part 2, there will be a second caller in Signal's results overlay. If this PR merges before Part 2, only Guess the Number needs updating. If after, both need updating.

## Acceptance Criteria

- [ ] `EventBuilder.buildSignalResult` produces correct kind 30042 event with Signal-specific tags
- [ ] `ResultSharingCubit.share()` accepts a builder callback instead of game-specific parameters
- [ ] Guess the Number sharing works identically after migration (same event content, tags, relay flow)
- [ ] Identity check → setup → resume flow works with new signature
- [ ] Retry on failure works with new signature
- [ ] `CommunityStatsRepository` requires no changes (verified, not assumed)
- [ ] All existing tests pass; no regressions

## Dependencies

- **None** — this PR can merge independently, before or after Part 1 and Part 2.
- If Part 2 has already merged, also update Signal's results overlay to use the generalized API.

## References

- Current EventBuilder: [event_builder.dart](lib/nostr/sharing/event_builder.dart)
- Current ResultSharingCubit: [result_sharing_cubit.dart](lib/nostr/sharing/cubit/result_sharing_cubit.dart)
- Current ResultsOverlay (caller): [results_overlay.dart](lib/games/guess_the_number/view/widgets/results_overlay.dart)
- Nostr event kind 30042 (replaceable): NIP-33
- Brainstorm: [2026-04-03-signal-puzzle-game-brainstorm-doc.md](docs/brainstorm/2026-04-03-signal-puzzle-game-brainstorm-doc.md)
