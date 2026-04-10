# Very Good Games

A Flutter app featuring daily puzzle games with Nostr social sharing. Built with VGV conventions.

## Architecture

### Layer Structure
- `lib/core/` — shared infrastructure (game registry, storage, theme, daily seed)
- `lib/games/<name>/` — each game is a self-contained module:
  - `models/` — data models (sealed classes, enums, equatable)
  - `logic/` — pure Dart game logic (calculators, generators, evaluators)
  - `cubit/` — state management (Cubit + part-of State)
  - `view/` — Flutter widgets (page, grid, overlays)
  - `theme/` — game-specific colors
  - `<name>_game.dart` — `GameDefinition` implementation
- `packages/nostr_identity/` — reusable Nostr identity package:
  - `identity/` — key management (generate, import, delete)
  - `signing/` — signer abstraction + `LocalNostrSigner`
  - `relay/` — `NdkProvider` (injectable relays) + relay config
  - `profile/` — `NostrProfile` model, `NostrProfileRepository` (kind-0 read/write + Drift cache)
  - `database/` — Drift database (schema v1, profile table)
- `lib/nostr/` — app-level Nostr integration:
  - `identity/` — `NostrIdentityCubit`, identity setup views
  - `profile/` — `ProfileCubit` for leaderboard + settings
  - `sharing/` — event building, publishing, result sharing UI
  - `stats/` — community stats from relays

### Conventions
- **State management**: Bloc/Cubit with `part of` state files
- **Testing**: `bloc_test` for cubits, `mocktail` for mocks, widget tests for UI
- **Barrel files**: every directory has one, export alphabetically
- **Imports**: use barrel files; never import across layer boundaries (view -> data)
- **copyWith pattern**: use `Type? Function()?` wrapper for nullable fields that need explicit null-setting
- **Nostr repositories**: all share a single `NdkProvider` (one WebSocket pool) — identity/signing/relay/profile are in `packages/nostr_identity/`, app imports via `package:nostr_identity/nostr_identity.dart`
- **Profile conventions**: kind-0 read-then-merge preserves unknown fields; Drift cache with 24h staleness; field validation (name 100 chars, about 500 chars, picture URL https + 2048 chars)
- **Game registration**: implement `GameDefinition`, add to `GameRegistry` in `main.dart`
- **Shared UI**: `ResultSharingListener`, `ShareResultButton`, `CommunityStatsSection`, `StarRating` — don't duplicate per game
- **Identity setup**: use `IdentitySetupLauncher.launch(context)` — don't copy the navigation flow
- **Date keys**: use `utcDateKey()` from `core/daily_seed/date_key.dart`
- **Instructions seen**: use `GameStorageRepository.hasSeenInstructions()` / `markInstructionsSeen()` — don't access SharedPreferences directly from views
- **Debug-only features**: gate with `kDebugMode` (e.g. shuffle button)

### Linting
- Uses `very_good_analysis` v7.0.0
- Run `dart fix --apply` before committing

### Adding a New Game
1. Create `lib/games/<name>/` with models, logic, cubit, view, theme
2. Implement `GameDefinition` in `<name>_game.dart`
3. Register in `main.dart` GameRegistry
4. Add `EventBuilder.build<Name>Result()` for Nostr sharing
5. Use shared overlay widgets (`ResultSharingListener`, `ShareResultButton`, etc.)
6. Use `utcDateKey()` for date formatting
7. Use `GameStorageRepository` for persistence (sessions, streaks, instructions seen)
