import SwiftUI
import ShroomKit

@MainActor
@Observable
final class TutorialFlow {
    var index: Int = 0
    var board: Board

    init() {
        let lesson = PuzzleData.lessons[0]
        self.board = Board(puzzle: lesson.puzzle, tier: nil, groveNumber: 1, allowHints: false)
    }

    var lesson: PuzzleData.Lesson {
        PuzzleData.lessons[index]
    }

    var isLast: Bool { index == PuzzleData.lessons.count - 1 }

    func next() {
        guard !isLast else { return }
        index += 1
        let l = PuzzleData.lessons[index]
        board = Board(puzzle: l.puzzle, tier: nil, groveNumber: index + 1, allowHints: false)
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

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, 10)
            instructionPill
                .padding(.bottom, 8)
            coachingSlot
                .padding(.bottom, 6)
            BoardView(board: flow.board, look: settings.look)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            unlockStrip
                .padding(.top, 16)
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
                Text("Skip")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.sub)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.pill)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: Instruction pill

    private var instructionPill: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(flow.lesson.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.text)
                Text(flow.lesson.instruction)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(palette.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.pill)
        )
    }

    // MARK: Coaching slot (fixed height, opacity-toggled so layout never jumps)

    private var coachingSlot: some View {
        let msg = errorMessage ?? stuckHint
        let isError = errorMessage != nil
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "lightbulb.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isError ? palette.warn : palette.accent)
            Text(msg ?? " ")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(palette.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: coachingHeight)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(msg == nil ? Color.clear : palette.tierSelBg)
        )
        .opacity(msg == nil ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: stuckHint)
    }

    // MARK: Over-fill detection

    private func evaluateClues() {
        let model = flow.board.model
        let p = model.puzzle
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
            }
        }
        errorMessage = nil
    }

    // MARK: Unlock strip (post-solve)

    @ViewBuilder
    private var unlockStrip: some View {
        if showUnlock {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Text("Unlocked: \"\(flow.lesson.unlock)\"")
                        .font(.system(size: 13.5, design: .rounded))
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
                Button(action: advance) {
                    Text(flow.isLast ? "Start playing" : "Next lesson")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.accentText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(palette.accent)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .transition(.opacity)
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
