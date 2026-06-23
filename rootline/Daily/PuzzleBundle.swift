import Foundation

/// One playable puzzle from the generated bundle, carrying its stable id and tier.
struct DailyPuzzle: Hashable, Sendable {
    let id: String
    let tier: Tier
    let puzzle: Puzzle
}

/// Codable mirror of the generator's `puzzles.json`. `inside`/`hideClues` arrive
/// as `[[c, r]]` pairs (not `[{c,r}]`); the bridge below maps them into `Puzzle`.
/// The generator's `meta` block is provenance-only and intentionally ignored
/// here (unknown JSON keys are dropped by the decoder).
private struct PuzzleBundleJSON: Decodable {
    let version: Int
    let tiers: [String: [Entry]]
    struct Entry: Decodable {
        let id: String
        let cols: Int
        let rows: Int
        let inside: [[Int]]
        let hideClues: [[Int]]
    }
}

enum PuzzleBundleError: Error, Equatable { case unknownTier(String) }

/// The loaded bundle: per-tier ordered arrays of playable puzzles. Array order is
/// the committed, append-only order the date→puzzle mapping depends on.
struct PuzzleBundle: Sendable {
    let version: Int
    private let byTier: [Tier: [DailyPuzzle]]

    init(byTier: [Tier: [DailyPuzzle]], version: Int = 1) {
        self.byTier = byTier
        self.version = version
    }

    func puzzles(for tier: Tier) -> [DailyPuzzle] { byTier[tier] ?? [] }

    /// Decode from the generator's JSON. Throws `PuzzleBundleError.unknownTier`
    /// for an unrecognized tier key, or a `DecodingError` for malformed JSON.
    init(data: Data) throws {
        let json = try JSONDecoder().decode(PuzzleBundleJSON.self, from: data)
        var out: [Tier: [DailyPuzzle]] = [:]
        for (key, entries) in json.tiers {
            guard let tier = Tier(rawValue: key) else {
                throw PuzzleBundleError.unknownTier(key)
            }
            out[tier] = entries.map { e in
                DailyPuzzle(
                    id: e.id,
                    tier: tier,
                    puzzle: Puzzle(cols: e.cols, rows: e.rows, inside: e.inside, hide: e.hideClues)
                )
            }
        }
        self.init(byTier: out, version: json.version)
    }
}
