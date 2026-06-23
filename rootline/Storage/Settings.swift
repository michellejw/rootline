import Foundation
import SwiftUI
import ShroomKit

enum LookVariant: String, CaseIterable, Codable, Sendable {
    case glow
    case ink

    var label: String {
        switch self {
        case .glow: return "Glow"
        case .ink:  return "Ink"
        }
    }
}

@MainActor
@Observable
final class Settings {
    private enum Keys {
        static let look = "rootline_look_variant_v1"
        static let showTimer = "rootline_show_timer_v1"
        static let tier = "rootline_tier_v1"
        static let tutorialSeen = "rootline_tutorial_seen_v1"
        static let themeMode = "rootline_theme_mode_v1"
        static let archiveFloor = "rootline_archive_floor_v1"
    }

    var look: LookVariant {
        didSet { UserDefaults.standard.set(look.rawValue, forKey: Keys.look) }
    }

    var showTimer: Bool {
        didSet { UserDefaults.standard.set(showTimer, forKey: Keys.showTimer) }
    }

    var tier: Tier {
        didSet { UserDefaults.standard.set(tier.rawValue, forKey: Keys.tier) }
    }

    var hasSeenTutorial: Bool {
        didSet { UserDefaults.standard.set(hasSeenTutorial, forKey: Keys.tutorialSeen) }
    }

    var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: Keys.themeMode) }
    }

    init() {
        let d = UserDefaults.standard
        self.look = LookVariant(rawValue: d.string(forKey: Keys.look) ?? "") ?? .glow
        // Default: hidden per plan ("Timer: optional, hidden by default").
        self.showTimer = d.object(forKey: Keys.showTimer) as? Bool ?? false
        self.tier = Tier(rawValue: d.string(forKey: Keys.tier) ?? "") ?? .default
        self.hasSeenTutorial = d.bool(forKey: Keys.tutorialSeen)
        self.themeMode = ThemeMode(rawValue: d.string(forKey: Keys.themeMode) ?? "") ?? .system
    }

    /// The archive's back-scroll floor: fixed once at first access to
    /// (firstOpen − 14 days), then never moved forward.
    var archiveFloor: Date {
        if let t = UserDefaults.standard.object(forKey: Keys.archiveFloor) as? Double {
            return Date(timeIntervalSince1970: t)
        }
        let floor = DailyService.archiveFloor(firstOpen: Date())
        UserDefaults.standard.set(floor.timeIntervalSince1970, forKey: Keys.archiveFloor)
        return floor
    }

    /// Cycle System → Light → Dark → System. Used by the in-game quick-toggle.
    func cycleThemeMode() {
        // Quick toggle: a 2-state light/dark flip. "System" is chosen in Settings.
        themeMode = (themeMode == .twilight) ? .forest : .twilight
    }
}
