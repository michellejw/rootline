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
