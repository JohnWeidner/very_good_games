---
title: "feat: expand identity explainer to five screens"
type: feat
date: 2026-04-03
---

## feat: expand identity explainer to five screens

## Overview

Expand the identity explainer onboarding flow from 2 screens to 5, matching the reference design. The flow educates users about Nostr before identity setup.

## Problem Statement / Motivation

The current explainer has only 2 screens ("What is Nostr?" and "Your Key Pair"). The reference design shows 5 screens that progressively build understanding: what Nostr is, identity ownership, digital signatures, public vs private keys, and identity flexibility. More screens = better onboarding before the user commits to creating a key pair.

## Proposed Solution

### Changes to Existing Files

| File | Change |
|---|---|
| `lib/nostr/identity/view/identity_explainer_flow.dart` | Change `_pageCount` from 2 to 5, replace `_YourKeyPairPage` with 4 new page widgets, keep `_WhatIsNostrPage` as-is |
| `test/nostr/identity/view/identity_explainer_flow_test.dart` | Update tests for 5 pages: fix "navigates to second page" test, fix "Set Up Identity" test to navigate to page 5, add test for each new page title |

### Screen Content (from reference design)

**Screen 1 — "What is Nostr?" (existing, keep as-is)**
- Intro text: "It's not an app or company; it's ..."
- Markdown bullets: open protocol, network of relays

**Screen 2 — "You Own Your Identity"**
- Icon: `Icons.key` (key)
- Body: "On Nostr, there are no 'accounts' owned by a company. You are your own master."

**Screen 3 — "Digital Signatures"**
- Icon: `Icons.draw` (signature/pen)
- Body: "Instead of having user accounts, Nostr works by having every note 'signed' to prove the signer has the nsec that created that note."

**Screen 4 — "Public vs. Private"**
- Icon: `Icons.visibility` / `Icons.visibility_off`
- Body: "When anyone sees one of your notes, they won't see your secret key (nsec), they will only see your public ID (npub)."
- Use markdown with two labeled sections:
  - **Public** — Your npub is visible to everyone, like a username
  - **Private** — Your nsec is hidden, like a password with no reset

**Screen 5 — "One ID or Many — You Decide."**
- Icon: `Icons.people` or `Icons.fingerprint`
- Three markdown sections:
  - **Freedom of Identity**: You can create a new ID for every site you visit, or use one single ID to stay connected everywhere.
  - **The Power of One**: If you want a single identity that never changes, just use the same nsec across different apps. Your followers and posts will follow you.
  - **The Golden Rule**: To keep your permanent ID safe, write your nsec down and store it with your important physical documents. There is no "Reset Password" button here.

### Implementation Details

- Each screen is a private `StatelessWidget` following the existing `_WhatIsNostrPage` pattern: icon + title + body text, wrapped in `Padding` with `SingleChildScrollView` for overflow safety
- Screen 4 uses `MarkdownBody` for the Public/Private sections (already imported)
- Screen 5 uses `MarkdownBody` for the three sections
- `_pageCount` changes from `2` to `5`
- `PageView.children` list updated to include all 5 page widgets

## Acceptance Criteria

- [ ] 5 screens render in the PageView in the correct order
- [ ] Screen 1 unchanged ("What is Nostr?" with markdown bullets)
- [ ] Screen 2 shows "You Own Your Identity" with key icon and body text
- [ ] Screen 3 shows "Digital Signatures" with body text
- [ ] Screen 4 shows "Public vs. Private" with markdown Public/Private sections
- [ ] Screen 5 shows "One ID or Many — You Decide." with three markdown sections
- [ ] "Next" button appears on screens 1–4, "Set Up Identity" on screen 5
- [ ] Page indicator shows 5 dots with correct active state
- [ ] All existing tests updated for 5-page flow
- [ ] New tests verify each screen title renders correctly
- [ ] Back button still dismisses without result

## Dependencies

None — only modifies existing files.

## References

- Current file: `lib/nostr/identity/view/identity_explainer_flow.dart`
- Current test: `test/nostr/identity/view/identity_explainer_flow_test.dart`
- Reference design: attached image (5 dark-themed screens with illustrations)
