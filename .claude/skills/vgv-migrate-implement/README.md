# vgv-migrate-implement

A Claude Code skill for implementing Flutter features following Feature-First Clean Architecture (FFCA), using artifacts produced by `vgv-migrate-analyze` as its primary input.

Follows the [Agent Skills specification](https://agentskills.io/specification).

## Structure

```
vgv-migrate-implement/
├── SKILL.md                          # Main skill file (required)
├── README.md                         # This file
└── references/
    ├── REFERENCE.md                  # Detailed phase/step instructions
    └── FFCA_PATTERNS.md              # FFCA code templates and conventions
```

## Overview

This skill implements a single feature triple (`{feature}_domain`, `{feature}_data`, `{feature}_presentation`) in one run, using:

- `docs/migration-manifest.yaml` — feature spec, effort size, API/model dependencies, complexity flags
- `native/{project}-ios/` and `native/{project}-android/` — native source files read during Phase 0 to extract business logic, validation rules, state transitions, and UI patterns not captured in the manifest
- `CLAUDE.md` — project coding standards, coverage requirements, architecture rules
- `shared/{package}/lib/{package}.dart` — barrel file for each shared package the feature references
- Existing workspace packages — detected before code generation begins

It uses Claude Code's subagent feature to parallelize Data, Presentation, and Domain test layers after the Domain scaffold is committed.

## Features

- **Native parity analysis**: reads iOS and Android source files to extract business logic, validation, state transitions, and UI patterns — ensures Flutter implementation matches native behavior, not just API surface
- **Pre-flight gate**: validates all inputs and shows a plan before writing any code
- **Figma design integration**: fetches design context and screenshots via Figma MCP for pixel-accurate UI generation
- **Parallel implementation**: Data + Presentation layers implemented concurrently by sub-agents in isolated git worktrees
- **Stub generation**: missing cross-feature deps and absent shared API methods become `UnimplementedError` stubs with structured TODOs
- **build_runner execution**: runs after sub-agent worktrees merge to verify codegen compiles
- **100% coverage**: tests written alongside implementation by the same sub-agent that owns the layer
- **Wiring snippet**: generates app router and DI registration snippets as TODOs, never modifies the app shell
- **Post-implementation review**: FFCA boundary compliance, coverage quality, stub inventory, and native parity reviewed by an agent team when available, sequentially otherwise

## Inputs (all pre-existing)

| Artifact | Produced by |
|---|---|
| `docs/migration-manifest.yaml` | `vgv-migrate-analyze` |
| `native/{project}-ios/` | Symlink to native iOS codebase (ViewModels, Views, Services) |
| `native/{project}-android/` | Symlink to native Android codebase (ViewModels, Screens, Repositories) |
| `shared/{pkg}/lib/{pkg}.dart` | Barrel files maintained alongside shared packages |
| `CLAUDE.md` | Project bootstrap / maintained manually |

## Usage

```bash
# Implement a feature by ID (as it appears in the manifest)
/vgv-migrate-implement cart

# Implement with explicit manifest path (if non-default)
/vgv-migrate-implement cart --manifest=path/to/migration-manifest.yaml

# Dry run: show pre-flight plan only, do not write code
/vgv-migrate-implement cart --dry-run

# Skip sub-agent parallelism (serial mode, useful for debugging)
/vgv-migrate-implement cart --serial

# Skip the post-implementation review phase
/vgv-migrate-implement cart --skip-review

# Provide Figma design URLs for UI generation
/vgv-migrate-implement settings --figma=https://www.figma.com/design/FILE_KEY/FILE_NAME?node-id=NODE_ID

# Multiple Figma URLs (one per screen)
/vgv-migrate-implement settings \
  --figma=https://www.figma.com/design/FILE_KEY/FILE_NAME?node-id=12454-16735 \
  --figma=https://www.figma.com/design/FILE_KEY/FILE_NAME?node-id=12454-16800
```

## Execution Model

```
main agent
  │
  ├─ Phase 0: Read context + native parity analysis (iOS & Android source)
  ├─ Phase 1: Generate NATIVE_PARITY.md checklist
  ├─ Phase 2: Pre-flight checks + developer confirmation
  ├─ Phase 3: Domain scaffold (committed to feature/{name})
  ├─ Phase 4: Register packages in workspace pubspec
  │
  ├─ Phase 5: Launch sub-agents in parallel (isolated worktrees)
  │    ├─ Sub-agent A: worktree — data layer
  │    │    ├─ DTOs, mappers, data sources, repository impl
  │    │    └─ Data layer unit tests
  │    ├─ Sub-agent B: worktree — presentation layer
  │    │    ├─ BLoC/Cubit, screens, widgets (+ Figma design context)
  │    │    └─ BLoC unit tests + widget tests
  │    └─ Sub-agent C: worktree — domain tests
  │         └─ Domain model + use case unit tests
  │
  ├─ Phase 6: Merge sub-agent worktrees → feature/{name}
  ├─ Phase 7: Run build_runner, verify compilation
  ├─ Phase 8: Generate implementation summary + wiring snippet
  │
  └─ Phase 9: Post-implementation review
       ├─ [agent teams available] Spawn review team (peer-coordinated)
       │    ├─ Reviewer A: FFCA boundary compliance
       │    ├─ Reviewer B: test coverage + quality
       │    ├─ Reviewer C: stub inventory + actionability
       │    └─ Reviewer D: native parity + Figma parity compliance
       └─ [fallback] Sequential review by main agent (same criteria)
            └─ Findings written to docs/features/{name}/REVIEW.md
```

## Output

All output is contained within the feature triple. The skill never modifies:
- `apps/` (routing wiring is emitted as a TODO snippet)
- `shared/` (missing shared symbols become stubs with TODOs)
- Other features' packages

## Pre-flight Summary Example

```
Feature: cart (effort: L, complexity: 3/5)

Packages to create:
  features/cart/cart_domain        (Dart)
  features/cart/cart_data          (Dart)
  features/cart/cart_presentation  (Flutter)

Cross-feature dependencies:
  ✓ product_domain — found at features/product/product_domain

Shared packages:
  ✓ ui_kit       — barrel found, 11 exported symbols
  ✓ api_client   — barrel found, 195 exported symbols

Native parity analysis:
  ✓ iOS     — 6 files read (CartViewModel, CartView, CartService, CartItemView, ...)
  ✓ Android — 5 files read (CartViewModel, CartScreen, CartRepository, ...)
  Business logic rules: 8 (add/remove item, quantity validation, tip calc, ...)
  Validation rules: 3 (min quantity, max quantity, tip percentage range)
  Platform differences: 1 (iOS has swipe-to-delete, Android uses icon button)

Complexity flags:
  ⚠ CartV2 + CartV3 APIs in parallel — see manifest note
  ⚠ Talon.One dependency not yet in shared client — stub will be generated

Workspace pubspec.yaml: will register 3 new packages

Proceed? [y/n]
```

## Post-run Summary Example

```
Feature: cart — implementation complete

Packages created:
  features/cart/cart_domain
  features/cart/cart_data
  features/cart/cart_presentation

build_runner: ✓ passed
Coverage: domain 87%, data 82%, presentation 81%

Open TODOs (5):
  [TODO-1] cart_data: TalonOneDataSource.applyOffer — stub, awaiting shared client
  [TODO-2] cart_data: CartApiClientV3.updateCartItems — method missing from shared client barrel exports
  [TODO-3] cart_presentation: CartSummaryWidget — ScCartItemRow not found in ui_kit, placeholder used
  [TODO-4] Routing: see wiring snippet below
  [TODO-5] cart_domain: GetCartTaxQuery — tax calculation logic unclear from manifest, review native impl

Wiring snippet: → see docs/features/cart/WIRING.md

Review: ✓ complete (agent team) → see docs/features/cart/REVIEW.md
  Findings: 2 boundary issues, 1 coverage gap, 3 stub clarifications
  Blocking: 0   Action required: 2   Informational: 4
```

## See Also

- `vgv-migrate-analyze` — the upstream skill that produces the manifest this skill consumes
- `references/REFERENCE.md` — detailed phase-by-phase instructions
- `references/FFCA_PATTERNS.md` — FFCA code templates used during generation
