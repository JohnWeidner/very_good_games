---
date: 2026-04-02
topic: daily-games-hub
---

# Very Good Games — Daily Puzzle Hub

## What We're Building

A mobile app (iOS & Android) that offers a collection of daily games and puzzles — think Wordle meets LinkedIn's daily games. The app serves two purposes: providing fun, bite-sized daily brain teasers, and gently educating users about the Nostr decentralized social protocol through a "learn by doing" approach.

The first game is **"Guess the Number"** — a deduction puzzle where players narrow down a hidden number (1–1024) on a visual 32x32 grid by asking strategic questions. The twist: you can't reuse the same question type, forcing varied thinking.

The app is architected as a modular game hub so additional word games and logic puzzles can be added over time.

As a secondary deliverable, Nostr authentication will be extracted into a reusable open-source package (`very_good_nostr_auth`) so other developers can more easily build social apps with Nostr.

## First Game: Guess the Number

### Core Mechanics
- **Grid**: 32x32 cells (1,024 total), each representing a number from 1 to 1024
- **Visual feedback**: Cells start green (possible), turn gray/red when eliminated by a question
- **Key constraint**: Each question type can only be used once (except `=`), forcing strategic variety
- **Win condition**: Use the `=` question (which can be asked multiple times) to guess the exact number
- **Scoring**: Combines time elapsed and number of questions used
- **Daily mode**: Same target number for all players each day (seeded), enabling result sharing/comparison
- **Educational angle**: Teaches mathematical concepts (prime numbers, divisibility, inequalities) through gameplay

### Question Types

Each type can be used **once per game** unless noted. Part of the design goal is teaching players these mathematical concepts through play.

**Comparison types:**
- `< N` — Less than N
- `<= N` — Less than or equal to N
- `> N` — Greater than N
- `>= N` — Greater than or equal to N
- `between (exclusive)` — Between X and Y, exclusive
- `between (inclusive)` — Between X and Y, inclusive

**Math property types:**
- `is odd` — Is the number odd?
- `is even` — Is the number even?
- `is divisible by N` — Is the number divisible by N?
- `is prime` — Is the number prime?

**Guess type:**
- `= N` — Guess the exact number *(can be used multiple times)*

**Special moves:**
- `shotgun` — Eliminates 20 random numbers from the remaining possibilities
- `hand grenade` — Pick a cell on the grid; eliminates 20 numbers within a certain radius of that cell

> **Note:** Question types will need iteration and playtesting to find the right balance for fun. The above is a starting set.

### Nostr Integration (v1)
- **Share results**: After completing the daily puzzle, generate a Nostr note with your score and a visual representation of your grid journey
- **Learn by doing**: Guide users through Nostr key generation and sharing naturally — explain concepts (keys, relays, notes) as they encounter them in the flow
- **No backend required**: Nostr relays handle the social/sharing layer
- **Reusable auth package**: Extract Nostr authentication into a standalone `very_good_nostr_auth` package that others can use to build social apps with Nostr
- **Reference implementation**: The [divine-mobile](https://github.com/divinevideo/divine-mobile) project (cloned at `/Users/john/AndroidStudioProjects/divine-mobile`) has a working Nostr auth flow to use as a starting point

## Why This Approach

### Architecture: Feature-based modular
Each game lives in its own feature module (`lib/games/guess_the_number/`), with shared concerns (daily seed generation, Nostr client, theming, navigation) in a `core/` layer. This was chosen over a monorepo (too heavy for a small team) and a flat structure (won't scale as games are added). The modular approach balances clean separation with fast iteration.

### Starting with one game
Rather than shipping 2-3 games immediately, we're building one polished game with the architecture ready for more. This lets us validate the game hub shell, Nostr integration, and daily-game infrastructure before scaling the game catalog.

### Nostr over a custom backend
Using Nostr for the social layer eliminates the need for a backend while doubling as an educational tool. Users learn about decentralized social protocols through a natural, low-stakes interaction (sharing game results).

### Extracting Nostr auth as a package
The Nostr authentication flow is extracted into `very_good_nostr_auth` rather than built inline because (a) it's a reusable concern not specific to this app, (b) it lowers the barrier for other Flutter developers to adopt Nostr, and (c) it follows VGV's open-source-first approach.

## Key Decisions
- **Platform**: Mobile only (iOS & Android) via Flutter
- **First game**: "Guess the Number" — grid-based deduction puzzle
- **Architecture**: Feature-based modular (`lib/games/`, `lib/core/`)
- **Grid size**: 32x32 (1,024 cells) — the density is intentional; watching large swaths disappear is the experience
- **Question constraint**: Each question type is used once per game, except `=` (guess) which is repeatable
- **Special moves**: Shotgun (random elimination) and hand grenade (area elimination) add tactical variety
- **Scoring**: Time + question count combined
- **Daily mode**: Shared daily target number for all players (deterministic seed)
- **Social**: Nostr for result sharing — no custom backend
- **Nostr auth**: Extract into a reusable `very_good_nostr_auth` package (open source)
- **Education**: Dual purpose — teach math concepts through gameplay, teach Nostr through result sharing
- **Persistence**: Local storage for stats/streaks (v1), Nostr for sharing

## Open Questions
- What specific Nostr libraries/packages are available for Flutter?
- How should the daily seed be deterministically generated (date-based hash)?
- What's the exact scoring formula (weight of time vs. question count)?
- What does the question selection UI look like — list, categories, or wheel?
- How does the hand grenade radius work — fixed radius or player-chosen?
- Should shotgun/hand grenade be available every game, or earned/limited?
- What happens if the player uses `=` and guesses wrong — penalty, or just costs a turn?
