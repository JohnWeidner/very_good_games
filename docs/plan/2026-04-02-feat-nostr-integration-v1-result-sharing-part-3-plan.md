---
title: "feat: add Nostr result sharing"
type: feat
date: 2026-04-02
---

## feat: add Nostr result sharing

## Overview

Add the "Share to Nostr" button on the win results overlay, a `ResultSharingCubit` for the publish lifecycle, an `EventBuilder` for constructing kind 30042 events, and a `NostrPublishRepository` wrapping `Ndk` relay writes. Tapping share triggers the identity explainer/setup flow (from PR 2) if no identity exists, then publishes the result.

## Problem Statement / Motivation

With identity management in place (PR 2), users can now publish their daily game results to the Nostr network. This is the core social action of the feature -- sharing a result makes it visible to the community and contributes to aggregate stats.

## Proposed Solution

### New Files

```
lib/
  nostr/
    sharing/
      sharing.dart                      # Barrel file
      cubit/
        result_sharing_cubit.dart
        result_sharing_state.dart
      repository/
        nostr_publish_repository.dart    # Wraps Ndk relay write operations
      event_builder.dart                # Builds kind 30042 events for Guess the Number
```

### Changes to Existing Files

| File | Change |
|---|---|
| `lib/games/guess_the_number/logic/score_calculator.dart` | Add `stars(int score)` static method (extract from `_StarRating`) |
| `lib/games/guess_the_number/view/widgets/results_overlay.dart` | Add "Share to Nostr" button (wins only), share state feedback, refactor `_StarRating` to use `ScoreCalculator.stars()` |
| `lib/games/guess_the_number/view/game_page.dart` | Provide `ResultSharingCubit` via `BlocProvider` |
| `lib/app/app.dart` | Provide `NostrPublishRepository` via `RepositoryProvider` |

### Architecture

**`NostrPublishRepository`**: Wraps `Ndk` relay write operations. Exposes a `publish(Nip01Event signedEvent)` method that broadcasts to all default relays in parallel. Returns success if at least 1 relay responds with `OK`. This keeps `ResultSharingCubit` testable -- mock the repository, not `Ndk` directly.

**`EventBuilder`**: Builds kind 30042 events specifically for Guess the Number. Accepts score, star count, question count, elapsed seconds, and date. Returns an unsigned `Nip01Event` with the correct `d` tag, `t` tags, NIP-32 labels (including `score-{n}`), and human-readable content showing points and stars. This is intentionally game-specific -- generalize when game #2 arrives.

**Star computation**: The star-from-score thresholds currently live in the private `_StarRating` widget in `results_overlay.dart` (>=450: 3 stars, >=250: 2, else: 1). Extract this logic into `ScoreCalculator.stars(int score)` (in `lib/games/guess_the_number/logic/score_calculator.dart`) so both the overlay widget and `EventBuilder` use the same thresholds. The caller passes the computed star count to `EventBuilder`.

**`ResultSharingCubit`**: Manages the share flow. States: `initial`, `checkingIdentity`, `publishing`, `success`, `failure(message)`. Depends on `NostrIdentityRepository` (for identity checks and signing) and `NostrPublishRepository`.

**Share flow**:
1. User taps "Share to Nostr" on win overlay
2. Cubit checks if identity exists via `NostrIdentityRepository.hasIdentity()`
3. If no identity: emit `checkingIdentity` -> a `BlocListener<ResultSharingCubit>` on the overlay reacts by pushing the identity explainer modal (from PR 2). After the modal pops, the UI calls `ResultSharingCubit.publish()` to resume the flow.
4. If identity exists: emit `publishing` -> build event via `EventBuilder` -> sign via `NostrIdentityRepository.getSigner()` -> publish via `NostrPublishRepository`
5. Success: emit `success` -> snackbar "Result shared!" -> button transitions to disabled "Shared" state
6. Failure: emit `failure` -> snackbar "Could not share your result. Tap to retry."

**Key backup nudge**: After each successful share, show a non-blocking snackbar reminder to back up their key in Settings (simple snackbar, no first-share tracking).

**Ndk initialization**: `NostrPublishRepository` uses a lazy factory to create the `Ndk` instance on first publish, avoiding eager WebSocket connections at app startup. The `Ndk` instance is configured with `MemCacheManager`, `Bip340EventVerifier`, and the default relay URLs.

### Event Format

```jsonc
{
  "kind": 30042,
  "tags": [
    ["d", "guess-the-number:2026-04-02"],
    ["t", "vgg"],
    ["t", "guess-the-number"],
    ["L", "games.vgg.score"],
    ["l", "score-350", "games.vgg.score"],
    ["l", "stars-3", "games.vgg.score"],
    ["l", "questions-8", "games.vgg.score"],
    ["l", "time-102", "games.vgg.score"]
  ],
  "content": "\ud83c\udfaf Very Good Games \u2014 Guess the Number\n\ud83c\udfaf 350 points \u00b7 \u2b50\u2b50\u2b50 3 Stars\n\ud83d\udcac 8 questions \u00b7 \u23f1 1:42\n\n2026-04-02"
}
```

- `d` tag date uses UTC to match `DailySeed.forDate()` logic
- Stars derived from score using existing `_StarRating` thresholds (>=450: 3, >=250: 2, else: 1)

### Error Handling

- **Success**: At least 1 relay `OK` (including `duplicate:`) = success
- **Failure**: All relays reject or timeout (10s) -> snackbar with retry
- **Navigating away**: Share opportunity is forfeited (cubit disposed with page)
- Simplified relay response handling: binary success/failure. No per-category classification in v1.

## Acceptance Criteria

### Publish Repository
- [ ] `NostrPublishRepository` wraps `Ndk` broadcast, publishes to 3 default relays in parallel
- [ ] Returns success if at least 1 relay responds OK
- [ ] Returns failure if all relays reject or timeout (10s)
- [ ] Full unit test coverage (mock `Ndk`)

### Event Builder
- [ ] Builds kind `30042` event with correct `d` tag format: `guess-the-number:<UTC-date>`
- [ ] Includes `t` tags: `vgg`, `guess-the-number`
- [ ] Includes NIP-32 labels: `score-{n}`, `stars-{n}`, `questions-{n}`, `time-{n}` under `games.vgg.score`
- [ ] Human-readable content with emoji, stars, question count, time, date
- [ ] Accepts primitive inputs (score, stars, questions, seconds, date), not `GameState`
- [ ] Full unit test coverage

### Star Computation Extraction
- [ ] `ScoreCalculator.stars(int score)` extracted to `score_calculator.dart`
- [ ] `_StarRating` widget refactored to use `ScoreCalculator.stars()`
- [ ] Existing `score_calculator_test.dart` updated with star tests
- [ ] Existing `results_overlay_test.dart` still passes

### Sharing Cubit
- [ ] Emits correct state transitions: initial -> checkingIdentity/publishing -> success/failure
- [ ] Depends on `NostrIdentityRepository` and `NostrPublishRepository`
- [ ] UI resumes publish flow after identity setup modal pops
- [ ] Signs event via `NostrIdentityRepository.getSigner()`, publishes via `NostrPublishRepository`
- [ ] Full unit test coverage with `bloc_test`

### Results Overlay
- [ ] "Share to Nostr" button visible on win overlay only (not on loss)
- [ ] Button shows loading state during publishing
- [ ] Button transitions to disabled "Shared" state with check icon on success
- [ ] Failure shows snackbar with retry action
- [ ] Key backup nudge snackbar after each successful share
- [ ] Widget tests for all button states (initial, loading, success, failure)

## Dependencies

- **PR 2** must merge first (identity management, signer, `Ndk` instance)
- Independent of PR 4 (community stats)

## References

- Results overlay: `lib/games/guess_the_number/view/widgets/results_overlay.dart`
- Game page: `lib/games/guess_the_number/view/game_page.dart`
- Game state (score, questions, time): `lib/games/guess_the_number/cubit/game_state.dart`
- Star thresholds (to extract): `lib/games/guess_the_number/view/widgets/results_overlay.dart:162-166`
- Score calculator (destination): `lib/games/guess_the_number/logic/score_calculator.dart`
- Daily seed (UTC date): `lib/core/daily_seed/daily_seed.dart`
- Parent plan: `docs/plan/2026-04-02-feat-nostr-integration-v1-result-sharing-plan.md`
