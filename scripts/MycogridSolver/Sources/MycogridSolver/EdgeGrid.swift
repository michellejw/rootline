struct EdgeGrid {
    let cols: Int
    let rows: Int
    let edges: [Edge]
    private let indexOf: [Edge: Int]
    /// One entry per clued cell: the required count and the indices of its 4 edges.
    let cellConstraints: [(clue: Int, edges: [Int])]
    /// One entry per dot (row-major over `(0...rows) x (0...cols)`): incident edge indices.
    let dotConstraints: [[Int]]

    var edgeCount: Int { edges.count }

    init(_ clues: PuzzleClues) {
        var edges: [Edge] = []
        var indexOf: [Edge: Int] = [:]
        func add(_ e: Edge) { indexOf[e] = edges.count; edges.append(e) }
        for r in 0...clues.rows { for c in 0..<clues.cols { add(.h(r: r, c: c)) } }
        for r in 0..<clues.rows { for c in 0...clues.cols { add(.v(r: r, c: c)) } }
        self.cols = clues.cols
        self.rows = clues.rows
        self.edges = edges
        self.indexOf = indexOf

        var cellCon: [(clue: Int, edges: [Int])] = []
        for (cell, n) in clues.clues {
            let es = Edge.cellEdges(c: cell.c, r: cell.r).map { indexOf[$0]! }
            cellCon.append((clue: n, edges: es))
        }
        self.cellConstraints = cellCon

        var dotCon: [[Int]] = []
        for r in 0...clues.rows {
            for c in 0...clues.cols {
                var inc: [Int] = []
                if c - 1 >= 0 { inc.append(indexOf[.h(r: r, c: c - 1)]!) }
                if c < clues.cols { inc.append(indexOf[.h(r: r, c: c)]!) }
                if r - 1 >= 0 { inc.append(indexOf[.v(r: r - 1, c: c)]!) }
                if r < clues.rows { inc.append(indexOf[.v(r: r, c: c)]!) }
                dotCon.append(inc)
            }
        }
        self.dotConstraints = dotCon
    }

    func endpoints(of e: Edge) -> (Dot, Dot) {
        switch e {
        case let .h(r, c): return (Dot(c: c, r: r), Dot(c: c + 1, r: r))
        case let .v(r, c): return (Dot(c: c, r: r), Dot(c: c, r: r + 1))
        }
    }
}
