import Foundation

struct GeneratedPuzzle: Sendable {
    let cols: Int
    let rows: Int
    let inside: [Cell]      // sorted (row, col)
    let hideClues: [Cell]   // sorted (row, col)
    let id: String
    let shownClueCount: Int
    let rulesFired: [Rule: Int]
}

/// One pipeline pass: region → gate on fully-clued board → greedy hide → record.
/// Returns nil if the region has a hole or the full board isn't pure-logic unique.
func generateOne(tier: Tier, using rng: inout SplitMix64) -> GeneratedPuzzle? {
    let inside = RegionGenerator(cols: tier.cols, rows: tier.rows).generate(using: &rng)
    guard isSimplyConnected(inside, cols: tier.cols, rows: tier.rows) else { return nil }

    let puzzle = Puzzle(cols: tier.cols, rows: tier.rows, inside: inside.map { [$0.c, $0.r] })
    let model = PuzzleModel(puzzle)

    // Gate: a region whose fully-clued board needs guessing can never be pure-logic.
    let full = solve(PuzzleClues(cols: tier.cols, rows: tier.rows, clues: model.clues))
    guard full.verdict == .unique, full.trace.guesses == 0 else { return nil }

    let hidden = ClueHider(model: model).hide(using: &rng)

    var visible: [Cell: Int] = [:]
    for (cell, n) in model.clues where !hidden.contains(cell) { visible[cell] = n }
    let finalResult = solve(PuzzleClues(cols: tier.cols, rows: tier.rows, clues: visible))

    let sortedCells: (Set<Cell>) -> [Cell] = { $0.sorted { ($0.r, $0.c) < ($1.r, $1.c) } }
    return GeneratedPuzzle(
        cols: tier.cols,
        rows: tier.rows,
        inside: sortedCells(inside),
        hideClues: sortedCells(hidden),
        id: puzzleID(cols: tier.cols, rows: tier.rows, inside: inside),
        shownClueCount: model.clues.count - hidden.count,
        rulesFired: finalResult.trace.rulesFired
    )
}

/// Drives `generateOne` per tier until `countPerTier` unique puzzles are collected,
/// deduping by region. Caps attempts so an exhausted tier can't loop forever.
func generateBundle(
    tiers: [Tier],
    countPerTier: Int,
    seed: UInt64,
    progress: (String) -> Void
) -> [Tier: [GeneratedPuzzle]] {
    var rng = SplitMix64(seed: seed)
    var out: [Tier: [GeneratedPuzzle]] = [:]

    for tier in tiers {
        var results: [GeneratedPuzzle] = []
        var seenKeys: Set<String> = []
        var attempts = 0
        let maxAttempts = max(1000, countPerTier * 200)

        while results.count < countPerTier && attempts < maxAttempts {
            attempts += 1
            guard let gp = generateOne(tier: tier, using: &rng) else { continue }
            let key = canonicalKey(cols: gp.cols, rows: gp.rows, inside: Set(gp.inside))
            if seenKeys.contains(key) { continue }
            seenKeys.insert(key)
            results.append(gp)
            if results.count % 10 == 0 {
                progress("\(tier.label): \(results.count)/\(countPerTier)")
            }
        }
        if results.count < countPerTier {
            progress("\(tier.label): WARNING only \(results.count)/\(countPerTier) after \(attempts) attempts")
        } else {
            progress("\(tier.label): done \(results.count)/\(countPerTier) (\(attempts) attempts)")
        }
        out[tier] = results
    }
    return out
}

// MARK: - Public CLI entry

public struct GenerateOptions {
    public var tierNames: [String]?   // nil = all tiers
    public var count: Int
    public var seed: UInt64
    public init(tierNames: [String]?, count: Int, seed: UInt64) {
        self.tierNames = tierNames
        self.count = count
        self.seed = seed
    }
}

public enum GenerateError: Error, Equatable {
    case unknownTier(String)
}

/// Resolves tier names, runs the driver, and returns the encoded JSON bundle.
public func generateBundleData(
    _ options: GenerateOptions,
    progress: (String) -> Void = { _ in }
) throws -> Data {
    let tiers: [Tier]
    if let names = options.tierNames {
        tiers = try names.map { name in
            guard let t = Tier(rawValue: name) else { throw GenerateError.unknownTier(name) }
            return t
        }
    } else {
        tiers = Tier.allCases
    }
    let bundle = generateBundle(
        tiers: tiers,
        countPerTier: options.count,
        seed: options.seed,
        progress: progress
    )
    return try encodeBundle(bundle, seed: options.seed)
}
