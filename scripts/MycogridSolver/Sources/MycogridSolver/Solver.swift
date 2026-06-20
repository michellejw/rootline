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
