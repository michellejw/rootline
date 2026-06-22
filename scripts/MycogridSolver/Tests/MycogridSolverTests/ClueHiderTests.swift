// ClueHiderTests.swift
import XCTest
@testable import MycogridSolver

final class ClueHiderTests: XCTestCase {
    // A small, fully-clued, pure-logic-unique base puzzle (Sprout grove #1 shape).
    private func sproutModel() -> PuzzleModel {
        PuzzleModel(Puzzle(cols: 4, rows: 6, inside: [
            [1,0],[2,0],
            [0,1],[1,1],[2,1],[3,1],
            [0,2],[1,2],[2,2],[3,2],
            [0,3],[1,3],[2,3],[3,3],
            [0,4],[1,4],[2,4],[3,4],
            [1,5],[2,5]
        ]))
    }

    private func solveVisible(_ model: PuzzleModel, hidden: Set<Cell>) -> SolveResult {
        var visible: [Cell: Int] = [:]
        for (cell, n) in model.clues where !hidden.contains(cell) { visible[cell] = n }
        return solve(PuzzleClues(cols: model.puzzle.cols, rows: model.puzzle.rows, clues: visible))
    }

    func test_sproutModel_isFullyCluedPureLogicUnique() {
        let model = sproutModel()
        let result = solveVisible(model, hidden: [])
        XCTAssertEqual(result.verdict, .unique)
        XCTAssertEqual(result.trace.guesses, 0)
    }

    func test_hide_keepsPureLogicUniqueness() {
        let model = sproutModel()
        var rng = SplitMix64(seed: 5)
        let hidden = ClueHider(model: model).hide(using: &rng)
        XCTAssertFalse(hidden.isEmpty, "expected the hider to hide at least one clue")
        let result = solveVisible(model, hidden: hidden)
        XCTAssertEqual(result.verdict, .unique)
        XCTAssertEqual(result.trace.guesses, 0)
    }

    func test_hide_isMaximal() {
        let model = sproutModel()
        var rng = SplitMix64(seed: 5)
        let hidden = ClueHider(model: model).hide(using: &rng)
        // Every still-shown clue, if additionally hidden, must break pure-logic uniqueness.
        for cell in model.clues.keys where !hidden.contains(cell) {
            var more = hidden; more.insert(cell)
            let result = solveVisible(model, hidden: more)
            let stillGood = result.verdict == .unique && result.trace.guesses == 0
            XCTAssertFalse(stillGood, "clue at (\(cell.c),\(cell.r)) could still be hidden — not maximal")
        }
    }

    func test_hide_isDeterministic() {
        let model = sproutModel()
        var a = SplitMix64(seed: 5)
        var b = SplitMix64(seed: 5)
        XCTAssertEqual(ClueHider(model: model).hide(using: &a),
                       ClueHider(model: model).hide(using: &b))
    }
}
