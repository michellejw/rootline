import SwiftUI
import ShroomKit

struct StatsView: View {
    @Bindable var completions: CompletionStore
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
                    if completions.hasAnyStats {
                        Text("\(completions.totalCleared) groves cleared")
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
            Button("Clear", role: .destructive) { completions.clearAll() }
        } message: {
            Text("This wipes every fastest time and cleared count across all tiers. Can't be undone.")
        }
    }

    private var header: some View {
        ScreenHeader("Stats", onBack: onClose) {
            if completions.hasAnyStats {
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
        let best = completions.bestSeconds(for: tier)
        let count = completions.clearedCount(for: tier)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                EyebrowLabel(tier.label)
                Spacer()
                Text(tier.shortMeta)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(palette.sub)
            }
            if let best {
                Text("Your fastest: \(best.asTimerString)")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
                Text("\(count) cleared")
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
