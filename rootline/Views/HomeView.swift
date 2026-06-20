import SwiftUI
import ShroomKit

struct HomeView: View {
    let tier: Tier
    let onPickDifficulty: () -> Void
    let onPlay: () -> Void
    let onStats: () -> Void
    let onHowToPlay: () -> Void
    let onSettings: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                PillIconButton(systemName: "gearshape", accessibilityLabel: "Settings", action: onSettings)
            }
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.pill)
                    .frame(width: 92, height: 92)
                    .overlay(MyceliumIcon().padding(16))
                Text("Rootline")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.text)
                Text("A cozy loop puzzle for mushroom foragers.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(palette.sub)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 230)
            }
            Spacer(minLength: 0)
            VStack(spacing: 11) {
                difficultyCard
                primaryButton("Play", action: onPlay)
                HStack(spacing: 6) {
                    textButton(icon: "chart.bar.fill", title: "Stats", action: onStats)
                    textButton(icon: "questionmark.circle", title: "How to play", action: onHowToPlay)
                }
            }
            Spacer(minLength: 24)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.appBg.ignoresSafeArea())
    }

    private var difficultyCard: some View {
        Button(action: onPickDifficulty) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    EyebrowLabel("Difficulty")
                    Text(tier.label)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(palette.text)
                    Text(tier.meta)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(palette.sub)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.sub)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.pill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.accent)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func textButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(palette.sub)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
