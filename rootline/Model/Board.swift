import Foundation
import SwiftUI

enum DrawMode: String, Codable, Sendable {
    case draw
    case mark
}

/// Runtime state for a single puzzle session.
@MainActor
@Observable
final class Board {
    let model: PuzzleModel
    let tier: Tier?
    let allowHints: Bool

    var activeEdges: Set<Edge>
    var xEdges: Set<Edge>
    var mode: DrawMode = .draw
    var elapsedSeconds: Int = 0
    var hintsUsed: Int = 0

    var isSolved: Bool = false
    /// True after the player has tapped "Show solution". Stats are not
    /// recorded for revealed boards.
    var revealed: Bool = false
    var solveTick: Int = 0
    var tapTick: Int = 0

    init(puzzle: Puzzle, tier: Tier?, allowHints: Bool = true) {
        self.model = PuzzleModel(puzzle)
        self.tier = tier
        self.allowHints = allowHints
        self.activeEdges = puzzle.presetActive
        self.xEdges = []
    }

    /// Build a board from a saved snapshot by re-deriving the puzzle from its
    /// played date via `DailyService`. Returns nil if the id no longer matches
    /// what the date maps to (bundle/regen drift).
    convenience init?(restoring progress: PuzzleProgress, using daily: DailyService) {
        guard let dp = daily.puzzle(for: progress.playedDate), dp.id == progress.puzzleID else { return nil }
        self.init(puzzle: dp.puzzle, tier: dp.tier, allowHints: true)
        self.activeEdges = Set(progress.activeEdges)
        self.xEdges = Set(progress.xEdges)
        self.mode = progress.mode
        self.elapsedSeconds = progress.elapsedSeconds
        self.hintsUsed = progress.hintsUsed
        if model.isSolved(active: activeEdges) {
            isSolved = true
        }
    }

    /// A serializable snapshot of the current play session, or `nil` if this is
    /// a tutorial board (no tier).
    func snapshot(puzzleID: String, playedDate: Date) -> PuzzleProgress? {
        guard let tier else { return nil }
        return PuzzleProgress(
            puzzleID: puzzleID,
            playedDate: playedDate,
            tier: tier,
            activeEdges: Array(activeEdges),
            xEdges: Array(xEdges),
            mode: mode,
            elapsedSeconds: elapsedSeconds,
            hintsUsed: hintsUsed
        )
    }

    var puzzle: Puzzle { model.puzzle }

    /// True when the player has done anything beyond the puzzle's preset state.
    /// Used to decide whether leaving the puzzle warrants a confirmation.
    var hasPlayerMoves: Bool {
        activeEdges != puzzle.presetActive || !xEdges.isEmpty || hintsUsed > 0
    }

    func tick() {
        guard !isSolved else { return }
        elapsedSeconds += 1
    }

    func toggle(_ edge: Edge) {
        guard !isSolved, !revealed else { return }
        tapTick &+= 1
        switch mode {
        case .draw:
            if activeEdges.contains(edge) {
                activeEdges.remove(edge)
            } else {
                activeEdges.insert(edge)
                xEdges.remove(edge)
            }
        case .mark:
            if xEdges.contains(edge) {
                xEdges.remove(edge)
            } else {
                xEdges.insert(edge)
                activeEdges.remove(edge)
            }
        }
        if model.isSolved(active: activeEdges) {
            isSolved = true
            solveTick &+= 1
        }
    }

    // MARK: Hints

    /// One tap = one move: place a correct edge or remove a wrongly-placed one.
    /// Unlimited — `hintsUsed` is tracked for the player's awareness, not gated.
    func nextHint() {
        guard allowHints, !isSolved, !revealed else { return }
        placeOneMissingEdge()
        hintsUsed += 1
    }

    /// Boot the board as a previously-cleared puzzle: solution drawn, win
    /// card visible, timer frozen at the player's saved best. `solveTick`
    /// stays at 0 so no re-record fires.
    func openAsCleared(bestSeconds: Int) {
        activeEdges = model.solution
        xEdges = []
        isSolved = true
        elapsedSeconds = bestSeconds
    }

    /// Reveal the full solution view-only: fills in every correct edge but
    /// does not set `isSolved` or fire `solveTick`, so no win card appears and
    /// no stats are recorded.
    func revealSolution() {
        guard !isSolved, !revealed else { return }
        activeEdges = model.solution
        xEdges = []
        revealed = true
    }

    /// First clue cell whose current count doesn't match its target.
    private func unsatisfiedCell() -> Cell? {
        let p = model.puzzle
        for r in 0..<p.rows {
            for c in 0..<p.cols {
                let cell = Cell(c: c, r: r)
                guard let target = model.clues[cell] else { continue }
                if p.hideClues.contains(cell) { continue }
                let count = model.count(cell: cell, in: activeEdges)
                if count != target {
                    return cell
                }
            }
        }
        // Fall back to a hidden cell that's unsatisfied (rare).
        for r in 0..<p.rows {
            for c in 0..<p.cols {
                let cell = Cell(c: c, r: r)
                guard let target = model.clues[cell] else { continue }
                let count = model.count(cell: cell, in: activeEdges)
                if count != target { return cell }
            }
        }
        return nil
    }

    /// Add one edge that's in the solution but missing from the player's loop,
    /// or remove one that's wrongly present.
    private func placeOneMissingEdge() {
        // Prefer making a move on an unsatisfied clue cell so the help is local.
        let p = model.puzzle
        if let cell = unsatisfiedCell() {
            // Try the cell's own edges first.
            let cellEdges = Edge.cellEdges(c: cell.c, r: cell.r)
            for e in cellEdges where model.solution.contains(e) && !activeEdges.contains(e) {
                activeEdges.insert(e)
                xEdges.remove(e)
                if model.isSolved(active: activeEdges) {
                    isSolved = true
                    solveTick &+= 1
                }
                return
            }
            // Remove a wrongly-active edge on the cell.
            for e in cellEdges where !model.solution.contains(e) && activeEdges.contains(e) {
                activeEdges.remove(e)
                return
            }
        }
        // Global fallback: add the first missing solution edge anywhere.
        for e in model.solution where !activeEdges.contains(e) {
            activeEdges.insert(e)
            xEdges.remove(e)
            if model.isSolved(active: activeEdges) {
                isSolved = true
                solveTick &+= 1
            }
            return
        }
        // Or remove the first wrong edge.
        for e in activeEdges where !model.solution.contains(e) {
            activeEdges.remove(e)
            return
        }
        _ = p
    }

    // MARK: Reset

    func reset() {
        activeEdges = puzzle.presetActive
        xEdges = []
        mode = .draw
        elapsedSeconds = 0
        hintsUsed = 0
        isSolved = false
        revealed = false
    }
}
