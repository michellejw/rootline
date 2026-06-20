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

    // KNOWN LIMIT: when a grid is sparsely clued (few visible clues), this
    // fallback explores unconstrained edges with no subloop pruning, so the
    // search can take a very long time (e.g. a 7x10 grid with a single clue
    // does not finish quickly). This is fine for the curated pool (<=5 guesses
    // per puzzle) and adequately-clued puzzles. The generator sub-project, which
    // will feed under-clued candidates, must add subloop pruning and/or a
    // guess/time budget before relying on solve() for arbitrary inputs.
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
