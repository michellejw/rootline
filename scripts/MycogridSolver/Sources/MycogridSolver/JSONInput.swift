import Foundation

struct ClueJSON: Codable { let c: Int; let r: Int; let n: Int }
struct PuzzleJSON: Codable { let cols: Int; let rows: Int; let clues: [ClueJSON] }

public func loadClues(fromJSON data: Data) throws -> PuzzleClues {
    let p = try JSONDecoder().decode(PuzzleJSON.self, from: data)
    var dict: [Cell: Int] = [:]
    for cl in p.clues { dict[Cell(c: cl.c, r: cl.r)] = cl.n }
    return PuzzleClues(cols: p.cols, rows: p.rows, clues: dict)
}
