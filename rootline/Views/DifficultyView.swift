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
        ScreenHeader("Difficulty", onBack: onBack)
    }

    private func tierRow(_ tier: Tier) -> some View {
        SelectionCard(title: tier.label, subtitle: tier.meta, isSelected: tier == selected) {
            onPick(tier)
        }
    }
}
