import Foundation

/// A snapshot of a play session that's small enough to fit comfortably in
/// UserDefaults. Restored on app launch so the player can resume after
/// backgrounding, killing the app, or rebooting the phone.
struct PuzzleProgress: Codable, Sendable {
    let puzzleID: String
    let playedDate: Date
    let tier: Tier
    let activeEdges: [Edge]
    let xEdges: [Edge]
    let mode: DrawMode
    let elapsedSeconds: Int
    let hintsUsed: Int
}

@MainActor
final class ProgressStore {
    private static let key = "rootline_in_progress_v2"

    func load() -> PuzzleProgress? {
        guard let data = UserDefaults.standard.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(PuzzleProgress.self, from: data)
    }

    func save(_ progress: PuzzleProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
