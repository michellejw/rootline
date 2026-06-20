import Foundation

/// An edge between two adjacent dots on the lattice.
/// `h(r, c)` connects dot (c, r) → (c+1, r).
/// `v(r, c)` connects dot (c, r) → (c, r+1).
public enum Edge: Hashable, Codable, Sendable {
    case h(r: Int, c: Int)
    case v(r: Int, c: Int)

    var endpoints: (Dot, Dot) {
        switch self {
        case .h(let r, let c): return (Dot(c: c, r: r), Dot(c: c + 1, r: r))
        case .v(let r, let c): return (Dot(c: c, r: r), Dot(c: c, r: r + 1))
        }
    }
}

public struct Dot: Hashable, Codable, Sendable {
    public let c: Int
    public let r: Int
    public init(c: Int, r: Int) { self.c = c; self.r = r }
}

extension Edge {
    /// Edges around a cell (c, r): top, bottom, left, right.
    static func cellEdges(c: Int, r: Int) -> [Edge] {
        [
            .h(r: r,     c: c),     // top
            .h(r: r + 1, c: c),     // bottom
            .v(r: r,     c: c),     // left
            .v(r: r,     c: c + 1)  // right
        ]
    }
}
