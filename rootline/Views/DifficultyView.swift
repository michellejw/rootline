import SwiftUI
import ShroomKit

struct DifficultyView: View {
    let selected: Tier
    let onBack: () -> Void
    let onPick: (Tier) -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 22)
            VStack(spacing: 11) {
                ForEach(Tier.allCases) { tier in
                    tierRow(tier)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.appBg.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 12) {
            PillIconButton(systemName: "chevron.left", accessibilityLabel: "Back", action: onBack)
            Text("Difficulty")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.text)
            Spacer()
        }
    }

    private func tierRow(_ tier: Tier) -> some View {
        let isSelected = tier == selected
        return Button { onPick(tier) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.label)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.text)
                    Text(tier.meta)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(palette.sub)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? palette.accent : palette.tierBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? palette.tierSelBg : palette.tierBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? palette.accent : palette.tierBorder, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
