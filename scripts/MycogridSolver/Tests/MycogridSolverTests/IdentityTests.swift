import XCTest
@testable import MycogridSolver

final class IdentityTests: XCTestCase {
    private func cells(_ pairs: [[Int]]) -> Set<Cell> {
        Set(pairs.map { Cell(c: $0[0], r: $0[1]) })
    }

    func test_canonicalKey_isOrderIndependent() {
        let a = cells([[0,0],[1,0],[1,1]])
        let b = cells([[1,1],[0,0],[1,0]])
        XCTAssertEqual(canonicalKey(cols: 2, rows: 2, inside: a),
                       canonicalKey(cols: 2, rows: 2, inside: b))
    }

    func test_id_isStableForSameRegion() {
        let region = cells([[0,0],[1,0],[1,1]])
        XCTAssertEqual(puzzleID(cols: 2, rows: 2, inside: region),
                       puzzleID(cols: 2, rows: 2, inside: region))
    }

    func test_id_differsForDifferentRegion() {
        let a = cells([[0,0],[1,0]])
        let b = cells([[0,0],[0,1]])
        XCTAssertNotEqual(puzzleID(cols: 2, rows: 2, inside: a),
                          puzzleID(cols: 2, rows: 2, inside: b))
    }

    func test_id_is12HexChars() {
        let region = cells([[0,0]])
        let id = puzzleID(cols: 1, rows: 1, inside: region)
        XCTAssertEqual(id.count, 12)
        XCTAssertTrue(id.allSatisfy { $0.isHexDigit })
    }
}
