// RegionTests.swift
import XCTest
@testable import MycogridSolver

final class RegionTests: XCTestCase {
    private func cells(_ pairs: [[Int]]) -> Set<Cell> {
        Set(pairs.map { Cell(c: $0[0], r: $0[1]) })
    }

    func test_solidRectangle_isSimplyConnected() {
        // 2x2 block inside a 3x3 grid.
        let region = cells([[0,0],[1,0],[0,1],[1,1]])
        XCTAssertTrue(isSimplyConnected(region, cols: 3, rows: 3))
    }

    func test_regionWithHole_isRejected() {
        // Ring of 8 cells around an empty center in a 3x3 grid — center (1,1) is a hole.
        let ring = cells([[0,0],[1,0],[2,0],[0,1],[2,1],[0,2],[1,2],[2,2]])
        XCTAssertFalse(isSimplyConnected(ring, cols: 3, rows: 3))
    }

    func test_disconnectedRegion_isRejected() {
        // Two separate cells in a 3x3 grid.
        let region = cells([[0,0],[2,2]])
        XCTAssertFalse(isSimplyConnected(region, cols: 3, rows: 3))
    }

    func test_emptyRegion_isRejected() {
        XCTAssertFalse(isSimplyConnected([], cols: 3, rows: 3))
    }

    func test_wholeGrid_isRejected() {
        let all = cells([[0,0],[1,0],[0,1],[1,1]])
        XCTAssertFalse(isSimplyConnected(all, cols: 2, rows: 2))
    }
}

extension RegionTests {
    func test_generate_isDeterministicForSameSeed() {
        var a = SplitMix64(seed: 99)
        var b = SplitMix64(seed: 99)
        let ra = RegionGenerator(cols: 4, rows: 6).generate(using: &a)
        let rb = RegionGenerator(cols: 4, rows: 6).generate(using: &b)
        XCTAssertEqual(ra, rb)
    }

    func test_generate_isNonTrivialAndConnected() {
        let gen = RegionGenerator(cols: 5, rows: 7)
        // Run a handful of seeds; every region is connected and within the fill band.
        for s in 0..<20 {
            var r = SplitMix64(seed: UInt64(s))
            let region = gen.generate(using: &r)
            XCTAssertFalse(region.isEmpty)
            XCTAssertLessThan(region.count, 5 * 7)
            // Connectivity holds even though holes may exist.
            XCTAssertTrue(regionIsConnected(region))
        }
    }

    // Local connectivity helper (does not check holes).
    private func regionIsConnected(_ inside: Set<Cell>) -> Bool {
        guard let first = inside.first else { return false }
        var seen: Set<Cell> = [first]
        var stack = [first]
        while let cur = stack.popLast() {
            for n in fourNeighbors(cur) where inside.contains(n) && !seen.contains(n) {
                seen.insert(n); stack.append(n)
            }
        }
        return seen.count == inside.count
    }
}
