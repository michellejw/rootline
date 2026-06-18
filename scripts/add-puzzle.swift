#!/usr/bin/env swift
//
//  add-puzzle.swift
//
//  Reads a `Puzzle(cols:, rows:, inside:, hide:)` declaration from the macOS
//  clipboard (the same text the in-app editor produces via Copy Swift) and
//  inserts it into the appropriate tier array in `rootline/Model/PuzzleData.swift`.
//
//  Refuses to insert if an existing puzzle in that tier has the same
//  cols/rows/inside footprint, normalized.
//
//  Usage (run from the rootline repo root):
//      swift scripts/add-puzzle.swift <tier>
//
//  Where <tier> is one of: sprout | mycelium | ancient | oldGrowth
//

import Foundation

// MARK: - CLI

/// Canonical grid dimensions per tier. Must match `Tier.cols` / `Tier.rows`
/// in `Model/Tier.swift`.
let tierDims: [(name: String, cols: Int, rows: Int)] = [
    ("sprout",    4, 6),
    ("mycelium",  5, 7),
    ("ancient",   6, 9),
    ("oldGrowth", 7, 10)
]
let validTiers = tierDims.map(\.name)

func die(_ message: String) -> Never {
    FileHandle.standardError.write(("error: " + message + "\n").data(using: .utf8)!)
    exit(1)
}

guard CommandLine.arguments.count >= 2 else {
    die("usage: swift scripts/add-puzzle.swift <\(validTiers.joined(separator: "|"))>")
}
let tier = CommandLine.arguments[1]
guard validTiers.contains(tier) else {
    die("unknown tier '\(tier)' — use one of: \(validTiers.joined(separator: ", "))")
}

// MARK: - Clipboard

func readClipboard() -> String {
    let task = Process()
    task.launchPath = "/usr/bin/pbpaste"
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

let clip = readClipboard().trimmingCharacters(in: .whitespacesAndNewlines)
guard clip.hasPrefix("Puzzle(") else {
    die("clipboard doesn't start with `Puzzle(`. Did you tap Copy Swift in the editor?")
}

// MARK: - Parse a Puzzle(...) source into its key signature

struct PuzzleShape {
    let cols: Int
    let rows: Int
    let inside: [(c: Int, r: Int)]  // sorted by (r, c) for normalized comparison
}

func parsePuzzleSource(_ source: String) -> PuzzleShape? {
    func intCapture(_ pattern: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(source.startIndex..., in: source)
        guard let match = re.firstMatch(in: source, range: range),
              let r = Range(match.range(at: 1), in: source) else { return nil }
        return Int(source[r])
    }
    guard let cols = intCapture("cols:\\s*(\\d+)"),
          let rows = intCapture("rows:\\s*(\\d+)") else { return nil }

    // Locate `inside:` then capture the balanced [...] that follows.
    guard let insideKeyword = source.range(of: "inside:") else { return nil }
    var idx = insideKeyword.upperBound
    while idx < source.endIndex, source[idx] != "[" {
        idx = source.index(after: idx)
    }
    guard idx < source.endIndex else { return nil }
    let listStart = idx
    var depth = 0
    while idx < source.endIndex {
        let ch = source[idx]
        if ch == "[" { depth += 1 }
        else if ch == "]" {
            depth -= 1
            if depth == 0 { break }
        }
        idx = source.index(after: idx)
    }
    guard idx < source.endIndex else { return nil }
    let insideSlice = source[listStart...idx]

    let pairRe = try! NSRegularExpression(pattern: "\\[\\s*(\\d+)\\s*,\\s*(\\d+)\\s*\\]")
    let pairs = pairRe.matches(
        in: String(insideSlice),
        range: NSRange(insideSlice.startIndex..., in: insideSlice)
    )
    var cells: [(c: Int, r: Int)] = []
    let insideStr = String(insideSlice)
    for m in pairs {
        guard let cR = Range(m.range(at: 1), in: insideStr),
              let rR = Range(m.range(at: 2), in: insideStr) else { continue }
        cells.append((c: Int(insideStr[cR])!, r: Int(insideStr[rR])!))
    }
    cells.sort { ($0.r, $0.c) < ($1.r, $1.c) }
    return PuzzleShape(cols: cols, rows: rows, inside: cells)
}

guard let newShape = parsePuzzleSource(clip) else {
    die("couldn't parse cols/rows/inside out of the clipboard.")
}

// MARK: - Validate the puzzle matches the chosen tier's dimensions

guard let tierDef = tierDims.first(where: { $0.name == tier }) else {
    die("internal: unknown tier '\(tier)'.")  // already guarded above
}
guard newShape.cols == tierDef.cols, newShape.rows == tierDef.rows else {
    // Suggest the correct tier if the dims match a different one.
    if let actualTier = tierDims.first(where: { $0.cols == newShape.cols && $0.rows == newShape.rows }) {
        die("puzzle is \(newShape.cols)×\(newShape.rows) but the \(tier) tier expects \(tierDef.cols)×\(tierDef.rows). Did you mean: swift scripts/add-puzzle.swift \(actualTier.name) ?")
    } else {
        die("puzzle is \(newShape.cols)×\(newShape.rows) — that doesn't match any shipped tier (sprout 4×6, mycelium 5×7, ancient 6×9, oldGrowth 7×10).")
    }
}

// MARK: - Validate the shape is simply connected

/// True when every outside cell can reach the off-grid void without crossing
/// an inside cell. False if any outside cell is enclosed by inside cells —
/// that hole would create a second loop and break the puzzle.
func isSimplyConnected(_ shape: PuzzleShape) -> Bool {
    let cols = shape.cols, rows = shape.rows
    let insideSet = Set(shape.inside.map { "\($0.c),\($0.r)" })
    var outsideCount = 0
    for r in 0..<rows {
        for c in 0..<cols where !insideSet.contains("\(c),\(r)") {
            outsideCount += 1
        }
    }
    if outsideCount == 0 { return true }   // every cell inside

    var visited = Set<String>()
    var stack: [(Int, Int)] = []
    for r in 0..<rows {
        for c in 0..<cols {
            let key = "\(c),\(r)"
            guard !insideSet.contains(key) else { continue }
            if c == 0 || r == 0 || c == cols - 1 || r == rows - 1 {
                if visited.insert(key).inserted {
                    stack.append((c, r))
                }
            }
        }
    }
    while let (c, r) = stack.popLast() {
        for (dc, dr) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            let nc = c + dc, nr = r + dr
            guard nc >= 0, nc < cols, nr >= 0, nr < rows else { continue }
            let key = "\(nc),\(nr)"
            guard !insideSet.contains(key), !visited.contains(key) else { continue }
            visited.insert(key)
            stack.append((nc, nr))
        }
    }
    return visited.count == outsideCount
}

guard !newShape.inside.isEmpty else {
    die("the puzzle has no inside cells — nothing to make a loop out of.")
}
guard isSimplyConnected(newShape) else {
    die("shape is not simply connected — at least one outside cell is enclosed by inside cells, which would create a second loop.")
}

// MARK: - Load PuzzleData.swift, find the tier array

let filePath = "rootline/Model/PuzzleData.swift"
guard let fileData = FileManager.default.contents(atPath: filePath),
      let fileSource = String(data: fileData, encoding: .utf8) else {
    die("couldn't read \(filePath). Run from the rootline repo root.")
}

guard let tierAnchor = fileSource.range(of: "static let \(tier): [Puzzle] = [") else {
    die("couldn't find `static let \(tier): [Puzzle] = [` in \(filePath).")
}

// Walk forward to find the matching `]` at the array level.
var idx = tierAnchor.upperBound
var bracketDepth = 1  // already past the opening `[`
var arrayClose: String.Index? = nil
while idx < fileSource.endIndex {
    let ch = fileSource[idx]
    if ch == "[" { bracketDepth += 1 }
    else if ch == "]" {
        bracketDepth -= 1
        if bracketDepth == 0 { arrayClose = idx; break }
    }
    idx = fileSource.index(after: idx)
}
guard let arrayCloseIdx = arrayClose else {
    die("couldn't find the closing `]` for the \(tier) array.")
}

let tierBody = String(fileSource[tierAnchor.upperBound..<arrayCloseIdx])

// MARK: - Pull each existing Puzzle(...) and check for a duplicate

var existing: [PuzzleShape] = []
var cursor = tierBody.startIndex
while let pStart = tierBody.range(of: "Puzzle(", range: cursor..<tierBody.endIndex) {
    var pIdx = pStart.upperBound
    var parenDepth = 1
    while pIdx < tierBody.endIndex {
        let ch = tierBody[pIdx]
        if ch == "(" { parenDepth += 1 }
        else if ch == ")" {
            parenDepth -= 1
            if parenDepth == 0 { break }
        }
        pIdx = tierBody.index(after: pIdx)
    }
    if pIdx < tierBody.endIndex {
        let pSlice = String(tierBody[pStart.lowerBound...pIdx])
        if let parsed = parsePuzzleSource(pSlice) {
            existing.append(parsed)
        }
    }
    cursor = tierBody.index(after: pStart.lowerBound)
}

func sameShape(_ a: PuzzleShape, _ b: PuzzleShape) -> Bool {
    guard a.cols == b.cols, a.rows == b.rows, a.inside.count == b.inside.count else { return false }
    return zip(a.inside, b.inside).allSatisfy { $0.c == $1.c && $0.r == $1.r }
}

for ex in existing {
    if sameShape(ex, newShape) {
        die("this puzzle is already in the \(tier) tier (matches Grove #\(existing.firstIndex { sameShape($0, newShape) }! + 1)).")
    }
}

// MARK: - Build the insertion block

let groveNum = existing.count + 1
// Indent every line by 8 spaces so it nests under the tier array opening.
let indented = clip.split(separator: "\n", omittingEmptySubsequences: false)
    .map { "        \($0)" }
    .joined(separator: "\n")

// MARK: - Splice into the file

// Insert AFTER the closing `)` of the last existing puzzle so we can also
// add the missing trailing comma. If the tier is empty (no `)` between the
// array's `[` and `]`), insert at the start of the array.
var insertPoint: String.Index
var prefix: String

if let lastClose = fileSource.range(of: ")", options: .backwards,
                                    range: tierAnchor.upperBound..<arrayCloseIdx) {
    insertPoint = lastClose.upperBound
    // Existing puzzle has no trailing comma — add one.
    prefix = ",\n"
} else {
    insertPoint = tierAnchor.upperBound
    prefix = "\n"
}

let insertion = """
\(prefix)        // Grove #\(groveNum)
\(indented)
"""

var output = fileSource
output.replaceSubrange(insertPoint..<insertPoint, with: insertion)

guard let outData = output.data(using: .utf8) else {
    die("failed to encode updated file.")
}
do {
    try outData.write(to: URL(fileURLWithPath: filePath), options: .atomic)
} catch {
    die("failed to write \(filePath): \(error.localizedDescription)")
}

print("Added Grove #\(groveNum) to \(tier) (\(newShape.cols)×\(newShape.rows), \(newShape.inside.count) inside cells).")
