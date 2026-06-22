import XCTest
@testable import MycogridSolver

final class RNGTests: XCTestCase {
    func test_sameSeed_producesSameSequence() {
        var a = SplitMix64(seed: 42)
        var b = SplitMix64(seed: 42)
        let seqA = (0..<5).map { _ in a.next() }
        let seqB = (0..<5).map { _ in b.next() }
        XCTAssertEqual(seqA, seqB)
    }

    func test_differentSeed_producesDifferentSequence() {
        var a = SplitMix64(seed: 1)
        var b = SplitMix64(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func test_drivesStdlibRandomDeterministically() {
        var a = SplitMix64(seed: 7)
        var b = SplitMix64(seed: 7)
        let xa = Int.random(in: 0..<1000, using: &a)
        let xb = Int.random(in: 0..<1000, using: &b)
        XCTAssertEqual(xa, xb)
    }
}
