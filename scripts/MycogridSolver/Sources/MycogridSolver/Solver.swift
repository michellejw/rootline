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

        // Post-fixpoint validation: check if any constraint configuration is impossible
        // For clues with onCount + unk > clue, check if remaining unknowns can satisfy all dot constraints
        for con in grid.cellConstraints {
            var onCount = 0
            var unk: [Int] = []
            for i in con.edges {
                if state[i] == on { onCount += 1 }
                else if state[i] == unknown { unk.append(i) }
            }
            // If we have more edges than needed, check feasibility
            if onCount + unk.count > con.clue && onCount < con.clue {
                let needToTurnOn = con.clue - onCount
                if !isClueAssignmentFeasible(unk, needToTurnOn, state) {
                    return false
                }
            }
        }

        return true
    }

    /// Check if we can assign exactly needToTurnOn unknowns to 'on' without violating dot constraints.
    private func isClueAssignmentFeasible(_ unknownEdges: [Int], _ needToTurnOn: Int, _ state: [Int8]) -> Bool {
        // For small counts, check if there exists a valid assignment
        guard unknownEdges.count >= needToTurnOn else { return false }
        guard needToTurnOn <= unknownEdges.count else { return false }

        // Brute force check: try all combinations of choosing needToTurnOn edges
        // For small grids this is acceptable
        return tryAssignments(unknownEdges, needToTurnOn, state, 0, 0, [])
    }

    private func tryAssignments(_ unknowns: [Int], _ needToTurnOn: Int, _ state: [Int8], _ idx: Int, _ turned: Int, _ assignment: [Int]) -> Bool {
        if turned == needToTurnOn {
            // Check if this assignment violates any dot constraint
            var testState = state
            for i in assignment {
                testState[i] = on
            }
            for i in unknowns {
                if !assignment.contains(i) {
                    testState[i] = off
                }
            }
            // Verify all dot constraints
            for inc in grid.dotConstraints {
                var degree = 0
                for i in inc {
                    if testState[i] == on { degree += 1 }
                }
                if degree > 2 || (degree == 1) { return false }
            }
            return true
        }
        if idx >= unknowns.count { return false }
        // Try including unknowns[idx]
        var newAssignment = assignment
        newAssignment.append(unknowns[idx])
        if tryAssignments(unknowns, needToTurnOn, state, idx + 1, turned + 1, newAssignment) {
            return true
        }
        // Try excluding unknowns[idx]
        return tryAssignments(unknowns, needToTurnOn, state, idx + 1, turned, assignment)
    }
}
