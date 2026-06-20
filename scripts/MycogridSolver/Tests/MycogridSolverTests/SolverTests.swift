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

    func test_isSingleLoop_rejectsTwoDisjointLoops() {
        // 3x1 grid: turn cell (0,0) and cell (2,0) into two separate unit loops.
        // Their edge sets don't overlap, so the on-edges form two disjoint loops,
        // which isSingleLoop must reject.
        let s = Solver(grid: EdgeGrid(PuzzleClues(cols: 3, rows: 1, clues: [:])))
        var state = [Int8](repeating: off, count: s.grid.edgeCount)
        for e in Edge.cellEdges(c: 0, r: 0) + Edge.cellEdges(c: 2, r: 0) {
            state[s.grid.edges.firstIndex(of: e)!] = on
        }
        XCTAssertFalse(s.isSingleLoop(state), "two disjoint unit loops must be rejected")
    }

    func test_isSingleLoop_acceptsOneLoop() {
        // Positive control: a single unit loop on a 1x1 grid is a valid single loop.
        let s = Solver(grid: EdgeGrid(PuzzleClues(cols: 1, rows: 1, clues: [:])))
        let state = [Int8](repeating: on, count: s.grid.edgeCount)
        XCTAssertTrue(s.isSingleLoop(state))
    }
}
