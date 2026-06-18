import SwiftUI
import ShroomKit

struct StatsView: View {
    @Bindable var scoreStore: ScoreStore
    let onClose: () -> Void

    @Environment(\.palette) private var palette
    @State private var confirmingClear: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Tier.allCases) { tier in
                        tierCard(tier)
                    }
                    if scoreStore.hasAnyStats {
                        Text("\(scoreStore.totalCleared) puzzles cleared")
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(palette.sub)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background(palette.appBg.ignoresSafeArea())
        .alert("Clear all stats?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) { scoreStore.clearAll() }
        } message: {
            Text("This wipes every fastest time and cleared count across all tiers. Can't be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.sub)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.pill)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("Stats")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.text)
            Spacer()
            if scoreStore.hasAnyStats {
                Button { confirmingClear = true } label: {
                    Text("Clear")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.sub)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tierCard(_ tier: Tier) -> some View {
        let stat = scoreStore.stat(for: tier)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(tier.label.uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .tracking(1.3)
                    .foregroundStyle(palette.sub)
                Spacer()
                Text(tier.shortMeta)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(palette.sub)
            }
            if let best = stat.bestSeconds {
                Text("Your fastest: \(best.asTimerString)")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
                Text("\(stat.clearedCount) cleared")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(palette.sub)
            } else {
                Text("Not cleared yet")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(palette.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.pill)
        )
    }
}
