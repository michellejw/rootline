import SwiftUI
import ShroomKit

struct WinCard: View {
    let board: Board
    /// True when this clear beat a pre-existing best time for the tier.
    let fastestYet: Bool
    /// True when this is a previously-cleared puzzle opened in review mode.
    /// Drives the secondary button: Replay (in review) vs Archive (fresh solve).
    let isReview: Bool
    let onMenu: () -> Void
    let onArchive: () -> Void
    let onReplay: () -> Void

    @Environment(\.palette) private var palette
    @State private var confirmingReplay: Bool = false

    var body: some View {
        ResultCard(
            title: title,
            subtitle: subtitle,
            note: fastestYet ? "Your fastest yet" : nil,
            primaryLabel: "Done", onPrimary: onMenu,
            secondaryLabel: isReview ? "Replay" : "Archive",
            onSecondary: { isReview ? (confirmingReplay = true) : onArchive() }
        ) {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(palette.tierSelBg)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(palette.accent)
                )
        }
        .alert("Play again?", isPresented: $confirmingReplay) {
            Button("Cancel", role: .cancel) { }
            Button("Play") { onReplay() }
        } message: {
            Text("Your cleared time will be kept if you don't beat it.")
        }
    }

    private var title: String {
        isReview ? "Previously cleared" : "Network connected!"
    }

    private var subtitle: String {
        let tierLabel = board.tier?.label ?? "Lesson"
        let size = "\(board.puzzle.cols)×\(board.puzzle.rows)"
        let time = board.elapsedSeconds.asTimerString
        return "\(tierLabel) · \(size) · cleared in \(time)"
    }
}
