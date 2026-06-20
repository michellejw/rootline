import XCTest
@testable import MycogridSolver

final class GridTests: XCTestCase {
    func test_puzzleClues_storesFields() {
        let clues = PuzzleClues(cols: 3, rows: 4, clues: [Cell(c: 1, r: 2): 3])
        XCTAssertEqual(clues.cols, 3)
        XCTAssertEqual(clues.rows, 4)
        XCTAssertEqual(clues.clues[Cell(c: 1, r: 2)], 3)
    }

    func test_edgeGrid_1x1_hasFourEdgesAndFourDots() {
        let grid = EdgeGrid(PuzzleClues(cols: 1, rows: 1, clues: [Cell(c: 0, r: 0): 4]))
        XCTAssertEqual(grid.edgeCount, 4)              // 2 horizontal + 2 vertical
        XCTAssertEqual(grid.dotConstraints.count, 4)   // (0,0)(1,0)(0,1)(1,1)
        for inc in grid.dotConstraints {
            XCTAssertEqual(inc.count, 2)               // each corner dot touches 2 edges
        }
        XCTAssertEqual(grid.cellConstraints.count, 1)
        XCTAssertEqual(grid.cellConstraints[0].clue, 4)
        XCTAssertEqual(grid.cellConstraints[0].edges.count, 4)
    }

    func test_edgeGrid_endpoints() {
        let grid = EdgeGrid(PuzzleClues(cols: 1, rows: 1, clues: [:]))
        let (a, b) = grid.endpoints(of: .h(r: 0, c: 0))
        XCTAssertEqual(a, Dot(c: 0, r: 0))
        XCTAssertEqual(b, Dot(c: 1, r: 0))
        let (p, q) = grid.endpoints(of: .v(r: 0, c: 0))
        XCTAssertEqual(p, Dot(c: 0, r: 0))
        XCTAssertEqual(q, Dot(c: 0, r: 1))
    }
}
