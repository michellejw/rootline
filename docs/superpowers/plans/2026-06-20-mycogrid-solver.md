# Mycogrid Solver (Uniqueness Validator) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an offline Swift CLI + library that proves a set of visible Mycogrid clues admits exactly one closed loop (uniqueness validation), and that audits the existing hand-curated puzzle pool.

**Architecture:** A standalone Swift Package under `scripts/MycogridSolver/`. The app's dependency-free model files (`Edge.swift`, `Engine.swift`, `Tier.swift`, `PuzzleData.swift`) are **symlinked** into the solver's single library target and compiled in-module, so the solver reuses the app's exact types with no duplication. Only `Edge` and `Cell` are promoted to `public` (they appear in the solver's public API); all other app types are used internally and stay untouched. The solver is constraint-propagation + backtracking, short-circuiting at the second solution, emitting a raw difficulty trace.

**Tech Stack:** Swift 5.9, SwiftPM, XCTest. Pure Swift — no external dependencies.

## Global Constraints

- **swift-tools-version: 5.9**, pure Swift, **no external package dependencies**.
- **Only `Edge` (Model/Edge.swift) and `Cell` (Model/Engine.swift) get `public`.** Every other app model type stays `internal` and is used only inside the solver module. Symlinked app files are otherwise read-only.
- **Naming: "Mycogrid".** Never use the word "Slitherlink" anywhere in code, comments, file names, or docs.
- **Validator is blind to the solution.** Its input type carries only `cols`, `rows`, and *visible* clues — never the `inside` region.
- **Public solver entry point:** `func solve(_ clues: PuzzleClues) -> SolveResult`.
- All work happens in the worktree `rootline-rock3/` on branch `feature/rock3-mycogrid-solver`. Commands below assume CWD `scripts/MycogridSolver/` unless stated.

## File Structure

```
scripts/MycogridSolver/
  Package.swift
  .gitignore                              (.build/)
  Sources/
    MycogridSolver/
      AppModel/                           symlinks, compiled in-module
        Edge.swift   -> ../../../../../rootline/Model/Edge.swift
        Engine.swift -> ../../../../../rootline/Model/Engine.swift
        Tier.swift   -> ../../../../../rootline/Model/Tier.swift     (added Task 6)
        PuzzleData.swift -> ../../../../../rootline/Model/PuzzleData.swift (added Task 6)
      PublicTypes.swift     PuzzleClues, Verdict, Rule, SolveTrace, SolveResult
      EdgeGrid.swift        internal grid: edge enumeration + cell/dot adjacency
      Solver.swift          propagate, search, single-loop check, solve()
      Pool.swift            PoolReport, auditPool() (added Task 6)
      JSONInput.swift       loadClues(fromJSON:) (added Task 7)
    mycogrid-validate/
      main.swift            CLI: pool | file <path>   (added Task 7)
  Tests/
    MycogridSolverTests/
      GridTests.swift       (Task 3)
      PropagationTests.swift(Task 4)
      SolverTests.swift     (Task 5)
      PoolTests.swift       (Task 6)
```

---

### Task 1: Package scaffold, symlinks, promote `Edge`/`Cell` to public

**Files:**
- Create: `scripts/MycogridSolver/Package.swift`
- Create: `scripts/MycogridSolver/.gitignore`
- Create symlinks: `scripts/MycogridSolver/Sources/MycogridSolver/AppModel/Edge.swift`, `…/Engine.swift`
- Create: `scripts/MycogridSolver/Sources/MycogridSolver/Placeholder.swift` (temporary, removed Task 2)
- Modify: `rootline/Model/Edge.swift` (mark `Edge` + `Dot` public)
- Modify: `rootline/Model/Engine.swift` (mark `Cell` public + add public init)

**Interfaces:**
- Produces: a buildable package named `MycogridSolver` with the app's `Edge`, `Dot`, `Cell` visible in-module; `Edge` and `Cell` are `public`.

- [ ] **Step 1: Create the package directory and `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MycogridSolver",
    targets: [
        .target(name: "MycogridSolver"),
        .executableTarget(name: "mycogrid-validate", dependencies: ["MycogridSolver"]),
        .testTarget(name: "MycogridSolverTests", dependencies: ["MycogridSolver"]),
    ]
)
```

- [ ] **Step 2: Create `.gitignore`**

```
.build/
```

- [ ] **Step 3: Create the symlinks to the app model files**

Run from the repo root (`rootline-rock3/`):

```bash
mkdir -p scripts/MycogridSolver/Sources/MycogridSolver/AppModel
mkdir -p scripts/MycogridSolver/Sources/mycogrid-validate
mkdir -p scripts/MycogridSolver/Tests/MycogridSolverTests
cd scripts/MycogridSolver/Sources/MycogridSolver/AppModel
ln -s ../../../../../rootline/Model/Edge.swift Edge.swift
ln -s ../../../../../rootline/Model/Engine.swift Engine.swift
cd -
ls -l scripts/MycogridSolver/Sources/MycogridSolver/AppModel
```
Expected: both symlinks resolve (arrow target prints, no "No such file").

- [ ] **Step 4: Promote `Edge` and `Dot` to public in `rootline/Model/Edge.swift`**

Change the type declarations (enum cases of a public enum are public automatically; the `cellEdges` helper stays internal — only used in-module):

```swift
public enum Edge: Hashable, Codable, Sendable {
    case h(r: Int, c: Int)
    case v(r: Int, c: Int)
}

public struct Dot: Hashable, Codable, Sendable {
    public let c: Int
    public let r: Int
    public init(c: Int, r: Int) { self.c = c; self.r = r }
}
```
Leave `static func cellEdges(...)` and everything else in the file unchanged.

- [ ] **Step 5: Promote `Cell` to public in `rootline/Model/Engine.swift`**

Make the `Cell` struct, its properties, and a memberwise init public. Leave `Puzzle`, `PuzzleModel`, and all other types unchanged:

```swift
public struct Cell: Hashable, Codable, Sendable {
    public let c: Int
    public let r: Int
    public init(c: Int, r: Int) { self.c = c; self.r = r }
}
```
If `Cell` already declares an init or additional members, keep them and only add `public` plus the public init shown above.

- [ ] **Step 6: Add a temporary placeholder so the target has a non-symlink source**

Create `Sources/MycogridSolver/Placeholder.swift`:

```swift
// Temporary — removed in Task 2 once PublicTypes.swift exists.
let mycogridSolverPlaceholder = true
```

- [ ] **Step 7: Build**

Run (from `scripts/MycogridSolver/`):

```bash
swift build
```
Expected: `Build complete!`

**Contingency:** If the build reports a missing model symbol (e.g. `Engine.swift` references a type defined in another file), symlink that additional **model-only** file into `AppModel/` and rebuild. If a referenced file imports `SwiftUI`/`UIKit`, do NOT symlink it — instead note the symbol and copy the minimal type into a new in-module file. Record any such deviation in a comment at the top of `Package.swift`.

- [ ] **Step 8: Commit**

```bash
git add scripts/MycogridSolver rootline/Model/Edge.swift rootline/Model/Engine.swift
git commit -m "feat: scaffold MycogridSolver package, symlink app model, make Edge/Cell public"
```

---

### Task 2: Public types

**Files:**
- Create: `scripts/MycogridSolver/Sources/MycogridSolver/PublicTypes.swift`
- Delete: `scripts/MycogridSolver/Sources/MycogridSolver/Placeholder.swift`
- Test: `scripts/MycogridSolver/Tests/MycogridSolverTests/GridTests.swift` (a types sanity test; grid tests appended in Task 3)

**Interfaces:**
- Produces:
  - `struct PuzzleClues { let cols: Int; let rows: Int; let clues: [Cell: Int]; init(cols:rows:clues:) }`
  - `enum Verdict: String { case none, unique, multiple }`
  - `enum Rule { case clue, dot }`
  - `struct SolveTrace { var rulesFired: [Rule: Int]; var guesses: Int; var maxDepth: Int }`
  - `struct SolveResult { let verdict: Verdict; let solution: Set<Edge>?; let witness: Set<Edge>?; let trace: SolveTrace }`

- [ ] **Step 1: Write the failing test**

Create `Tests/MycogridSolverTests/GridTests.swift`:

```swift
import XCTest
@testable import MycogridSolver

final class GridTests: XCTestCase {
    func test_puzzleClues_storesFields() {
        let clues = PuzzleClues(cols: 3, rows: 4, clues: [Cell(c: 1, r: 2): 3])
        XCTAssertEqual(clues.cols, 3)
        XCTAssertEqual(clues.rows, 4)
        XCTAssertEqual(clues.clues[Cell(c: 1, r: 2)], 3)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test
```
Expected: FAIL — `cannot find 'PuzzleClues' in scope`.

- [ ] **Step 3: Create `PublicTypes.swift` and delete the placeholder**

```swift
public struct PuzzleClues: Sendable {
    public let cols: Int
    public let rows: Int
    /// Visible clues only. A cell absent from this map carries no constraint.
    public let clues: [Cell: Int]
    public init(cols: Int, rows: Int, clues: [Cell: Int]) {
        self.cols = cols
        self.rows = rows
        self.clues = clues
    }
}

public enum Verdict: String, Sendable { case none, unique, multiple }

public enum Rule: Hashable, Sendable { case clue, dot }

public struct SolveTrace: Equatable, Sendable {
    public var rulesFired: [Rule: Int]
    public var guesses: Int
    public var maxDepth: Int
    public init(rulesFired: [Rule: Int] = [:], guesses: Int = 0, maxDepth: Int = 0) {
        self.rulesFired = rulesFired
        self.guesses = guesses
        self.maxDepth = maxDepth
    }
}

public struct SolveResult: Sendable {
    public let verdict: Verdict
    /// The loop when `.unique`; one example loop when `.multiple`.
    public let solution: Set<Edge>?
    /// The second, distinct loop when `.multiple` — proof of non-uniqueness.
    public let witness: Set<Edge>?
    public let trace: SolveTrace
    public init(verdict: Verdict, solution: Set<Edge>?, witness: Set<Edge>?, trace: SolveTrace) {
        self.verdict = verdict
        self.solution = solution
        self.witness = witness
        self.trace = trace
    }
}
```
Then remove the placeholder:

```bash
rm Sources/MycogridSolver/Placeholder.swift
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test
```
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add scripts/MycogridSolver
git commit -m "feat: add MycogridSolver public types (PuzzleClues, SolveResult, trace)"
```

---

### Task 3: EdgeGrid — edge enumeration and adjacency

**Files:**
- Create: `scripts/MycogridSolver/Sources/MycogridSolver/EdgeGrid.swift`
- Test: `scripts/MycogridSolver/Tests/MycogridSolverTests/GridTests.swift` (append)

**Interfaces:**
- Consumes: `PuzzleClues`, app `Edge`, `Dot`, `Edge.cellEdges(c:r:)`.
- Produces (internal):
  - `struct EdgeGrid { init(_ clues: PuzzleClues); let edges: [Edge]; var edgeCount: Int; let cellConstraints: [(clue: Int, edges: [Int])]; let dotConstraints: [[Int]]; func endpoints(of: Edge) -> (Dot, Dot) }`
  - Edge index convention: horizontals `h(r,c)` for `r in 0...rows, c in 0..<cols` first, then verticals `v(r,c)` for `r in 0..<rows, c in 0...cols`.

- [ ] **Step 1: Write the failing test (append to `GridTests.swift`)**

```swift
    func test_edgeGrid_1x1_hasFourEdgesAndFourDots() {
        let grid = EdgeGrid(PuzzleClues(cols: 1, rows: 1, clues: [Cell(c: 0, r: 0): 4]))
        XCTAssertEqual(grid.edgeCount, 4)              // 2 horizontal + 2 vertical
        XCTAssertEqual(grid.dotConstraints.count, 4)   // (0,0)(1,0)(0,1)(1,1)
        for inc in grid.dotConstraints {
            XCTAssertEqual(inc.count, 2)               // each corner dot touches 2 edges
        }
        XCTAssertEqual(grid.cellConstraints.count, 1)
        XCTAssertEqual(grid.cellConstraints[0].clue, 4)
        XCTAssertEqual(grid.cellConstraints[0].edges.count, 4)
    }

    func test_edgeGrid_endpoints() {
        let grid = EdgeGrid(PuzzleClues(cols: 1, rows: 1, clues: [:]))
        let (a, b) = grid.endpoints(of: .h(r: 0, c: 0))
        XCTAssertEqual(a, Dot(c: 0, r: 0))
        XCTAssertEqual(b, Dot(c: 1, r: 0))
        let (p, q) = grid.endpoints(of: .v(r: 0, c: 0))
        XCTAssertEqual(p, Dot(c: 0, r: 0))
        XCTAssertEqual(q, Dot(c: 0, r: 1))
    }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test
```
Expected: FAIL — `cannot find 'EdgeGrid' in scope`.

- [ ] **Step 3: Create `EdgeGrid.swift`**

```swift
struct EdgeGrid {
    let cols: Int
    let rows: Int
    let edges: [Edge]
    private let indexOf: [Edge: Int]
    /// One entry per clued cell: the required count and the indices of its 4 edges.
    let cellConstraints: [(clue: Int, edges: [Int])]
    /// One entry per dot (row-major over `(0...rows) x (0...cols)`): incident edge indices.
    let dotConstraints: [[Int]]

    var edgeCount: Int { edges.count }

    init(_ clues: PuzzleClues) {
        var edges: [Edge] = []
        var indexOf: [Edge: Int] = [:]
        func add(_ e: Edge) { indexOf[e] = edges.count; edges.append(e) }
        for r in 0...clues.rows { for c in 0..<clues.cols { add(.h(r: r, c: c)) } }
        for r in 0..<clues.rows { for c in 0...clues.cols { add(.v(r: r, c: c)) } }
        self.cols = clues.cols
        self.rows = clues.rows
        self.edges = edges
        self.indexOf = indexOf

        var cellCon: [(clue: Int, edges: [Int])] = []
        for (cell, n) in clues.clues {
            let es = Edge.cellEdges(c: cell.c, r: cell.r).map { indexOf[$0]! }
            cellCon.append((clue: n, edges: es))
        }
        self.cellConstraints = cellCon

        var dotCon: [[Int]] = []
        for r in 0...clues.rows {
            for c in 0...clues.cols {
                var inc: [Int] = []
                if c - 1 >= 0 { inc.append(indexOf[.h(r: r, c: c - 1)]!) }
                if c < clues.cols { inc.append(indexOf[.h(r: r, c: c)]!) }
                if r - 1 >= 0 { inc.append(indexOf[.v(r: r - 1, c: c)]!) }
                if r < clues.rows { inc.append(indexOf[.v(r: r, c: c)]!) }
                dotCon.append(inc)
            }
        }
        self.dotConstraints = dotCon
    }

    func endpoints(of e: Edge) -> (Dot, Dot) {
        switch e {
        case let .h(r, c): return (Dot(c: c, r: r), Dot(c: c + 1, r: r))
        case let .v(r, c): return (Dot(c: c, r: r), Dot(c: c, r: r + 1))
        }
    }
}
```

**Contingency:** If `Edge.cellEdges(c:r:)` does not exist or has a different label in `rootline/Model/Edge.swift`, replace the `es` line with the explicit four edges: `[.h(r: cell.r, c: cell.c), .h(r: cell.r + 1, c: cell.c), .v(r: cell.r, c: cell.c), .v(r: cell.r, c: cell.c + 1)].map { indexOf[$0]! }`.

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/MycogridSolver
git commit -m "feat: add EdgeGrid edge enumeration and cell/dot adjacency"
```

---

### Task 4: Constraint propagation (clue + dot rules)

**Files:**
- Create: `scripts/MycogridSolver/Sources/MycogridSolver/Solver.swift` (Solver struct + propagate; search added in Task 5)
- Test: `scripts/MycogridSolver/Tests/MycogridSolverTests/PropagationTests.swift`

**Interfaces:**
- Consumes: `EdgeGrid`, `SolveTrace`.
- Produces (internal):
  - edge-state constants `unknown: Int8 = 0`, `on: Int8 = 1`, `off: Int8 = 2`
  - `struct Solver { init(grid: EdgeGrid); let grid: EdgeGrid; var trace: SolveTrace; var solutions: [[Int8]]; mutating func propagate(_ state: inout [Int8]) -> Bool }`
  - `propagate` returns `false` on contradiction, otherwise mutates `state` to a fixpoint.

- [ ] **Step 1: Write the failing test**

Create `Tests/MycogridSolverTests/PropagationTests.swift`:

```swift
import XCTest
@testable import MycogridSolver

final class PropagationTests: XCTestCase {
    func test_clue4_on1x1_forcesAllEdgesOn() {
        var s = Solver(grid: EdgeGrid(PuzzleClues(cols: 1, rows: 1, clues: [Cell(c: 0, r: 0): 4])))
        var state = [Int8](repeating: unknown, count: s.grid.edgeCount)
        XCTAssertTrue(s.propagate(&state))
        XCTAssertTrue(state.allSatisfy { $0 == on })
        XCTAssertGreaterThan(s.trace.rulesFired[.clue, default: 0], 0)
    }

    func test_clue0_on1x1_forcesAllEdgesOff() {
        var s = Solver(grid: EdgeGrid(PuzzleClues(cols: 1, rows: 1, clues: [Cell(c: 0, r: 0): 0])))
        var state = [Int8](repeating: unknown, count: s.grid.edgeCount)
        XCTAssertTrue(s.propagate(&state))
        XCTAssertTrue(state.allSatisfy { $0 == off })
    }

    func test_clue4_withOneEdgeOff_isContradiction() {
        // A 1x1 cell needs all 4 edges on, but one is already off → clue 4 is
        // unreachable, so propagation must report a contradiction immediately.
        var s = Solver(grid: EdgeGrid(PuzzleClues(cols: 1, rows: 1, clues: [Cell(c: 0, r: 0): 4])))
        var state = [Int8](repeating: unknown, count: s.grid.edgeCount)
        state[0] = off
        XCTAssertFalse(s.propagate(&state))
    }
}

> **Note:** `propagate` only catches contradictions that follow from the
> *current* forced edges (e.g. a clue whose remaining unknowns can no longer
> reach its count). It does NOT detect a contradiction that requires trying
> assignments — e.g. an all-unknown 1×1 with clue 3 is unsatisfiable, but no
> single rule fires, so `propagate` returns `true` and search (Task 5) finds
> the contradiction. That case is covered by Task 5's
> `test_contradictoryClue_isNone`. Do NOT add brute-force feasibility
> enumeration to `propagate`.
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test
```
Expected: FAIL — `cannot find 'Solver' in scope`.

- [ ] **Step 3: Create `Solver.swift` with the Solver struct and `propagate`**

```swift
let unknown: Int8 = 0
let on: Int8 = 1
let off: Int8 = 2

struct Solver {
    let grid: EdgeGrid
    var trace = SolveTrace()
    var solutions: [[Int8]] = []

    init(grid: EdgeGrid) { self.grid = grid }

    /// Applies clue + dot deductions to a fixpoint. Returns false on contradiction.
    mutating func propagate(_ state: inout [Int8]) -> Bool {
        var changed = true
        while changed {
            changed = false

            // Clue rule
            for con in grid.cellConstraints {
                var onCount = 0
                var unk: [Int] = []
                for i in con.edges {
                    if state[i] == on { onCount += 1 }
                    else if state[i] == unknown { unk.append(i) }
                }
                if onCount > con.clue { return false }
                if onCount + unk.count < con.clue { return false }
                if unk.isEmpty { continue }
                if onCount == con.clue {
                    for i in unk { state[i] = off }
                    trace.rulesFired[.clue, default: 0] += unk.count
                    changed = true
                } else if onCount + unk.count == con.clue {
                    for i in unk { state[i] = on }
                    trace.rulesFired[.clue, default: 0] += unk.count
                    changed = true
                }
            }

            // Dot rule: every dot's degree must be 0 or 2, never 1.
            for inc in grid.dotConstraints {
                var onCount = 0
                var unk: [Int] = []
                for i in inc {
                    if state[i] == on { onCount += 1 }
                    else if state[i] == unknown { unk.append(i) }
                }
                if onCount > 2 { return false }
                if onCount == 1 && unk.isEmpty { return false } // would be degree 1
                if onCount == 2 && !unk.isEmpty {
                    for i in unk { state[i] = off }
                    trace.rulesFired[.dot, default: 0] += unk.count
                    changed = true
                } else if onCount == 1 && unk.count == 1 {
                    state[unk[0]] = on
                    trace.rulesFired[.dot, default: 0] += 1
                    changed = true
                } else if onCount == 0 && unk.count == 1 {
                    state[unk[0]] = off
                    trace.rulesFired[.dot, default: 0] += 1
                    changed = true
                }
            }
        }
        return true
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test
```
Expected: PASS (6 tests total).

- [ ] **Step 5: Commit**

```bash
git add scripts/MycogridSolver
git commit -m "feat: add constraint propagation (clue + dot rules)"
```

---

### Task 5: Search, single-loop acceptance, and `solve` with uniqueness

**Files:**
- Modify: `scripts/MycogridSolver/Sources/MycogridSolver/Solver.swift` (add `search`, `chooseUnknown`, `isSingleLoop`, `run`, top-level `solve`)
- Test: `scripts/MycogridSolver/Tests/MycogridSolverTests/SolverTests.swift`

**Interfaces:**
- Consumes: `Solver.propagate`, `EdgeGrid.endpoints`, `SolveResult`, `Verdict`.
- Produces:
  - `public func solve(_ clues: PuzzleClues) -> SolveResult`
  - internal `Solver.run`, `Solver.search(_:depth:)`, `Solver.chooseUnknown(_:)`, `Solver.isSingleLoop(_:)`
  - Acceptance: a full assignment passing propagation whose on-edges form exactly one non-empty closed loop.

- [ ] **Step 1: Write the failing test**

Create `Tests/MycogridSolverTests/SolverTests.swift`:

```swift
import XCTest
@testable import MycogridSolver

final class SolverTests: XCTestCase {
    func test_1x1_clue4_isUniqueWithFourEdges() {
        let result = solve(PuzzleClues(cols: 1, rows: 1, clues: [Cell(c: 0, r: 0): 4]))
        XCTAssertEqual(result.verdict, .unique)
        XCTAssertEqual(result.solution?.count, 4)
        XCTAssertNil(result.witness)
        XCTAssertEqual(result.trace.guesses, 0) // solved by pure deduction
    }

    func test_noClues_isMultiple() {
        let result = solve(PuzzleClues(cols: 2, rows: 2, clues: [:]))
        XCTAssertEqual(result.verdict, .multiple)
        XCTAssertNotNil(result.solution)
        XCTAssertNotNil(result.witness)
        XCTAssertNotEqual(result.solution, result.witness)
    }

    func test_contradictoryClue_isNone() {
        let result = solve(PuzzleClues(cols: 1, rows: 1, clues: [Cell(c: 0, r: 0): 3]))
        XCTAssertEqual(result.verdict, .none)
        XCTAssertNil(result.solution)
    }

    func test_twoAdjacentCells_clued_isSingleLoop() {
        // A 2x1 board where both cells are inside: the boundary is one 6-edge loop.
        let result = solve(PuzzleClues(cols: 2, rows: 1,
            clues: [Cell(c: 0, r: 0): 3, Cell(c: 1, r: 0): 3]))
        XCTAssertEqual(result.verdict, .unique)
        XCTAssertEqual(result.solution?.count, 6)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test
```
Expected: FAIL — `cannot find 'solve' in scope`.

- [ ] **Step 3: Add search, acceptance, and `solve` to `Solver.swift`**

Append to `Solver.swift`:

```swift
public func solve(_ clues: PuzzleClues) -> SolveResult {
    var solver = Solver(grid: EdgeGrid(clues))
    return solver.run()
}

extension Solver {
    mutating func run() -> SolveResult {
        var state = [Int8](repeating: unknown, count: grid.edgeCount)
        search(&state, depth: 0)
        let verdict: Verdict = solutions.isEmpty
            ? .none
            : (solutions.count == 1 ? .unique : .multiple)
        return SolveResult(
            verdict: verdict,
            solution: solutions.first.map(edgeSet),
            witness: solutions.count >= 2 ? edgeSet(solutions[1]) : nil,
            trace: trace
        )
    }

    func edgeSet(_ st: [Int8]) -> Set<Edge> {
        var set = Set<Edge>()
        for i in grid.edges.indices where st[i] == on { set.insert(grid.edges[i]) }
        return set
    }

    mutating func search(_ state: inout [Int8], depth: Int) {
        if solutions.count >= 2 { return } // short-circuit: two is enough to prove non-unique
        trace.maxDepth = max(trace.maxDepth, depth)
        var st = state
        if !propagate(&st) { return }
        guard let pick = chooseUnknown(st) else {
            if isSingleLoop(st) { solutions.append(st) }
            return
        }
        trace.guesses += 1
        st[pick] = on
        search(&st, depth: depth + 1)
        if solutions.count >= 2 { return }
        st[pick] = off
        search(&st, depth: depth + 1)
    }

    /// Most-constrained-variable: an unknown edge of the clued cell with the fewest unknowns.
    func chooseUnknown(_ st: [Int8]) -> Int? {
        var best: Int?
        var bestUnk = Int.max
        for con in grid.cellConstraints {
            let unk = con.edges.filter { st[$0] == unknown }
            if !unk.isEmpty && unk.count < bestUnk {
                bestUnk = unk.count
                best = unk[0]
            }
        }
        if let best { return best }
        return st.firstIndex(of: unknown)
    }

    /// True iff the on-edges form exactly one non-empty closed loop.
    func isSingleLoop(_ st: [Int8]) -> Bool {
        let onEdges = grid.edges.indices.filter { st[$0] == on }
        guard let start = onEdges.first else { return false }
        var dotEdges: [Dot: [Int]] = [:]
        for i in onEdges {
            let (a, b) = grid.endpoints(of: grid.edges[i])
            dotEdges[a, default: []].append(i)
            dotEdges[b, default: []].append(i)
        }
        var visited = Set<Int>()
        var currentEdge = start
        var currentDot = grid.endpoints(of: grid.edges[start]).0
        while !visited.contains(currentEdge) {
            visited.insert(currentEdge)
            let (a, b) = grid.endpoints(of: grid.edges[currentEdge])
            let nextDot = (a == currentDot) ? b : a
            guard let next = (dotEdges[nextDot] ?? []).first(where: { $0 != currentEdge }) else {
                return false
            }
            currentEdge = next
            currentDot = nextDot
        }
        return visited.count == onEdges.count
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test
```
Expected: PASS (10 tests total). If `test_twoAdjacentCells_clued_isSingleLoop` fails on edge count, print the solution and confirm the expected loop length for a 2×1 inside region is 6 (top 2 + bottom 2 + left 1 + right 1).

- [ ] **Step 5: Commit**

```bash
git add scripts/MycogridSolver
git commit -m "feat: add backtracking search, single-loop acceptance, and uniqueness solve()"
```

---

### Task 6: Pool audit against the existing curated puzzles

**Files:**
- Create symlinks: `Sources/MycogridSolver/AppModel/Tier.swift`, `…/PuzzleData.swift`
- Create: `scripts/MycogridSolver/Sources/MycogridSolver/Pool.swift`
- Test: `scripts/MycogridSolver/Tests/MycogridSolverTests/PoolTests.swift`

**Interfaces:**
- Consumes (internal, intra-module): `Tier.allCases`, `tier.label`, `PuzzleData.puzzles(for:)`, `Puzzle.cols`, `Puzzle.rows`, `Puzzle.hideClues`, `PuzzleModel(_:)`, `PuzzleModel.clues`, `PuzzleModel.solution`, `PuzzleModel.isSolved(active:)`.
- Produces:
  - `public struct PoolReport { let label: String; let verdict: Verdict; let matchesStored: Bool; let oracleOK: Bool; let guesses: Int; var passed: Bool }`
  - `public func auditPool() -> [PoolReport]`

- [ ] **Step 1: Add the remaining symlinks**

From `rootline-rock3/`:

```bash
cd scripts/MycogridSolver/Sources/MycogridSolver/AppModel
ln -s ../../../../../rootline/Model/Tier.swift Tier.swift
ln -s ../../../../../rootline/Model/PuzzleData.swift PuzzleData.swift
cd -
swift build
```
Expected: `Build complete!`

**Contingency:** If the build fails because `PuzzleData.swift` or `Tier.swift` references a symbol from another file (e.g. a `Lesson`/tutorial type or `DrawMode`), symlink that **model-only** file too. If the missing symbol lives in a file that imports `SwiftUI`/`UIKit`, copy just that type into a small in-module file instead. Note any such addition in a `Package.swift` comment.

- [ ] **Step 2: Verify the app member names this task depends on**

Read `rootline/Model/Engine.swift` and `rootline/Model/Tier.swift` and confirm: `PuzzleModel(_:)` initializer, `.clues: [Cell: Int]`, `.solution: Set<Edge>`, `func isSolved(active: Set<Edge>) -> Bool`, `Tier: CaseIterable`, `tier.label`, `PuzzleData.puzzles(for:) -> [Puzzle]`, `Puzzle.hideClues: Set<Cell>`. If any name differs, adjust `Pool.swift` in Step 4 to match.

- [ ] **Step 3: Write the failing test**

Create `Tests/MycogridSolverTests/PoolTests.swift`:

```swift
import XCTest
@testable import MycogridSolver

final class PoolTests: XCTestCase {
    func test_pool_isNonEmpty_andEveryPuzzleIsUniqueAndMatchesStored() {
        let reports = auditPool()
        XCTAssertFalse(reports.isEmpty, "auditPool returned no puzzles")
        let failures = reports.filter { !$0.passed }
        XCTAssertTrue(failures.isEmpty, "puzzles failed validation: " +
            failures.map {
                "\($0.label)[\($0.verdict.rawValue) match=\($0.matchesStored) oracle=\($0.oracleOK)]"
            }.joined(separator: ", "))
    }
}
```

**Note for the implementer:** A failure here may NOT be a solver bug. If a puzzle reports `.multiple`, that hand-curated puzzle is genuinely non-unique once its hidden clues are removed — exactly the kind of defect this tool exists to find (see the design spec's "Open questions"). Before changing solver code, hand-verify one reported puzzle. If it is truly non-unique, that is a real finding to surface to Michelle as a follow-up, not a reason to weaken the test.

- [ ] **Step 4: Run test to verify it fails**

```bash
swift test
```
Expected: FAIL — `cannot find 'auditPool' in scope`.

- [ ] **Step 5: Create `Pool.swift`**

```swift
public struct PoolReport: Sendable {
    public let label: String
    public let verdict: Verdict
    public let matchesStored: Bool
    public let oracleOK: Bool
    public let guesses: Int
    public var passed: Bool { verdict == .unique && matchesStored && oracleOK }
}

public func auditPool() -> [PoolReport] {
    var out: [PoolReport] = []
    for tier in Tier.allCases {
        for (i, puzzle) in PuzzleData.puzzles(for: tier).enumerated() {
            out.append(auditPuzzle(puzzle, label: "\(tier.label) #\(i + 1)"))
        }
    }
    return out
}

func auditPuzzle(_ puzzle: Puzzle, label: String) -> PoolReport {
    let model = PuzzleModel(puzzle)
    // Visible clues = derived clues minus the hidden ones (what a player actually sees).
    var visible: [Cell: Int] = [:]
    for (cell, n) in model.clues where !puzzle.hideClues.contains(cell) {
        visible[cell] = n
    }
    let result = solve(PuzzleClues(cols: puzzle.cols, rows: puzzle.rows, clues: visible))
    let matchesStored = result.solution == model.solution
    let oracleOK = result.solution.map { model.isSolved(active: $0) } ?? false
    return PoolReport(
        label: label,
        verdict: result.verdict,
        matchesStored: matchesStored,
        oracleOK: oracleOK,
        guesses: result.trace.guesses
    )
}
```

- [ ] **Step 6: Run test to verify it passes**

```bash
swift test
```
Expected: PASS. If it fails with `.multiple` on a real puzzle, follow the Step 3 note (investigate before touching solver code).

- [ ] **Step 7: Commit**

```bash
git add scripts/MycogridSolver
git commit -m "feat: audit existing curated puzzle pool for uniqueness + stored-solution match"
```

---

### Task 7: CLI executable (`pool` and `file` commands)

**Files:**
- Create: `scripts/MycogridSolver/Sources/MycogridSolver/JSONInput.swift`
- Create: `scripts/MycogridSolver/Sources/mycogrid-validate/main.swift`

**Interfaces:**
- Consumes: `auditPool()`, `solve(_:)`, `PoolReport`, `SolveResult`.
- Produces:
  - `public func loadClues(fromJSON data: Data) throws -> PuzzleClues` (JSON: `{ "cols": Int, "rows": Int, "clues": [{ "c": Int, "r": Int, "n": Int }] }`)
  - executable `mycogrid-validate` with subcommands `pool` and `file <path>`; exit code non-zero when any puzzle is non-unique.

- [ ] **Step 1: Create `JSONInput.swift`**

```swift
import Foundation

struct ClueJSON: Codable { let c: Int; let r: Int; let n: Int }
struct PuzzleJSON: Codable { let cols: Int; let rows: Int; let clues: [ClueJSON] }

public func loadClues(fromJSON data: Data) throws -> PuzzleClues {
    let p = try JSONDecoder().decode(PuzzleJSON.self, from: data)
    var dict: [Cell: Int] = [:]
    for cl in p.clues { dict[Cell(c: cl.c, r: cl.r)] = cl.n }
    return PuzzleClues(cols: p.cols, rows: p.rows, clues: dict)
}
```

- [ ] **Step 2: Create the CLI `main.swift`**

```swift
import Foundation
import MycogridSolver

func pad(_ s: String, _ w: Int) -> String {
    s.count >= w ? s : s + String(repeating: " ", count: w - s.count)
}

func fail(_ msg: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(code)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    fail("usage: mycogrid-validate <pool | file <path>>", code: 2)
}

switch args[1] {
case "pool":
    let reports = auditPool()
    print("\(pad("tier/grove", 22)) \(pad("verdict", 9)) \(pad("guesses", 8)) \(pad("match", 6)) \(pad("oracle", 7)) result")
    var anyFail = false
    for r in reports {
        if !r.passed { anyFail = true }
        print("\(pad(r.label, 22)) \(pad(r.verdict.rawValue, 9)) \(pad(String(r.guesses), 8)) \(pad(r.matchesStored ? "yes" : "no", 6)) \(pad(r.oracleOK ? "yes" : "no", 7)) \(r.passed ? "PASS" : "FAIL")")
    }
    exit(anyFail ? 1 : 0)

case "file":
    guard args.count >= 3 else { fail("usage: mycogrid-validate file <path>", code: 2) }
    let result: SolveResult
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
        result = solve(try loadClues(fromJSON: data))
    } catch {
        fail("error reading \(args[2]): \(error)", code: 2)
    }
    print("verdict: \(result.verdict.rawValue)")
    print("guesses: \(result.trace.guesses), maxDepth: \(result.trace.maxDepth)")
    if result.verdict == .multiple { print("NOT UNIQUE — two distinct loops exist") }
    exit(result.verdict == .unique ? 0 : 1)

default:
    fail("unknown command: \(args[1])", code: 2)
}
```

- [ ] **Step 3: Build and run the pool audit end-to-end**

```bash
swift build
swift run mycogrid-validate pool
echo "exit=$?"
```
Expected: a printed table with one row per curated puzzle and a final `exit=0` (or `exit=1` with at least one `FAIL` row — if so, follow the Task 6 Step 3 note: investigate whether that puzzle is genuinely non-unique before treating it as a bug).

- [ ] **Step 4: Smoke-test `file` mode**

```bash
cat > /tmp/mg-1x1.json <<'JSON'
{ "cols": 1, "rows": 1, "clues": [ { "c": 0, "r": 0, "n": 4 } ] }
JSON
swift run mycogrid-validate file /tmp/mg-1x1.json
echo "exit=$?"
```
Expected: `verdict: unique`, `guesses: 0`, `exit=0`.

- [ ] **Step 5: Commit**

```bash
git add scripts/MycogridSolver
git commit -m "feat: add mycogrid-validate CLI (pool audit + single-file validation)"
```

---

## Self-Review

**Spec coverage:**
- Symlink sharing, app untouched except `Edge`/`Cell` public → Task 1. *(Deviation: spec said "app untouched"; we mark exactly two types `public`. This was approved as the professional choice over a parallel-types bridge.)*
- Blind validator (`PuzzleClues` has no `inside`) → Task 2.
- Constraint propagation (clue + dot rules) → Task 4.
- Backtracking + single-loop acceptance + uniqueness short-circuit → Task 5.
- Raw difficulty trace (`rulesFired`, `guesses`, `maxDepth`) → Tasks 2/4/5. *(Known roughness: the trace is cumulative across the whole search, not just the winning path — acceptable as "raw signal"; sharpening it is the later grading sub-project's job.)*
- CLI `pool` (audits curated pool, non-zero exit on failure) → Tasks 6 + 7.
- CLI `file <path.json>` → Task 7.
- Tests: tiny grids, pool regression, oracle cross-check (`isSolved`), degenerate cases → Tasks 3–6.

**Placeholder scan:** No "TBD"/"handle edge cases" steps; every code step shows complete code. The two `Contingency` notes are concrete fallbacks (which file to symlink / how to verify member names), not vague deferrals.

**Type consistency:** `unknown/on/off: Int8` constants shared across Tasks 4–5. `PoolReport.passed` defined once (Task 6) and consumed by the CLI (Task 7). `solve` / `auditPool` / `loadClues` signatures match between producer and consumer tasks. Public API uses app `Edge`/`Cell` throughout (no `GridEdge`/`GridCell` — the bridge approach was dropped).

## Risks / open items (carry to execution)

- **Symlink build surprises** — if `PuzzleData.swift`/`Tier.swift` drag in non-model dependencies, follow the Task 6 contingency.
- **Sparse non-unique puzzles could be slow** — propagation handles dense clue sets fast; if any unique puzzle with very few visible clues makes the search crawl, that is a signal to add the deferred subloop-pruning optimization (out of scope now).
- **A genuinely non-unique curated puzzle** — surfaced by `auditPool`; this is a finding for Michelle, decided as a follow-up, not part of this sub-project.
