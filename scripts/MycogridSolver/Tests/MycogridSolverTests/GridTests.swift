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
