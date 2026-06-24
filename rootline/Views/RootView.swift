import SwiftUI
import ShroomKit

enum Screen {
    case launching
    case welcome
    case home
    case play
    case tutorial
    case stats
    case archive
}

@MainActor
@Observable
final class AppState {
    var screen: Screen = .launching
    let settings: Settings = Settings()
    let progressStore: ProgressStore = ProgressStore()
    let daily: DailyService? = DailyService.live()
    let completions: CompletionStore = CompletionStore()

    var activeBoard: Board?
    var tutorial: TutorialFlow?

    /// The calendar date of the board currently in play (today, or an archived day).
    private(set) var playingDate: Date = Date()
    private(set) var playingPuzzleID: String?
    /// True when the active board was opened as a previously-cleared puzzle
    /// (review mode). Drives the WinCard's secondary button.
    private(set) var isReviewing: Bool = false

    struct TodayContext {
        let date: Date
        let tier: Tier
        let cleared: Bool
        let bestSeconds: Int?
    }

    func todayContext() -> TodayContext? {
        guard let daily, let dp = daily.puzzle(for: Date()) else { return nil }
        return TodayContext(
            date: Date(),
            tier: dp.tier,
            cleared: completions.isCleared(dp),
            bestSeconds: completions.bestSeconds(for: dp.tier)
        )
    }

    /// Start today's daily puzzle. If already cleared, opens in review mode
    /// (solved board + win card); use `replayCurrent()` to force a fresh attempt.
    func startToday() { playDaily(date: Date(), forceFresh: false) }

    /// Replay today's puzzle from scratch (called from the Home button).
    func replayToday() { playDaily(date: Date(), forceFresh: true) }

    /// Start the puzzle for a specific calendar date (from the archive).
    func startArchived(date: Date) { playDaily(date: date, forceFresh: false) }

    /// Replay the in-play puzzle from scratch (called from the WinCard's
    /// "Replay" affordance in review mode).
    func replayCurrent() { playDaily(date: playingDate, forceFresh: true) }

    private func playDaily(date: Date, forceFresh: Bool) {
        guard let daily, let dp = daily.puzzle(for: date) else { return }
        playingDate = date
        playingPuzzleID = dp.id
        let cleared = completions.isCleared(dp)
        let board = Board(puzzle: dp.puzzle, tier: dp.tier)
        if !forceFresh, cleared, let best = completions.byID[dp.id]?.bestSeconds {
            board.openAsCleared(bestSeconds: best)
            isReviewing = true
        } else {
            isReviewing = false
        }
        activeBoard = board
        saveProgress()
        screen = .play
    }

    /// Record a clear of the in-play puzzle. Returns true on a new per-tier best.
    @discardableResult
    func recordClear(seconds: Int) -> Bool {
        guard let id = playingPuzzleID, let tier = activeBoard?.tier else { return false }
        return completions.record(id: id, tier: tier, seconds: seconds)
    }

    func openArchive() { screen = .archive }

    /// Called once when the launch loader finishes its first beat. If a
    /// previous session was in progress, jump straight into it.
    func finishLaunch() {
        if let saved = progressStore.load(),
           let daily,
           let board = Board(restoring: saved, using: daily),
           !board.isSolved {
            activeBoard = board
            playingDate = saved.playedDate
            playingPuzzleID = saved.puzzleID
            screen = .play
            return
        }
        if !settings.hasSeenTutorial {
            screen = .welcome
        } else {
            screen = .home
        }
    }

    func skipWelcome() {
        settings.hasSeenTutorial = true
        screen = .home
    }

    /// Snapshot the active board to disk. Cheap; called on every tap and on
    /// scenePhase changes.
    func saveProgress() {
        guard let board = activeBoard, !board.isSolved,
              let id = playingPuzzleID,
              let snapshot = board.snapshot(puzzleID: id, playedDate: playingDate) else { return }
        progressStore.save(snapshot)
    }

    func clearSavedProgress() {
        progressStore.clear()
    }

    func goHome() {
        screen = .home
    }

    func openStats() {
        screen = .stats
    }

    func startTutorial() {
        tutorial = TutorialFlow()
        screen = .tutorial
    }

    func finishTutorial() {
        settings.hasSeenTutorial = true
        tutorial = nil
        screen = .home
    }
}

struct RootView: View {
    @State private var appState = AppState()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette.palette(for: colorScheme)
        ZStack {
            palette.appBg.ignoresSafeArea()
            content
        }
        .environment(\.palette, palette)
        .preferredColorScheme(appState.settings.themeMode.preferredColorScheme)
        .animation(.easeInOut(duration: 0.22), value: appState.screen)
    }

    @ViewBuilder
    private var content: some View {
        switch appState.screen {
        case .launching:
            LoadingView(message: "Loading") {
                MyceliumIcon()
            }
            .transition(.opacity)
            .task {
                try? await Task.sleep(for: .milliseconds(700))
                appState.finishLaunch()
            }
        case .welcome:
            WelcomeScaffold(
                title: "Welcome to Mycogrid",
                tagline: "A cozy loop puzzle for mushroom foragers. Want a quick tour before you dig in?",
                primaryLabel: "Show me how to play",
                secondaryLabel: "Jump right in",
                onPrimary: { appState.startTutorial() },
                onSecondary: { appState.skipWelcome() }
            ) {
                MyceliumIcon()
            }
            .transition(.opacity)
        case .home:
            HomeView(
                today: appState.todayContext(),
                onPlayToday: { appState.startToday() },
                onReplayToday: { appState.replayToday() },
                onArchive: { appState.openArchive() },
                onStats: { appState.openStats() },
                onHowToPlay: { appState.startTutorial() }
            )
            .transition(.opacity)
        case .play:
            if let board = appState.activeBoard {
                PlayView(
                    board: board,
                    settings: appState.settings,
                    playedDate: appState.playingDate,
                    isReview: appState.isReviewing,
                    onRecordClear: { appState.recordClear(seconds: $0) },
                    onArchive: { appState.openArchive() },
                    onReplay: { appState.replayCurrent() },
                    onMenu: {
                        appState.clearSavedProgress()
                        appState.goHome()
                    },
                    onBack: {
                        appState.clearSavedProgress()
                        appState.goHome()
                    },
                    onSave: { appState.saveProgress() },
                    onClearProgress: { appState.clearSavedProgress() }
                )
                .transition(.opacity)
            }
        case .tutorial:
            if let flow = appState.tutorial {
                TutorialView(
                    flow: flow,
                    settings: appState.settings,
                    onFinish: { appState.finishTutorial() },
                    onSkip: { appState.finishTutorial() }
                )
                .transition(.opacity)
            }
        case .stats:
            StatsView(
                completions: appState.completions,
                onClose: { appState.goHome() }
            )
            .transition(.opacity)
        case .archive:
            ArchiveView(
                daily: appState.daily,
                completions: appState.completions,
                floor: appState.settings.archiveFloor,
                onPlay: { date in appState.startArchived(date: date) },
                onClose: { appState.goHome() }
            )
            .transition(.opacity)
        }
    }
}
