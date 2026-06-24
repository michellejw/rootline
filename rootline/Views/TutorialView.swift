import SwiftUI
import ShroomKit

@MainActor
@Observable
final class TutorialFlow {
    var index: Int = 0
    var board: Board

    init() {
        let lesson = PuzzleData.lessons[0]
        self.board = Board(puzzle: lesson.puzzle, tier: nil, allowHints: false)
    }

    var lesson: PuzzleData.Lesson {
        PuzzleData.lessons[index]
    }

    var isLast: Bool { index == PuzzleData.lessons.count - 1 }

    func next() {
        guard !isLast else { return }
        index += 1
        let l = PuzzleData.lessons[index]
        board = Board(puzzle: l.puzzle, tier: nil, allowHints: false)
    }
}

struct TutorialView: View {
    @Bindable var flow: TutorialFlow
    let settings: Settings
    let onFinish: () -> Void
    let onSkip: () -> Void

    @Environment(\.palette) private var palette
    @State private var showUnlock: Bool = false
    @State private var errorMessage: String? = nil
    @State private var stuckHint: String? = nil

    private let coachingHeight: CGFloat = 56
    /// Fixed-height bottom area so the board never reflows when the mode toggle
    /// is swapped for the unlock strip on solve.
    private let bottomSlotHeight: CGFloat = 140

    /// Board's natural aspect ratio including its padding — matches
    /// `BoardLayout`'s `cell * (cols + 1.24) / cell * (rows + 1.24)` so the
    /// outer frame matches the inner draw bounds.
    private var boardAspect: CGFloat {
        let cols = CGFloat(flow.board.puzzle.cols)
        let rows = CGFloat(flow.board.puzzle.rows)
        return (cols + 1.24) / (rows + 1.24)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, 10)
            instructionPill
                .padding(.bottom, 8)
            coachingSlot
                .padding(.bottom, 6)
            Spacer(minLength: 0)
            BoardView(board: flow.board)
                .aspectRatio(boardAspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            bottomSlot
                .padding(.top, 14)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(palette.appBg.ignoresSafeArea())
        .onChange(of: flow.index) { _, _ in
            showUnlock = false
            errorMessage = nil
            stuckHint = nil
        }
        .onChange(of: flow.board.tapTick) { _, _ in
            stuckHint = nil
            evaluateClues()
        }
        .onChange(of: flow.board.isSolved) { _, solved in
            if solved {
                stuckHint = nil
                errorMessage = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    withAnimation(.easeInOut(duration: 0.3)) { showUnlock = true }
                }
            }
        }
        .task(id: "\(flow.index)-\(flow.board.tapTick)") {
            try? await Task.sleep(for: .seconds(45))
            if !Task.isCancelled, !flow.board.isSolved {
                stuckHint = flow.lesson.stuckHint
            }
        }
    }

    // MARK: Top bar (Skip only — no page counter)

    private var topBar: some View {
        HStack {
            Button(action: onSkip) {
                Text("Skip all")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.sub)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.pill)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: skipLesson) {
                HStack(spacing: 4) {
                    Text(flow.isLast ? "Finish" : "Skip lesson")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(palette.sub)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func skipLesson() {
        if flow.isLast {
            onFinish()
        } else {
            flow.next()
        }
    }

    // MARK: Instruction pill

    private var instructionPill: some View {
        TutorialBannerCard(title: flow.lesson.title, message: flow.lesson.instruction)
    }

    // MARK: Coaching slot (fixed height, opacity-toggled so layout never jumps)

    private var coachingSlot: some View {
        let msg = errorMessage ?? stuckHint
        let tone: NudgeTone = errorMessage != nil ? .warning : .guidance
        return Group {
            if let msg {
                NudgeToast(msg, tone: tone)
                    .lineLimit(2)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: coachingHeight)
        .opacity(msg == nil ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: stuckHint)
    }

    // MARK: Bottom slot — fixed height; holds modeToggle OR unlockStrip via opacity

    private var bottomSlot: some View {
        ZStack(alignment: .top) {
            modeToggle
                .opacity(flow.board.isSolved ? 0 : 1)
                .allowsHitTesting(!flow.board.isSolved)
            unlockStrip
                .opacity(showUnlock ? 1 : 0)
                .allowsHitTesting(showUnlock)
        }
        .frame(maxWidth: .infinity)
        .frame(height: bottomSlotHeight, alignment: .top)
        .animation(.easeInOut(duration: 0.25), value: showUnlock)
        .animation(.easeInOut(duration: 0.25), value: flow.board.isSolved)
    }

    // MARK: Draw / Mark mode toggle (mirrors PlayView)

    private var modeToggle: some View {
        SegmentedToggle(
            selection: Binding(get: { flow.board.mode }, set: { flow.board.mode = $0 }),
            segments: [
                .init(.draw, title: "Draw thread") { threadGlyph },
                .init(.mark, title: "Mark dead") {
                    Text("✕").font(.system(.footnote, design: .rounded).weight(.semibold))
                },
            ]
        )
    }

    private var threadGlyph: some View {
        Capsule()
            .fill(Color.primary)
            .frame(width: 13, height: 3)
    }

    // MARK: Over-fill detection

    private func evaluateClues() {
        let model = flow.board.model
        let p = model.puzzle
        var hasUnderFilled = false
        for r in 0..<p.rows {
            for c in 0..<p.cols {
                let cell = Cell(c: c, r: r)
                guard let target = model.clues[cell],
                      !p.hideClues.contains(cell) else { continue }
                let count = model.count(cell: cell, in: flow.board.activeEdges)
                if count > target {
                    let msg = target == 0
                        ? "That cell wants no thread — switch to Mark dead and X out its edges."
                        : "That cell only takes \(target) thread\(target == 1 ? "" : "s")."
                    errorMessage = msg
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        if errorMessage == msg { errorMessage = nil }
                    }
                    return
                }
                if count < target { hasUnderFilled = true }
            }
        }
        // No over-fills. If the loop closes but a visible clue still wants more
        // thread, the player drew a *different* loop from the intended one and
        // probably thinks they're done. Nudge them at the unsatisfied clue.
        if hasUnderFilled, !flow.board.isSolved,
           model.isClosedLoop(active: flow.board.activeEdges) {
            errorMessage = "Your loop closes, but a clue still wants more thread. Look for the number that isn't green."
            return
        }
        errorMessage = nil
    }

    // MARK: Unlock strip (post-solve)

    private var unlockStrip: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.accent)
                Text("Unlocked: \"\(flow.lesson.unlock)\"")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.tierSelBg)
            )
            Button(flow.isLast ? "Start playing" : "Next lesson", action: advance)
                .buttonStyle(.shroomPrimary)
        }
    }

    private func advance() {
        if flow.isLast {
            onFinish()
        } else {
            flow.next()
            withAnimation(.easeInOut(duration: 0.25)) { showUnlock = false }
        }
    }
}
