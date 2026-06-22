import Foundation

struct BundleJSON: Codable {
    let version: Int
    let tiers: [String: [PuzzleEntryJSON]]
}

struct PuzzleEntryJSON: Codable {
    let id: String
    let cols: Int
    let rows: Int
    let inside: [[Int]]
    let hideClues: [[Int]]
    let meta: MetaJSON
}

struct MetaJSON: Codable {
    let shownClueCount: Int
    let rulesFired: [String: Int]
    let seed: UInt64
}

/// Serializes a generated bundle. `.sortedKeys` + already-sorted cell arrays make
/// the output byte-identical for identical input (regenerate-and-diff drift guard).
func encodeBundle(_ bundle: [Tier: [GeneratedPuzzle]], seed: UInt64) throws -> Data {
    var tiers: [String: [PuzzleEntryJSON]] = [:]
    for (tier, puzzles) in bundle {
        tiers[tier.rawValue] = puzzles.map { gp in
            PuzzleEntryJSON(
                id: gp.id,
                cols: gp.cols,
                rows: gp.rows,
                inside: gp.inside.map { [$0.c, $0.r] },
                hideClues: gp.hideClues.map { [$0.c, $0.r] },
                meta: MetaJSON(
                    shownClueCount: gp.shownClueCount,
                    rulesFired: ["clue": gp.rulesFired[.clue] ?? 0,
                                 "dot": gp.rulesFired[.dot] ?? 0],
                    seed: seed
                )
            )
        }
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    return try encoder.encode(BundleJSON(version: 1, tiers: tiers))
}
