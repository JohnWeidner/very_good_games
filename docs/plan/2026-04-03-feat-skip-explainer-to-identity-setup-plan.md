---
title: "feat: add skip button to explainer flow"
type: feat
date: 2026-04-03
---

## feat: add skip button to explainer flow

## Overview

Add a "Skip" text button to the explainer flow so users can bypass the educational screens and go directly to identity setup.

## Problem Statement / Motivation

Users who already understand Nostr (or who have seen the explainer before) shouldn't be forced to tap "Next" through 5 screens. A skip option respects their time while keeping the educational content available for first-timers.

## Proposed Solution

### Changes to Existing Files

| File | Change |
|---|---|
| `lib/nostr/identity/view/identity_explainer_flow.dart` | Add "Skip" `TextButton` in the AppBar `actions`, pops with `true` (same as "Set Up Identity") |
| `test/nostr/identity/view/identity_explainer_flow_test.dart` | Add test: tapping Skip pops with `true` and navigates to identity setup |

### Implementation Details

- Add a `TextButton` with text "Skip" to the AppBar's `actions` list
- `onPressed` calls `Navigator.of(context).pop(true)` — same behavior as the "Set Up Identity" button on the last page
- The Skip button is visible on all 5 pages
- No changes to the caller (`NostrIdentitySection`, `ResultsOverlay`) — they already handle the `pop(true)` result by navigating to `IdentitySetupPage`

## Acceptance Criteria

- [ ] "Skip" button visible in AppBar on all explainer screens
- [ ] Tapping "Skip" pops with `true`, triggering identity setup
- [ ] "Set Up Identity" button still works on the last page
- [ ] Widget test: Skip button renders on first page
- [ ] Widget test: tapping Skip pops with `true`

## Dependencies

None.

## References

- Explainer flow: `lib/nostr/identity/view/identity_explainer_flow.dart`
- Test: `test/nostr/identity/view/identity_explainer_flow_test.dart`
