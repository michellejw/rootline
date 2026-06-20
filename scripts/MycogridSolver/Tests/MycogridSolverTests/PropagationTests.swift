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

    func test_clue3_on1x1_isContradiction() {
        var s = Solver(grid: EdgeGrid(PuzzleClues(cols: 1, rows: 1, clues: [Cell(c: 0, r: 0): 3])))
        var state = [Int8](repeating: unknown, count: s.grid.edgeCount)
        XCTAssertFalse(s.propagate(&state))
    }
}
