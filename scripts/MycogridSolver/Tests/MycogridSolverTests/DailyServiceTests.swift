// scripts/MycogridSolver/Tests/MycogridSolverTests/DailyServiceTests.swift
import Testing
import Foundation
@testable import MycogridSolver

@Suite struct DailyServiceTests {
    // A UTC calendar makes weekday math deterministic in tests.
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// Build a bundle with N distinctly-id'd placeholder puzzles per tier so we
    /// can read back which index a date selected. (Solver validity is not under
    /// test here — only the mapping.)
    static func bundle(perTier n: Int) -> PuzzleBundle {
        var byTier: [Tier: [DailyPuzzle]] = [:]
        for tier in Tier.allCases {
            byTier[tier] = (0..<n).map { i in
                DailyPuzzle(id: "\(tier.rawValue)-\(i)", tier: tier,
                            puzzle: Puzzle(cols: tier.cols, rows: tier.rows, inside: [[0,0]]))
            }
        }
        return PuzzleBundle(byTier: byTier)
    }

    func svc(_ n: Int = 300) -> DailyService {
        DailyService(bundle: Self.bundle(perTier: n), calendar: Self.utc)
    }

    @Test func weekdayMapsToTier() {
        let s = svc()
        // 2026-06-22 is a Monday.
        #expect(s.tier(for: Self.day(2026, 6, 22)) == .sprout)     // Mon
        #expect(s.tier(for: Self.day(2026, 6, 23)) == .sprout)     // Tue
        #expect(s.tier(for: Self.day(2026, 6, 24)) == .mycelium)   // Wed
        #expect(s.tier(for: Self.day(2026, 6, 25)) == .mycelium)   // Thu
        #expect(s.tier(for: Self.day(2026, 6, 26)) == .ancient)    // Fri
        #expect(s.tier(for: Self.day(2026, 6, 27)) == .oldGrowth)  // Sat
        #expect(s.tier(for: Self.day(2026, 6, 28)) == .oldGrowth)  // Sun
    }

    @Test func epochMondayIsSproutOccurrenceZero() {
        let s = svc()
        // mappingEpoch = 2026-01-05 (Mon) → first sprout day, index 0.
        let p = s.puzzle(for: Self.day(2026, 1, 5))
        #expect(p?.id == "sprout-0")
    }

    @Test func occurrenceIndexCountsOnlyMatchingWeekdays() {
        let s = svc()
        // Tue 2026-01-06 is the 2nd sprout day since epoch → index 1.
        #expect(s.tierOccurrenceIndex(for: Self.day(2026, 1, 6), tier: .sprout) == 1)
        // Next Mon 2026-01-12 is the 3rd sprout day → index 2.
        #expect(s.tierOccurrenceIndex(for: Self.day(2026, 1, 12), tier: .sprout) == 2)
        // First ancient day (Fri 2026-01-09) → index 0.
        #expect(s.tierOccurrenceIndex(for: Self.day(2026, 1, 9), tier: .ancient) == 0)
    }

    @Test func mappingIsDeterministic() {
        let s = svc()
        let a = s.puzzle(for: Self.day(2026, 6, 22))?.id
        let b = s.puzzle(for: Self.day(2026, 6, 22))?.id
        #expect(a == b)
    }

    @Test func poolCyclesWithModulo() {
        // Only 1 sprout puzzle → every sprout day maps to index 0.
        let s = DailyService(bundle: Self.bundle(perTier: 1), calendar: Self.utc)
        #expect(s.puzzle(for: Self.day(2026, 1, 5))?.id == "sprout-0")
        #expect(s.puzzle(for: Self.day(2026, 1, 6))?.id == "sprout-0")
    }

    @Test func appendOnlyStabilityHoldsBeforeWrap() {
        // A larger pool must not change the puzzle for a date whose index < oldCount.
        let small = DailyService(bundle: Self.bundle(perTier: 10), calendar: Self.utc)
        let big   = DailyService(bundle: Self.bundle(perTier: 50), calendar: Self.utc)
        let d = Self.day(2026, 1, 12)   // sprout index 2 (< 10)
        #expect(small.puzzle(for: d)?.id == big.puzzle(for: d)?.id)
    }

    @Test func emptyPoolReturnsNil() {
        let s = DailyService(bundle: PuzzleBundle(byTier: [:]), calendar: Self.utc)
        #expect(s.puzzle(for: Self.day(2026, 6, 22)) == nil)
    }

    @Test func archiveFloorIsFourteenDaysBefore() {
        let floor = DailyService.archiveFloor(firstOpen: Self.day(2026, 6, 22), calendar: Self.utc)
        #expect(floor == Self.day(2026, 6, 8))
    }
}

@Suite struct DailyServiceArchiveTests {
    typealias T = DailyServiceTests
    func svc(_ n: Int = 300) -> DailyService {
        DailyService(bundle: DailyServiceTests.bundle(perTier: n), calendar: DailyServiceTests.utc)
    }

    @Test func archiveDatesAreInclusiveAndDescending() {
        let s = svc()
        let dates = s.archiveDates(floor: T.day(2026, 6, 20), today: T.day(2026, 6, 22))
        #expect(dates == [T.day(2026, 6, 22), T.day(2026, 6, 21), T.day(2026, 6, 20)])
    }

    @Test func archiveDatesEmptyWhenTodayBeforeFloor() {
        let s = svc()
        #expect(s.archiveDates(floor: T.day(2026, 6, 22), today: T.day(2026, 6, 20)).isEmpty)
    }

    @Test func streakCountsConsecutiveClearedEndingToday() {
        let s = svc()
        // Cleared: 20, 21, 22 (today). Streak = 3.
        let cleared: Set<String> = [
            s.puzzle(for: T.day(2026, 6, 20))!.id,
            s.puzzle(for: T.day(2026, 6, 21))!.id,
            s.puzzle(for: T.day(2026, 6, 22))!.id,
        ]
        let n = s.currentStreak(today: T.day(2026, 6, 22)) { cleared.contains($0.id) }
        #expect(n == 3)
    }

    @Test func streakEndsYesterdayWhenTodayUnsolved() {
        let s = svc()
        // Cleared: 20, 21 but NOT 22. Today 22 unsolved → streak ends yesterday = 2.
        let cleared: Set<String> = [
            s.puzzle(for: T.day(2026, 6, 20))!.id,
            s.puzzle(for: T.day(2026, 6, 21))!.id,
        ]
        let n = s.currentStreak(today: T.day(2026, 6, 22)) { cleared.contains($0.id) }
        #expect(n == 2)
    }

    @Test func streakStopsAtAGap() {
        let s = svc()
        // Cleared: 22 (today) and 20, but 21 missing → streak = 1 (just today).
        let cleared: Set<String> = [
            s.puzzle(for: T.day(2026, 6, 22))!.id,
            s.puzzle(for: T.day(2026, 6, 20))!.id,
        ]
        let n = s.currentStreak(today: T.day(2026, 6, 22)) { cleared.contains($0.id) }
        #expect(n == 1)
    }

    @Test func streakIsZeroWhenNothingCleared() {
        let s = svc()
        #expect(s.currentStreak(today: T.day(2026, 6, 22)) { _ in false } == 0)
    }
}
