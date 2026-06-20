import XCTest
@testable import MycogridSolver

final class PoolTests: XCTestCase {
    func test_pool_isNonEmpty_andEveryPuzzleIsUniqueAndMatchesStored() {
        let reports = auditPool()
        XCTAssertFalse(reports.isEmpty, "auditPool returned no puzzles")
        let failures = reports.filter { !$0.passed }
        XCTAssertTrue(failures.isEmpty, "puzzles failed validation: " +
            failures.map {
                "\($0.label)[\($0.verdict.rawValue) match=\($0.matchesStored) oracle=\($0.oracleOK)]"
            }.joined(separator: ", "))
    }
}
