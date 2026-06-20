# Mycogrid Solver — Uniqueness Validator (Rock 3, sub-project 1)

**Date:** 2026-06-20
**Branch:** `feature/rock3-mycogrid-solver` (worktree `rootline-rock3/`)
**Scope:** Rootline iOS repo only. Standalone offline CLI + library. No app UI changes.

## Context

Rock 3 replaces Mycogrid's hand-curated puzzle pool with an offline-generated bundle
surfaced as daily puzzles + a browseable archive. Its sequence is: **solver →
generator → app daily/archive → persistence migration.** This spec covers only the
first piece: the **solver**.

### The reframing that defines this sub-project

Today a puzzle is defined by its *solution* — the `inside` set of cells in
`Puzzle` (see `rootline/Model/Engine.swift`). Clues are *derived* from that region,
then some are hidden via `hideClues`. Because every puzzle starts from a real loop,
it is "valid" by construction.

A real puzzle, though, is defined by its **visible clues**, and is only a *good*
puzzle if those clues admit **exactly one** closed loop. Hiding clues (or generating
regions randomly, later) can silently produce puzzles with multiple solutions —
unsolvable-by-logic and broken-feeling.

So the "solver" is not a player aid. It is a **uniqueness validator**: given only the
visible clues, prove there is exactly one satisfying loop. It is the gatekeeper the
generator will call before any puzzle ships. Everything else in Rock 3 depends on it.

## Goals

- A pure-Swift, dependency-free library that decides uniqueness for a set of visible clues.
- A CLI that audits the *current* hand-curated pool for uniqueness/solution-match.
- A difficulty/technique **trace** emitted alongside the verdict (raw signal only;
  no grading formula — that is a later sub-project).
- Full unit-test coverage against known puzzles, cross-checked with the app's own
  `PuzzleModel.isSolved` as an independent oracle.

## Non-goals (explicitly deferred)

- Random region generation, clue-hiding strategy, JSON bundle emission (generator sub-project).
- Difficulty grading *formula* / buckets (later; this spec emits only the raw trace).
- Any app-side daily/archive UI, or persistence migration from grove-index to date-keyed ids.
- Advanced human-style deduction rules beyond clue + dot rules (correctness does not need them;
  they are a later enhancement to reduce guessing and sharpen the difficulty signal).

## Architecture

A new Swift Package under `scripts/`. The app project is **not** modified.

```
rootline-rock3/scripts/MycogridSolver/
  Package.swift
  Sources/
    MycogridModel/        symlinks to the app's dependency-free model files
                          (Edge.swift, Engine.swift, Tier.swift, PuzzleData.swift)
    MycogridSolver/       the validator (new code); depends on MycogridModel
    mycogrid-validate/    CLI executable; depends on MycogridModel + MycogridSolver
  Tests/
    MycogridSolverTests/
```

### Sharing the app's types — via symlinks

SPM refuses source files located outside the package directory, so `Package.swift`
cannot simply list `../../rootline/Model/Edge.swift`. Instead, `Sources/MycogridModel/`
contains **symlinks** to the app's model files; SPM follows them and compiles the real
files. This gives a single source of truth with zero duplication and no app
restructuring. Symlinks are committed and are fine on macOS.

**Fallback:** if any symlinked file drags in a UI dependency (it should not — the model
files are `Codable`/`Sendable` and UI-free), copy the minimal type instead and note the
divergence. Verify at implementation time that `Edge`, `Engine` (`Puzzle`/`Cell`/
`PuzzleModel`), `Tier`, and `PuzzleData` compile standalone.

## Data model & public interface

The validator's entire public surface:

```swift
struct PuzzleClues {            // the ONLY input — exactly what a player sees
    let cols: Int
    let rows: Int
    let clues: [Cell: Int]      // visible clues only; a missing cell = no constraint
}

enum Verdict { case none, unique, multiple }

enum Rule { case clue, dot }    // extensible; only these two to start

struct SolveTrace {
    var rulesFired: [Rule: Int] // how often each deduction rule forced an edge
    var guesses: Int            // branch decisions taken (0 = solved by pure logic)
    var maxDepth: Int           // deepest branch level reached
}

struct SolveResult {
    let verdict: Verdict
    let solution: Set<Edge>?    // the loop when .unique (or one example when .multiple)
    let witness: Set<Edge>?     // the second loop when .multiple (proof of non-uniqueness)
    let trace: SolveTrace
}

func solve(_ clues: PuzzleClues) -> SolveResult
```

`PuzzleClues` deliberately has **no `inside` field** — the validator structurally
cannot peek at the stored solution. The `Set<Edge>` outputs use the app's exact `Edge`
type, so results interoperate with `PuzzleModel.isSolved`.

### Geometry (from the existing app, unchanged)

- Cells `(c, r)`, `c ∈ [0, cols)`, `r ∈ [0, rows)`.
- Dots `(c, r)`, `c ∈ [0, cols]`, `r ∈ [0, rows]`.
- `Edge.h(r, c)` connects dots `(c, r)→(c+1, r)`; `Edge.v(r, c)` connects `(c, r)→(c, r+1)`.
- A cell's 4 edges come from `Edge.cellEdges(c:r:)` — top, bottom, left, right.

## Algorithm: constraint propagation + backtracking

Internally every edge holds a state: `unknown | on | off`. Repeated two-step cycle:

### 1. Propagate to a fixpoint

Apply deduction rules until no edge changes. For a clued cell, let `on` = edges already
on, `unk` = unknown edges:

- **Clue rule**
  - `on > clue` **or** `on + unk < clue` → contradiction (dead branch).
  - `on == clue` → force all unknown edges of the cell **off**.
  - `on + unk == clue` → force all unknown edges **on**.
- **Dot rule** (each dot's degree must be 0 or 2, never 1)
  - two incident edges on → force remaining incident edges **off**.
  - one on with exactly one unknown left → force that unknown **on**.
  - zero on with exactly one unknown left → force that unknown **off**.

Every forced edge can trigger further deductions, so loop until stable. Each force
increments `trace.rulesFired[rule]`.

### 2. Branch

If propagation stalls with unknowns remaining: pick the most-constrained unknown edge
(heuristic — adjacent to the tightest clue/dot), try **on** then **off**, recurse.
Increment `trace.guesses`; track `trace.maxDepth`.

### Accepting a solution

A leaf is a valid solution iff: fully assigned, **all visible clues satisfied**, **all
dots degree 0 or 2**, **and the on-edges form a single closed loop**. Degree-2 alone
permits several disjoint loops, so connectivity is checked explicitly and multi-loop
states are rejected. Basic subloop pruning discards branches that seal a loop early
while clues remain unsatisfied (speed only; correctness rests on the final check).

### Deciding uniqueness

A counting DFS that **short-circuits the moment a second accepted solution appears**:

- 0 solutions → `.none`.
- exactly 1 → `.unique` (`solution` set, `witness` nil).
- ≥2 → `.multiple` (`solution` = first, `witness` = second).

Grids cap at 7×10 (~157 edges), small enough that propagation + branching is fast even
when guessing is required.

## CLI: `mycogrid-validate`

- **`pool`** — load every puzzle from `PuzzleData`; for each, derive its *visible* clues
  (`PuzzleModel.clues` minus `hideClues`), validate, and print a table:
  `tier · grove# · verdict · guesses · PASS/FAIL`.
  **FAIL** = not `.unique`, **or** the unique solution does not equal the stored region's
  boundary. Process exits non-zero if any puzzle fails — a CI guard that also immediately
  audits the current hand-curated pool.
- **`file <path.json>`** — validate a single `{cols, rows, clues}` puzzle from JSON.
  The hook the generator will call later.

## Testing

- **Rule unit tests** — tiny hand-verified grids (a forced single-clue case, a known
  2×2) asserting specific edges get forced and verdicts are correct.
- **Pool regression** — every *fully-clued* puzzle in `PuzzleData` must validate
  `.unique` with `solution == stored boundary`.
- **Oracle cross-check** — every found solution is confirmed by the app's own
  `PuzzleModel.isSolved(active:)`.
- **Degenerate cases** — no clues → `.multiple`; contradictory clues → `.none`.

## Success criteria

- `swift test` green in `scripts/MycogridSolver/`.
- `mycogrid-validate pool` runs over the real `PuzzleData` and reports a verdict per
  puzzle, exiting non-zero on any non-unique/mismatched puzzle.
- The validator never reads `Puzzle.inside`; it operates solely on `PuzzleClues`.
- Each result carries a populated `SolveTrace` (rule counts + guesses), ready for the
  later grading sub-project.

## Open questions / risks

- **Symlink portability** — fine on this macOS dev setup; revisit only if CI runs elsewhere.
- **Possible non-unique existing puzzles** — RESOLVED for the current pool: the `pool`
  audit found exactly one — **Mycelium #1** had two valid loops once its clues were
  hidden — and it was fixed by revealing one clue (cell `(1,0)`), now uniquely solvable
  with zero guesses. The audit is a permanent regression guard against this recurring.
- **Performance cliff on under-clued grids (deferred to the generator sub-project)** —
  `solve()` is fast on well-clued puzzles but can hang on sparse inputs (a 7×10 grid with
  one clue does not finish quickly). Not an issue for this sub-project's only live input
  (the curated pool). Before the generator feeds under-clued candidates to `solve()`, it
  must add subloop pruning and/or a guess/time budget. Documented as a `KNOWN LIMIT`
  comment in `Solver.swift`.
