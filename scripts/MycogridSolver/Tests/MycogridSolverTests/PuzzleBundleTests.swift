// scripts/MycogridSolver/Tests/MycogridSolverTests/PuzzleBundleTests.swift
import Testing
import Foundation
@testable import MycogridSolver

@Suite struct PuzzleBundleTests {
    // [c,r] pairs, matching the generator's emit order.
    static let json = """
    {
      "version": 1,
      "tiers": {
        "sprout": [
          { "id": "abc123",
            "cols": 4, "rows": 6,
            "inside": [[1,0],[2,0]],
            "hideClues": [[0,1]],
            "meta": { "shownClueCount": 18, "rulesFired": { "clue": 30, "dot": 12 }, "seed": 1 } }
        ],
        "mycelium": []
      }
    }
    """.data(using: .utf8)!

    @Test func decodesEntriesIntoDailyPuzzles() throws {
        let bundle = try PuzzleBundle(data: Self.json)
        #expect(bundle.version == 1)
        let sprout = bundle.puzzles(for: .sprout)
        #expect(sprout.count == 1)
        let p = sprout[0]
        #expect(p.id == "abc123")
        #expect(p.tier == .sprout)
        #expect(p.puzzle.cols == 4 && p.puzzle.rows == 6)
        #expect(p.puzzle.inside == Set([Cell(c: 1, r: 0), Cell(c: 2, r: 0)]))
        #expect(p.puzzle.hideClues == Set([Cell(c: 0, r: 1)]))
    }

    @Test func emptyTierAndAbsentTierReturnEmpty() throws {
        let bundle = try PuzzleBundle(data: Self.json)
        #expect(bundle.puzzles(for: .mycelium).isEmpty)
        #expect(bundle.puzzles(for: .oldGrowth).isEmpty)
    }

    @Test func unknownTierKeyThrows() {
        let bad = #"{ "version": 1, "tiers": { "bogus": [] } }"#.data(using: .utf8)!
        #expect(throws: PuzzleBundleError.unknownTier("bogus")) {
            try PuzzleBundle(data: bad)
        }
    }

    @Test func preservesArrayOrder() throws {
        let two = """
        { "version": 1, "tiers": { "sprout": [
          { "id": "first",  "cols": 4, "rows": 6, "inside": [[0,0]], "hideClues": [],
            "meta": { "shownClueCount": 1, "rulesFired": {"clue":1,"dot":0}, "seed": 1 } },
          { "id": "second", "cols": 4, "rows": 6, "inside": [[1,0]], "hideClues": [],
            "meta": { "shownClueCount": 1, "rulesFired": {"clue":1,"dot":0}, "seed": 1 } }
        ] } }
        """.data(using: .utf8)!
        let ids = try PuzzleBundle(data: two).puzzles(for: .sprout).map(\.id)
        #expect(ids == ["first", "second"])
    }
}
