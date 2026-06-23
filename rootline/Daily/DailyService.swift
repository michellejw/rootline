import Foundation

/// Maps real calendar dates to puzzles and (Task 4) enumerates the archive
/// window. Pure given an injected `Calendar`; no I/O. The live app loads the
/// bundle from `Bundle.main` via `DailyService.live` (Part 2).
struct DailyService: Sendable {
    let bundle: PuzzleBundle
    var calendar: Calendar

    /// Fixed math anchor — a Monday. Its only requirement is to be ≤ every
    /// player's archive floor; otherwise arbitrary.
    static let mappingEpoch = DateComponents(year: 2026, month: 1, day: 5) // Monday

    init(bundle: PuzzleBundle, calendar: Calendar = .autoupdatingCurrent) {
        self.bundle = bundle
        self.calendar = calendar
    }

    /// Tier (grid size) for a date, from its weekday.
    /// Calendar weekday: 1=Sun, 2=Mon … 7=Sat.
    func tier(for date: Date) -> Tier {
        switch calendar.component(.weekday, from: date) {
        case 2, 3: return .sprout      // Mon, Tue
        case 4, 5: return .mycelium    // Wed, Thu
        case 6:    return .ancient     // Fri
        default:   return .oldGrowth   // Sat (7), Sun (1)
        }
    }

    /// 0-based count of dates in [epoch, date) that map to `tier` — i.e. the
    /// index of `date` among that tier's days since the epoch.
    func tierOccurrenceIndex(for date: Date, tier: Tier) -> Int {
        let day = calendar.startOfDay(for: date)
        guard let epoch = calendar.date(from: Self.mappingEpoch) else { return 0 }
        let epochDay = calendar.startOfDay(for: epoch)
        let totalDays = calendar.dateComponents([.day], from: epochDay, to: day).day ?? 0
        guard totalDays > 0 else { return 0 }
        var count = 0
        for offset in 0..<totalDays {                 // exclude `date` itself → 0-based
            if let d = calendar.date(byAdding: .day, value: offset, to: epochDay),
               self.tier(for: d) == tier {
                count += 1
            }
        }
        return count
    }

    /// The puzzle for a date: the n-th occurrence of that tier's weekday since
    /// the epoch, indexed into the tier's append-only pool (cycling on overflow).
    func puzzle(for date: Date) -> DailyPuzzle? {
        let t = tier(for: date)
        let pool = bundle.puzzles(for: t)
        guard !pool.isEmpty else { return nil }
        let n = tierOccurrenceIndex(for: date, tier: t)
        return pool[n % pool.count]
    }

    /// Archive back-scroll floor: 14 days before first open, fixed once.
    static func archiveFloor(firstOpen: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: firstOpen))
            ?? calendar.startOfDay(for: firstOpen)
    }

    /// Start-of-day dates from `floor` through `today` inclusive, most-recent-first.
    func archiveDates(floor: Date, today: Date) -> [Date] {
        let f = calendar.startOfDay(for: floor)
        let t = calendar.startOfDay(for: today)
        guard t >= f else { return [] }
        let n = calendar.dateComponents([.day], from: f, to: t).day ?? 0
        let ascending = (0...n).compactMap { calendar.date(byAdding: .day, value: $0, to: f) }
        return ascending.reversed()
    }

    /// Current backfillable streak: consecutive cleared days ending at today, or at
    /// yesterday when today is not cleared yet. Walks backward, stopping at the
    /// first gap. `isCleared` is supplied by the completion store.
    func currentStreak(today: Date, isCleared: (DailyPuzzle) -> Bool) -> Int {
        var day = calendar.startOfDay(for: today)
        // If today's puzzle isn't cleared, an in-progress today shouldn't break the
        // streak — start the count from yesterday.
        if let p = puzzle(for: day), !isCleared(p) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while let p = puzzle(for: day), isCleared(p) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}
