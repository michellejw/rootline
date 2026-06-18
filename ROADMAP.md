# Rootline + Shroom Games roadmap

A standing plan for where Rootline (and the broader Shroom Games suite) is headed. Things settled here have been agreed already; revisit only when something genuinely changes.

## Guiding principles

- **Calm and meditative** is the north star for Rootline's UX. No arcade/competitive framing.
- **Works offline, no accounts, no ads.** (Same as the original design plan.)
- **Cross-app consistency** matters — anything visual or interaction-pattern-y should be sharable across the suite (iOS apps + future web).
- **The owner (Michelle) is up for ambitious work** to learn how to build solid apps.

## Three big rocks (in order)

### 1. Calm-leaderboard rework

Replace the current arcade-style leaderboard (3-letter initials, ranked top 5, "New record!" entry sheet) with a quieter pattern:

- Track best time per tier silently
- Show as a single line per tier in a "Stats" view: *"Your fastest Sprout: 1:23"* + optional completion count (*"23 sprouts cleared"*)
- The win card whispers "**0:42 — your fastest yet**" if you beat your own best, otherwise stays quiet on time
- No 3-letter entry sheet at all
- No ranks

This is the smallest of the three. Doing it first lets us sit with what "calm stats" feels like before committing to a shared pattern.

**Affected files**: `Storage/ScoreStore.swift`, `Views/BestTimesView.swift`, `Views/WinEntrySheet.swift` (delete), `Views/WinCard.swift`, `Views/PlayView.swift`, `Views/HomeView.swift`.

If this pattern feels right, it becomes a candidate for ShroomKit, and Shroomsweeper retro-fits to it. Shroomsweeper currently has the arcade leaderboard; doesn't have to change unless we decide it should match.

### 2. Design tokens system across iOS + web

Single source of truth for palette, typography, spacing, radii, motion. A `tokens/` source (likely JSON, possibly the design-tokens.org spec) plus a small build pipeline that emits:

- Swift extensions for ShroomKit — replaces the hand-coded values in `Palette.swift` / future `Spacing.swift` / etc.
- CSS custom properties / Tailwind config for the marketing site (`shroomgames.app`) and any future web games
- (Manual but tracked) Figma library updates

**Why now**: before more apps and more web surfaces ship and lock in duplicates of the values.

**Likely home**: a new `shroomkit-tokens/` repo or a `tokens/` directory inside ShroomKit. To be decided when starting.

**Open design questions** (decide when starting):
- Tokens spec: design-tokens.org community group format, or hand-rolled JSON?
- Generator: Style Dictionary, or hand-rolled Swift / JS scripts?
- Where do tokens live: ShroomKit repo, or their own repo?
- How to handle Figma sync: manual, or via a plugin?

### 3. Slitherlink solver + generator + daily/archive UI

Replace the hand-curated puzzle pool with an offline-generated bundle, surfaced as NYT-style daily puzzles plus a browseable archive.

**Architecture**:
- An **offline Swift CLI generator** under `scripts/` produces a JSON bundle of validated puzzles per tier:
  - Random region generation
  - Solution derivation (already in `Engine.swift`)
  - Clue-hiding strategy
  - **Slitherlink solver** (constraint propagation + uniqueness check) — the hardest piece
  - Difficulty grading (count of techniques the solver needs)
- The output JSON ships as an app **bundled resource**
- App loads the bundle, maps date → puzzle deterministically (e.g., date hash mod count)
- **Daily** view: "Today's grove" prominent on Home
- **Archive** view: scrollable grid of all past days, each with a status (cleared / not / streak)
- Replaces the current Sprout #1 / #2 / #3 cycling

**Why deepest**: solver is real work, takes time to get right, but unlocks endless content forever. The reason the original design plan punted on it.

**Order within #3**:
1. Solver (CLI, validates uniqueness, no UI)
2. Generator (CLI, emits JSON bundle)
3. App-side: load bundle, daily, archive
4. Migrate progress/persistence from grove-index to date-keyed puzzle id

## Status of where we are right now (as of last commit)

All three apps build clean, public on GitHub, MIT-licensed.

- **Rootline** ([github.com/michellejw/rootline](https://github.com/michellejw/rootline)) — v1 feature-complete per the original design plan. Plus: app icon, persistence, puzzle editor + add-puzzle script, tutorial overhaul, leaderboard (the soon-to-be-reworked arcade version), theme cycle in-game, full Dynamic Type pass.
- **Shroomsweeper** ([github.com/michellejw/shroomsweeper](https://github.com/michellejw/shroomsweeper)) — on ShroomKit, persistence, ThemeMode, in-game theme cycle.
- **ShroomKit** ([github.com/michellejw/shroomkit](https://github.com/michellejw/shroomkit)) — Palette, Appearance, ThemeMode, LoadingView, WelcomeScaffold. Two consumers. Local-path package dependency (URL-based was attempted but Xcode's SPM resolver was flaky — punted).

## What's not on the roadmap (intentionally)

- **Sharing solutions** — not interested
- **Per-puzzle initials/competitive leaderboard** — replaced by the calm rework
- **Hint refinement** — current 3-level system is fine
- **Accounts / cloud sync** — design plan says no, sticking with that
