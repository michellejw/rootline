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
