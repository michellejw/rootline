import XCTest
@testable import MycogridSolver

final class GeneratorTests: XCTestCase {
    // Re-solve a generated puzzle from only its visible clues and assert the
    // core invariant: unique, pure-logic, and matching the derived solution.
    private func assertCoreInvariant(_ gp: GeneratedPuzzle) {
        let puzzle = Puzzle(
            cols: gp.cols, rows: gp.rows,
            inside: gp.inside.map { [$0.c, $0.r] },
            hide: gp.hideClues.map { [$0.c, $0.r] }
        )
        let model = PuzzleModel(puzzle)
        var visible: [Cell: Int] = [:]
        for (cell, n) in model.clues where !Set(gp.hideClues).contains(cell) { visible[cell] = n }
        let result = solve(PuzzleClues(cols: gp.cols, rows: gp.rows, clues: visible))
        XCTAssertEqual(result.verdict, .unique)
        XCTAssertEqual(result.trace.guesses, 0)
        XCTAssertEqual(result.solution, model.solution)
    }

    func test_generateBundle_everyPuzzleSatisfiesCoreInvariant() {
        let bundle = generateBundle(tiers: [.sprout], countPerTier: 3, seed: 1, progress: { _ in })
        let puzzles = bundle[.sprout] ?? []
        XCTAssertEqual(puzzles.count, 3)
        for gp in puzzles { assertCoreInvariant(gp) }
    }

    func test_generateBundle_dedupsByRegion() {
        let bundle = generateBundle(tiers: [.sprout], countPerTier: 5, seed: 2, progress: { _ in })
        let puzzles = bundle[.sprout] ?? []
        let keys = puzzles.map { canonicalKey(cols: $0.cols, rows: $0.rows, inside: Set($0.inside)) }
        XCTAssertEqual(Set(keys).count, keys.count, "duplicate regions in bundle")
    }

    func test_generateBundle_isDeterministic() {
        let a = generateBundle(tiers: [.sprout], countPerTier: 3, seed: 7, progress: { _ in })
        let b = generateBundle(tiers: [.sprout], countPerTier: 3, seed: 7, progress: { _ in })
        let ka = (a[.sprout] ?? []).map { $0.id }
        let kb = (b[.sprout] ?? []).map { $0.id }
        XCTAssertEqual(ka, kb)
    }
}
