---
title: "feat: add settings screen with route and navigation"
type: feat
date: 2026-04-02
---

## feat: add settings screen with route and navigation

## Overview

Add a bare settings page with a `/settings` route, a gear icon on the home page AppBar, and a placeholder "Nostr Identity" section. This is the navigation shell that all Nostr integration features will plug into.

## Problem Statement / Motivation

The app has no settings screen. The Nostr integration (identity management, result sharing, community stats) needs a persistent home for identity configuration. This PR establishes the route and entry point so subsequent PRs can add functionality without touching navigation plumbing.

## Proposed Solution

### New Files

```
lib/
  settings/
    settings.dart                   # Barrel file
    view/
      settings_page.dart            # Scaffold with AppBar + placeholder sections
      view.dart                     # Barrel file
```

### Changes to Existing Files

| File | Change |
|---|---|
| `lib/home/view/home_page.dart:57` | Add gear icon `IconButton` to AppBar `actions`, navigates to `/settings` |
| `lib/app/routes/routes.dart` | Add `GoRoute(path: '/settings', builder: ...)` |

### Implementation Details

- `SettingsPage` is a simple `Scaffold` with an `AppBar` titled "Settings" and a `ListView` body.
- Include a placeholder `ListTile` for "Nostr Identity" that shows "Set up your identity" with a chevron. In this PR it navigates nowhere -- PR 2 wires it up.
- Gear icon uses `Icons.settings` in the home page AppBar's `actions` list.

## Technical Considerations

- No new dependencies required.
- Follow existing barrel file conventions (`settings.dart`, `view.dart`).
- The settings route is not a game route, so it is added directly to `createRouter()` alongside the home route rather than through the `GameRegistry`.

## Acceptance Criteria

- [ ] Settings page renders with "Settings" title in AppBar
- [ ] Gear icon visible in home page AppBar, tapping navigates to `/settings`
- [ ] Back navigation from settings returns to home
- [ ] Placeholder "Nostr Identity" `ListTile` is visible (non-functional in this PR)
- [ ] Barrel files created: `lib/settings/settings.dart`, `lib/settings/view/view.dart`
- [ ] Widget test: settings page renders correctly
- [ ] Widget test: gear icon navigates to settings
- [ ] Widget test: back navigation works

## Dependencies

None -- this is the first PR in the series.

## References

- Home page (entry point): `lib/home/view/home_page.dart:57`
- Router: `lib/app/routes/routes.dart`
- Parent plan: `docs/plan/2026-04-02-feat-nostr-integration-v1-result-sharing-plan.md`
