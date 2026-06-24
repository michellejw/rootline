import SwiftUI
import ShroomKit

struct HomeView: View {
    let today: AppState.TodayContext?
    let onPlayToday: () -> Void
    let onReplayToday: () -> Void
    let onArchive: () -> Void
    let onStats: () -> Void
    let onHowToPlay: () -> Void

    @Environment(\.palette) private var palette
    @State private var confirmingReplay: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.pill)
                    .frame(width: 92, height: 92)
                    .overlay(MyceliumIcon().padding(16))
                Text("Mycogrid")
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
                todayCard
                Button(today?.cleared == true ? "Play again" : "Play today") {
                    if today?.cleared == true {
                        confirmingReplay = true
                    } else {
                        onPlayToday()
                    }
                }
                .buttonStyle(.shroomPrimary(prominent: true))
                .disabled(today == nil)
                HStack(spacing: 6) {
                    textButton(icon: "calendar", title: "Archive", action: onArchive)
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
        .alert("Play again?", isPresented: $confirmingReplay) {
            Button("Cancel", role: .cancel) { }
            Button("Play") { onReplayToday() }
        } message: {
            Text("Your cleared time will be kept if you don't beat it.")
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            EyebrowLabel("Today's grove")
            if let today {
                Text(today.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.text)
                HStack(spacing: 8) {
                    Text(today.tier.label)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(palette.sub)
                    if today.cleared {
                        Text("· Cleared\(today.bestSeconds.map { " · \($0.asTimerString)" } ?? "")")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(palette.accent)
                    }
                }
            } else {
                Text("Couldn't load today's puzzle")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.pill))
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
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
