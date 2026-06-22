/// Greedily hides as many clues as the 2-rule solver tolerates while keeping the
/// puzzle uniquely solvable by pure logic (`guesses == 0`). The achievable
/// density emerges from what the solver can deduce.
struct ClueHider {
    let model: PuzzleModel

    func hide(using rng: inout some RandomNumberGenerator) -> Set<Cell> {
        let cols = model.puzzle.cols
        let rows = model.puzzle.rows
        var hidden: Set<Cell> = []

        // Deterministic order: sort clue cells, then shuffle with the seeded RNG.
        let order = model.clues.keys
            .sorted { ($0.r, $0.c) < ($1.r, $1.c) }
            .shuffled(using: &rng)

        for cell in order {
            var trial = hidden
            trial.insert(cell)
            var visible: [Cell: Int] = [:]
            for (cl, n) in model.clues where !trial.contains(cl) { visible[cl] = n }
            let result = solve(PuzzleClues(cols: cols, rows: rows, clues: visible))
            if result.verdict == .unique && result.trace.guesses == 0 {
                hidden = trial
            }
        }
        return hidden
    }
}
