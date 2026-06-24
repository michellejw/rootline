import Foundation

public enum Tier: String, CaseIterable, Identifiable, Codable, Sendable {
    case sprout
    case mycelium
    case ancient
    case oldGrowth

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sprout:     return "Sprout"
        case .mycelium:   return "Mycelium"
        case .ancient:    return "Ancient"
        case .oldGrowth:  return "Old Growth"
        }
    }

    public var cols: Int {
        switch self {
        case .sprout:    return 4
        case .mycelium:  return 5
        case .ancient:   return 6
        case .oldGrowth: return 7
        }
    }

    public var rows: Int {
        switch self {
        case .sprout:    return 6
        case .mycelium:  return 7
        case .ancient:   return 9
        case .oldGrowth: return 10
        }
    }

    public var shortMeta: String { "\(cols)×\(rows)" }
}
