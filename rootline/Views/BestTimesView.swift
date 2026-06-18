import SwiftUI
import ShroomKit

struct BestTimesView: View {
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
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Tier.allCases) { tier in
                        tierSection(tier)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background(palette.appBg.ignoresSafeArea())
        .alert("Clear all best times?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) { scoreStore.clearAll() }
        } message: {
            Text("This wipes every saved time across all tiers. Can't be undone.")
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
            Text("Best times")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.text)
            Spacer()
            if scoreStore.scores.values.contains(where: { !$0.isEmpty }) {
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

    @ViewBuilder
    private func tierSection(_ tier: Tier) -> some View {
        let entries = scoreStore.best(for: tier)
        VStack(alignment: .leading, spacing: 8) {
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
            if entries.isEmpty {
                emptyRow
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                        row(rank: idx + 1, entry: entry)
                    }
                }
            }
        }
    }

    private var emptyRow: some View {
        Text("No times yet — clear a puzzle to land on the board.")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(palette.sub)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.pill)
            )
    }

    private func row(rank: Int, entry: ScoreEntry) -> some View {
        HStack(spacing: 12) {
            Text("\(rank).")
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(palette.sub)
                .frame(width: 28, alignment: .leading)
            Text(entry.initials)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(palette.text)
                .tracking(2)
            Spacer()
            Text("Grove #\(entry.groveNumber)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(palette.sub)
            Text(entry.seconds.asTimerString)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.text)
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.tierBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.tierBorder, lineWidth: 1)
                )
        )
    }
}
