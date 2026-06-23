import SwiftUI
import ShroomKit

struct ArchiveView: View {
    let daily: DailyService?
    @Bindable var completions: CompletionStore
    let floor: Date
    let onPlay: (Date) -> Void
    let onClose: () -> Void

    @Environment(\.palette) private var palette

    private var calendar: Calendar { Calendar.autoupdatingCurrent }
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var floorDay: Date { calendar.startOfDay(for: floor) }

    /// Set of in-window dates (start-of-day), for fast membership checks.
    private var availableDates: Set<Date> {
        guard floorDay <= today else { return [] }
        var out: Set<Date> = []
        var d = floorDay
        while d <= today {
            out.insert(d)
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }

    /// Months covered by the archive window, most-recent first.
    private var monthsDescending: [Date] {
        guard floorDay <= today else { return [] }
        var months: [Date] = []
        var cursor = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let stop = calendar.date(from: calendar.dateComponents([.year, .month], from: floorDay))!
        while cursor >= stop {
            months.append(cursor)
            guard let prev = calendar.date(byAdding: .month, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return months
    }

    private var streak: Int {
        guard let daily else { return 0 }
        return daily.currentStreak(today: Date()) { completions.isCleared($0) }
    }

    private static let weekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let cellColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader("Archive", onBack: onClose)
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 4)

            VStack(spacing: 6) {
                if streak > 0 {
                    Text(streak == 1 ? "1 day streak" : "\(streak) day streak")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(palette.sub)
                }
                Text("Mon–Tue 4×6 · Wed–Thu 5×7 · Fri 6×9 · Sat–Sun 7×10")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(palette.sub.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)

            ScrollView {
                weekdayHeader
                    .padding(.horizontal, 22)
                    .padding(.bottom, 6)

                VStack(spacing: 22) {
                    ForEach(monthsDescending, id: \.timeIntervalSince1970) { monthStart in
                        monthSection(monthStart)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background(palette.appBg.ignoresSafeArea())
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: cellColumns, spacing: 0) {
            ForEach(Array(Self.weekdayLetters.enumerated()), id: \.offset) { _, letter in
                Text(letter)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.sub)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func monthSection(_ monthStart: Date) -> some View {
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<2
        let firstWeekday = calendar.component(.weekday, from: monthStart) // 1=Sun
        let leadingPad = firstWeekday - 1
        let dayCount = range.count
        let available = availableDates
        VStack(alignment: .leading, spacing: 8) {
            Text(monthStart.formatted(.dateTime.month(.wide).year()))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.text)
            LazyVGrid(columns: cellColumns, spacing: 6) {
                ForEach(0..<(leadingPad + dayCount), id: \.self) { idx in
                    if idx < leadingPad {
                        Color.clear.frame(height: 52)
                    } else {
                        let dayNum = idx - leadingPad + 1
                        let date = calendar.date(byAdding: .day, value: dayNum - 1, to: monthStart) ?? monthStart
                        if available.contains(date) {
                            availableCell(date)
                        } else {
                            disabledCell(date)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func availableCell(_ date: Date) -> some View {
        let dp = daily?.puzzle(for: date)
        let cleared = dp.map { completions.isCleared($0) } ?? false
        let isToday = calendar.isDateInToday(date)
        Button {
            onPlay(date)
        } label: {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.text)
                Image(systemName: cleared ? "checkmark.circle.fill" : "circle")
                    .font(.system(.caption))
                    .foregroundStyle(cleared ? palette.accent : palette.sub.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.pill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(palette.accent, lineWidth: isToday ? 2 : 0)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(date.formatted(.dateTime.weekday(.wide).month().day())), \(dp?.tier.label ?? ""), \(cleared ? "cleared" : "not cleared")"))
    }

    @ViewBuilder
    private func disabledCell(_ date: Date) -> some View {
        Text(date.formatted(.dateTime.day()))
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(palette.sub.opacity(0.35))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
    }
}
