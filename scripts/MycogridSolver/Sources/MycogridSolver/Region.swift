import Foundation

/// The four edge-adjacent neighbors of a cell (may be out of bounds; callers filter).
func fourNeighbors(_ cell: Cell) -> [Cell] {
    [
        Cell(c: cell.c - 1, r: cell.r),
        Cell(c: cell.c + 1, r: cell.r),
        Cell(c: cell.c, r: cell.r - 1),
        Cell(c: cell.c, r: cell.r + 1),
    ]
}

/// True iff `inside` is non-empty, smaller than the whole grid, edge-connected,
/// and hole-free. A hole would enclose "outside" cells the loop can't reach,
/// producing two loops instead of one.
func isSimplyConnected(_ inside: Set<Cell>, cols: Int, rows: Int) -> Bool {
    guard !inside.isEmpty, inside.count < cols * rows else { return false }

    // 1. Edge-connected: flood the region from any member.
    var seen: Set<Cell> = []
    var stack = [inside.first!]
    seen.insert(inside.first!)
    while let cur = stack.popLast() {
        for n in fourNeighbors(cur) where inside.contains(n) && !seen.contains(n) {
            seen.insert(n)
            stack.append(n)
        }
    }
    if seen.count != inside.count { return false }

    // 2. Hole-free: flood the "sea" from a padded corner just outside the grid.
    //    Every in-bounds non-inside cell must be reachable; any unreached one is a hole.
    func inPadded(_ c: Cell) -> Bool {
        c.c >= -1 && c.c <= cols && c.r >= -1 && c.r <= rows
    }
    var sea: Set<Cell> = [Cell(c: -1, r: -1)]
    var stack2 = [Cell(c: -1, r: -1)]
    while let cur = stack2.popLast() {
        for n in fourNeighbors(cur)
        where inPadded(n) && !inside.contains(n) && !sea.contains(n) {
            sea.insert(n)
            stack2.append(n)
        }
    }
    let reachedInBounds = sea.filter { $0.c >= 0 && $0.c < cols && $0.r >= 0 && $0.r < rows }.count
    return reachedInBounds == cols * rows - inside.count
}

/// Grows a random connected region by cell accretion. Result is connected and
/// sized within ~40–60% of the grid, but may contain a hole; callers validate
/// with `isSimplyConnected` and retry.
struct RegionGenerator {
    let cols: Int
    let rows: Int

    func generate(using rng: inout some RandomNumberGenerator) -> Set<Cell> {
        let total = cols * rows
        let frac = Double.random(in: 0.4...0.6, using: &rng)
        let target = max(1, min(total - 1, Int((Double(total) * frac).rounded())))

        let seed = Cell(c: Int.random(in: 0..<cols, using: &rng),
                        r: Int.random(in: 0..<rows, using: &rng))
        var inside: Set<Cell> = [seed]
        var frontier: Set<Cell> = Set(inBoundsNeighbors(seed))

        while inside.count < target && !frontier.isEmpty {
            // Sort frontier to an array before randomElement — Set order is not stable.
            let ordered = frontier.sorted { ($0.r, $0.c) < ($1.r, $1.c) }
            let pick = ordered.randomElement(using: &rng)!
            inside.insert(pick)
            frontier.remove(pick)
            for n in inBoundsNeighbors(pick) where !inside.contains(n) {
                frontier.insert(n)
            }
        }
        return inside
    }

    private func inBoundsNeighbors(_ cell: Cell) -> [Cell] {
        fourNeighbors(cell).filter { $0.c >= 0 && $0.c < cols && $0.r >= 0 && $0.r < rows }
    }
}
