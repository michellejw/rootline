import Foundation

/// Order-independent string identity for a region. Cells sorted (row, col).
func canonicalKey(cols: Int, rows: Int, inside: Set<Cell>) -> String {
    let sorted = inside.sorted { ($0.r, $0.c) < ($1.r, $1.c) }
    return "\(cols)x\(rows):" + sorted.map { "\($0.c),\($0.r)" }.joined(separator: ";")
}

/// FNV-1a 64-bit. Stable across processes (unlike the stdlib `Hasher`).
func fnv1a64(_ s: String) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in s.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01b3
    }
    return hash
}

/// 12-char hex id derived from the canonical region key.
func puzzleID(cols: Int, rows: Int, inside: Set<Cell>) -> String {
    let h = fnv1a64(canonicalKey(cols: cols, rows: rows, inside: inside))
    return String(String(format: "%016llx", h).prefix(12))
}
