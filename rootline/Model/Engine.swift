import Foundation

/// A Mycogrid puzzle definition: a `cols × rows` grid plus a simply-connected
/// region of "inside" cells. The solution loop and clues are derived from the region.
struct Puzzle: Hashable, Codable, Sendable {
    let cols: Int
    let rows: Int
    /// Cells that are inside the loop, as (col, row) pairs.
    let inside: Set<Cell>
    /// Cells whose clue digit should be hidden from the player.
    let hideClues: Set<Cell>
    /// Edges drawn before the player starts (used by tutorials).
    let presetActive: Set<Edge>

    init(cols: Int, rows: Int, inside: [[Int]], hide: [[Int]] = [], presetActive: [Edge] = []) {
        self.cols = cols
        self.rows = rows
        self.inside = Set(inside.compactMap { Cell.from(pair: $0) })
        self.hideClues = Set(hide.compactMap { Cell.from(pair: $0) })
        self.presetActive = Set(presetActive)
    }
}

public struct Cell: Hashable, Codable, Sendable {
    public let c: Int
    public let r: Int
    public init(c: Int, r: Int) { self.c = c; self.r = r }

    static func from(pair: [Int]) -> Cell? {
        guard pair.count == 2 else { return nil }
        return Cell(c: pair[0], r: pair[1])
    }
}

/// Static model derived from a Puzzle: the solution edges and the clue count per cell.
struct PuzzleModel: Sendable {
    let puzzle: Puzzle
    let solution: Set<Edge>
    let clues: [Cell: Int]

    init(_ puzzle: Puzzle) {
        self.puzzle = puzzle

        let cols = puzzle.cols
        let rows = puzzle.rows
        let inside = puzzle.inside

        func isIn(_ c: Int, _ r: Int) -> Bool {
            guard c >= 0, c < cols, r >= 0, r < rows else { return false }
            return inside.contains(Cell(c: c, r: r))
        }

        var sol = Set<Edge>()
        // Horizontal edges h-{r}-{c} separate cell (c, r-1) above and (c, r) below.
        for r in 0...rows {
            for c in 0..<cols {
                if isIn(c, r - 1) != isIn(c, r) {
                    sol.insert(.h(r: r, c: c))
                }
            }
        }
        // Vertical edges v-{r}-{c} separate cell (c-1, r) left and (c, r) right.
        for r in 0..<rows {
            for c in 0...cols {
                if isIn(c - 1, r) != isIn(c, r) {
                    sol.insert(.v(r: r, c: c))
                }
            }
        }
        self.solution = sol

        var c2: [Cell: Int] = [:]
        for r in 0..<rows {
            for c in 0..<cols {
                var n = 0
                for e in Edge.cellEdges(c: c, r: r) where sol.contains(e) {
                    n += 1
                }
                c2[Cell(c: c, r: r)] = n
            }
        }
        self.clues = c2
    }

    /// How many edges around cell `cell` are currently in `active`.
    func count(cell: Cell, in active: Set<Edge>) -> Int {
        var n = 0
        for e in Edge.cellEdges(c: cell.c, r: cell.r) where active.contains(e) {
            n += 1
        }
        return n
    }

    /// True when the active edges form a single closed loop (every touched dot
    /// has degree 2 and the edges form one connected component), regardless of
    /// whether the clues are satisfied. Used by the tutorial to detect the
    /// "drew a valid loop but the wrong one" case.
    func isClosedLoop(active: Set<Edge>) -> Bool {
        guard !active.isEmpty else { return false }
        var degree: [Dot: Int] = [:]
        var byDot: [Dot: [Edge]] = [:]
        for e in active {
            let (a, b) = e.endpoints
            degree[a, default: 0] += 1
            degree[b, default: 0] += 1
            byDot[a, default: []].append(e)
            byDot[b, default: []].append(e)
        }
        for (_, d) in degree where d != 2 { return false }
        guard let start = active.first else { return false }
        var seen: Set<Edge> = [start]
        var stack: [Edge] = [start]
        while let e = stack.popLast() {
            let (a, b) = e.endpoints
            for d in [a, b] {
                for ne in byDot[d] ?? [] where !seen.contains(ne) {
                    seen.insert(ne)
                    stack.append(ne)
                }
            }
        }
        return seen.count == active.count
    }

    /// Win: every shown clue is satisfied AND the active edges form one closed loop.
    func isSolved(active: Set<Edge>) -> Bool {
        // Shown clues all satisfied.
        for (cell, val) in clues {
            if puzzle.hideClues.contains(cell) { continue }
            if count(cell: cell, in: active) != val { return false }
        }
        guard !active.isEmpty else { return false }

        // Every dot the loop touches must have degree exactly 2.
        var degree: [Dot: Int] = [:]
        var byDot: [Dot: [Edge]] = [:]
        for e in active {
            let (a, b) = e.endpoints
            degree[a, default: 0] += 1
            degree[b, default: 0] += 1
            byDot[a, default: []].append(e)
            byDot[b, default: []].append(e)
        }
        for (_, d) in degree where d != 2 { return false }

        // Single connected component.
        guard let start = active.first else { return false }
        var seen: Set<Edge> = [start]
        var stack: [Edge] = [start]
        while let e = stack.popLast() {
            let (a, b) = e.endpoints
            for d in [a, b] {
                for ne in byDot[d] ?? [] where !seen.contains(ne) {
                    seen.insert(ne)
                    stack.append(ne)
                }
            }
        }
        return seen.count == active.count
    }
}
