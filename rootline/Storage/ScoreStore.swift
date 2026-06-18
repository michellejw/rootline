import Foundation

/// Quiet per-tier stats: the player's fastest clear and how many they've cleared.
struct TierStat: Codable, Equatable, Sendable {
    var bestSeconds: Int? = nil
    var clearedCount: Int = 0
}

/// Result of recording a cleared puzzle, used to decide the win-card whisper.
enum ClearOutcome: Equatable, Sendable {
    case firstClear      // first clear of this tier; no prior best existed
    case newBest         // beat the previous best time
    case noImprovement   // cleared, but not faster than the existing best
}

@MainActor
@Observable
final class ScoreStore {
    private static let key = "rootline_stats_v1"
    private let defaults: UserDefaults

    private(set) var stats: [Tier: TierStat] = Tier.allCases.reduce(into: [:]) { $0[$1] = TierStat() }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func stat(for tier: Tier) -> TierStat {
        stats[tier] ?? TierStat()
    }

    func bestSeconds(for tier: Tier) -> Int? {
        stat(for: tier).bestSeconds
    }

    func clearedCount(for tier: Tier) -> Int {
        stat(for: tier).clearedCount
    }

    /// True when the player has cleared at least one puzzle in any tier.
    var hasAnyStats: Bool {
        stats.values.contains { $0.clearedCount > 0 }
    }

    /// Total puzzles cleared across every tier.
    var totalCleared: Int {
        stats.values.reduce(0) { $0 + $1.clearedCount }
    }

    /// Record a cleared puzzle: bump the completion count, lower the best time
    /// if this was faster, and report what happened so callers can decide
    /// whether to whisper "your fastest yet".
    @discardableResult
    func record(seconds: Int, for tier: Tier) -> ClearOutcome {
        var s = stat(for: tier)
        s.clearedCount += 1
        let outcome: ClearOutcome
        if let best = s.bestSeconds {
            if seconds < best {
                s.bestSeconds = seconds
                outcome = .newBest
            } else {
                outcome = .noImprovement
            }
        } else {
            s.bestSeconds = seconds
            outcome = .firstClear
        }
        stats[tier] = s
        persist()
        return outcome
    }

    func clearAll() {
        for tier in Tier.allCases { stats[tier] = TierStat() }
        persist()
    }

    // MARK: - Persistence

    private struct Stored: Codable {
        var sprout: TierStat = TierStat()
        var mycelium: TierStat = TierStat()
        var ancient: TierStat = TierStat()
        var oldGrowth: TierStat = TierStat()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        stats[.sprout]    = stored.sprout
        stats[.mycelium]  = stored.mycelium
        stats[.ancient]   = stored.ancient
        stats[.oldGrowth] = stored.oldGrowth
    }

    private func persist() {
        let stored = Stored(
            sprout:    stat(for: .sprout),
            mycelium:  stat(for: .mycelium),
            ancient:   stat(for: .ancient),
            oldGrowth: stat(for: .oldGrowth)
        )
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
