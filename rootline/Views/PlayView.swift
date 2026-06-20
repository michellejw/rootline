import SwiftUI
import ShroomKit

struct PlayView: View {
    @Bindable var board: Board
    let settings: Settings
    @Bindable var scoreStore: ScoreStore
    let onBack: () -> Void
    let onNext: () -> Void
    let onMenu: () -> Void
    let onSave: () -> Void
    let onClearProgress: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    @State private var fastestYet: Bool = false
    @State private var confirmingReveal: Bool = false
    @State private var confirmingLeave: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 6)
            statsRow
                .padding(.top, 14)
                .padding(.bottom, 10)
            BoardView(board: board, look: settings.look)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
            if !board.isSolved && !board.revealed {
                modeToggle
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            } else {
                Color.clear.frame(height: 96)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
        .background(palette.appBg.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if board.isSolved {
                WinCard(board: board, fastestYet: fastestYet, onNext: onNext, onMenu: onMenu)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if board.revealed {
                RevealedCard(board: board, onNext: onNext, onMenu: onMenu)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: board.isSolved)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: board.revealed)
        .alert("Show solution?", isPresented: $confirmingReveal) {
            Button("Cancel", role: .cancel) { }
            Button("Show") {
                board.revealSolution()
                onClearProgress()
            }
        } message: {
            Text("Reveal the full path for this puzzle. This clear won't be counted toward your stats.")
        }
        .alert("Leave puzzle?", isPresented: $confirmingLeave) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) { onBack() }
        } message: {
            Text("Your progress on this puzzle will be lost.")
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: board.tapTick)
        .sensoryFeedback(.success, trigger: board.solveTick)
        .task(id: ObjectIdentifier(board)) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                board.tick()
            }
        }
        .onChange(of: board.tapTick) { _, _ in onSave() }
        .onChange(of: board.solveTick) { _, _ in
            // Guard: when the board is swapped (Next puzzle), solveTick can
            // change from a non-zero value to 0. Only react to real solves.
            guard board.isSolved else { return }
            onClearProgress()
            if let tier = board.tier {
                fastestYet = scoreStore.record(seconds: board.elapsedSeconds, for: tier) == .newBest
            } else {
                fastestYet = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                onSave()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 0) {
            PillIconButton(systemName: "chevron.left", accessibilityLabel: "Back", action: { tappedBack() })
                .padding(.trailing, 6)
            PillIconButton(systemName: "eye", accessibilityLabel: "Show solution", isEnabled: revealEnabled, action: { confirmingReveal = true })
            Spacer()
            VStack(spacing: 1) {
                EyebrowLabel(board.tier?.label ?? "Lesson")
                Text("Grove #\(board.groveNumber)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.text)
            }
            Spacer()
            PillIconButton(systemName: settings.themeMode.iconName, accessibilityLabel: "Theme", action: { settings.cycleThemeMode() })
                .padding(.trailing, 6)
            PillIconButton(systemName: "questionmark", accessibilityLabel: "Hint", isEnabled: hintEnabled, action: { board.nextHint() })
        }
    }

    private func tappedBack() {
        if board.hasPlayerMoves && !board.isSolved && !board.revealed {
            confirmingLeave = true
        } else {
            onBack()
        }
    }

    private var hintEnabled: Bool {
        board.allowHints && !board.isSolved && !board.revealed
    }

    private var revealEnabled: Bool {
        board.allowHints && !board.isSolved && !board.revealed
    }

    private var hintsUsedLabel: String {
        board.hintsUsed == 1 ? "1 hint used" : "\(board.hintsUsed) hints used"
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            Spacer()
            if settings.showTimer {
                statPill(systemName: "clock", text: board.elapsedSeconds.asTimerString)
            }
            if board.allowHints && board.hintsUsed > 0 {
                hintsPill
            }
            Spacer()
        }
    }

    private func statPill(systemName: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.sub)
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.text)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.pill)
        )
    }

    private var hintsPill: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 8, height: 8)
            }
            Text(hintsUsedLabel)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.text)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.pill)
        )
    }

    // MARK: Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 6) {
            segment(title: "Draw thread",
                    icon: { AnyView(threadGlyph) },
                    isActive: board.mode == .draw,
                    action: { board.mode = .draw })
            segment(title: "Mark dead",
                    icon: { AnyView(
                        Text("✕")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                    ) },
                    isActive: board.mode == .mark,
                    action: { board.mode = .mark })
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.pill)
        )
    }

    private var threadGlyph: some View {
        Capsule()
            .fill(Color.primary)
            .frame(width: 13, height: 3)
    }

    private func segment(title: String, icon: () -> AnyView, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                icon()
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 4)
            .foregroundStyle(isActive ? palette.accentText : palette.sub)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? palette.accent : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

extension Int {
    var asTimerString: String {
        let m = self / 60
        let s = self % 60
        return String(format: "%d:%02d", m, s)
    }
}
