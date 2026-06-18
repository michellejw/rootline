import Foundation

struct ScoreEntry: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    let initials: String
    let tier: Tier
    let groveNumber: Int
    let seconds: Int
    let date: Date
}

@MainActor
@Observable
final class ScoreStore {
    private static let key = "rootline_scores_v1"
    private static let maxPerTier = 5

    private(set) var scores: [Tier: [ScoreEntry]] = Tier.allCases.reduce(into: [:]) { $0[$1] = [] }

    init() {
        load()
    }

    func best(for tier: Tier) -> [ScoreEntry] {
        scores[tier] ?? []
    }

    /// True if the given time would land in the top N for that tier.
    func qualifies(seconds: Int, for tier: Tier) -> Bool {
        let list = best(for: tier)
        if list.count < Self.maxPerTier { return true }
        guard let slowest = list.last else { return true }
        return seconds < slowest.seconds
    }

    /// True if the given time is better than the current best for the tier.
    func isNewRecord(seconds: Int, for tier: Tier) -> Bool {
        guard let fastest = best(for: tier).first else { return true }
        return seconds < fastest.seconds
    }

    @discardableResult
    func save(initials: String, seconds: Int, tier: Tier, groveNumber: Int) -> ScoreEntry {
        let cleaned = Self.sanitize(initials)
        let entry = ScoreEntry(
            initials: cleaned,
            tier: tier,
            groveNumber: groveNumber,
            seconds: seconds,
            date: Date()
        )
        var list = best(for: tier)
        list.append(entry)
        list.sort { $0.seconds < $1.seconds }
        if list.count > Self.maxPerTier {
            list = Array(list.prefix(Self.maxPerTier))
        }
        scores[tier] = list
        persist()
        return entry
    }

    func clearAll() {
        for tier in Tier.allCases { scores[tier] = [] }
        persist()
    }

    static func sanitize(_ raw: String) -> String {
        let upper = raw.uppercased().unicodeScalars.filter { CharacterSet.uppercaseLetters.contains($0) }
        let str = String(String.UnicodeScalarView(upper))
        if str.isEmpty { return "YOU" }
        return String(str.prefix(3))
    }

    // MARK: - Persistence

    private struct Stored: Codable {
        var sprout: [ScoreEntry] = []
        var mycelium: [ScoreEntry] = []
        var ancient: [ScoreEntry] = []
        var oldGrowth: [ScoreEntry] = []
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        scores[.sprout]    = stored.sprout
        scores[.mycelium]  = stored.mycelium
        scores[.ancient]   = stored.ancient
        scores[.oldGrowth] = stored.oldGrowth
    }

    private func persist() {
        let stored = Stored(
            sprout:    scores[.sprout]    ?? [],
            mycelium:  scores[.mycelium]  ?? [],
            ancient:   scores[.ancient]   ?? [],
            oldGrowth: scores[.oldGrowth] ?? []
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
