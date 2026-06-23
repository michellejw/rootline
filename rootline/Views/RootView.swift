import SwiftUI
import ShroomKit

enum Screen {
    case launching
    case welcome
    case home
    case difficulty
    case play
    case tutorial
    case stats
    case archive
#if DEBUG
    case puzzleEditor
#endif
}

@MainActor
@Observable
final class AppState {
    var screen: Screen = .launching
    let settings: Settings = Settings()
    let progressStore: ProgressStore = ProgressStore()
    let scoreStore: ScoreStore = ScoreStore()
    let daily: DailyService? = DailyService.live()
    let completions: CompletionStore = CompletionStore()

    var activeBoard: Board?
    var tutorial: TutorialFlow?

    /// The calendar date of the board currently in play (today, or an archived day).
    private(set) var playingDate: Date = Date()
    private(set) var playingPuzzleID: String?

    private var currentPuzzleIndex: Int = 0

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

    /// Start today's daily puzzle.
    func startToday() { playDaily(date: Date()) }

    /// Start the puzzle for a specific calendar date (from the archive).
    func startArchived(date: Date) { playDaily(date: date) }

    private func playDaily(date: Date) {
        guard let daily, let dp = daily.puzzle(for: date) else { return }
        playingDate = date
        playingPuzzleID = dp.id
        let board = Board(puzzle: dp.puzzle, tier: dp.tier, groveNumber: 0)
        if completions.isCleared(dp), let best = completions.byID[dp.id]?.bestSeconds {
            board.openAsCleared(bestSeconds: best)
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
           let board = Board(restoring: saved),
           !board.isSolved {
            activeBoard = board
            currentPuzzleIndex = saved.groveNumber - 1
            settings.tier = saved.tier
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

    func startGame(tier: Tier) {
        settings.tier = tier
        currentPuzzleIndex = 0
        let puzzles = PuzzleData.puzzles(for: tier)
        let puzzle = puzzles[currentPuzzleIndex]
        let board = Board(
            puzzle: puzzle,
            tier: tier,
            groveNumber: currentPuzzleIndex + 1
        )
        activeBoard = board
        saveProgress()
        screen = .play
    }

    func nextPuzzle() {
        guard let tier = activeBoard?.tier else { return }
        let puzzles = PuzzleData.puzzles(for: tier)
        currentPuzzleIndex = (currentPuzzleIndex + 1) % puzzles.count
        let board = Board(
            puzzle: puzzles[currentPuzzleIndex],
            tier: tier,
            groveNumber: currentPuzzleIndex + 1
        )
        activeBoard = board
        saveProgress()
    }

    /// Snapshot the active board to disk. Cheap; called on every tap and on
    /// scenePhase changes.
    func saveProgress() {
        guard let board = activeBoard, !board.isSolved,
              let snapshot = board.snapshot() else { return }
        progressStore.save(snapshot)
    }

    func clearSavedProgress() {
        progressStore.clear()
    }

    func goHome() {
        screen = .home
    }

    func openDifficulty() {
        screen = .difficulty
    }

    func openStats() {
        screen = .stats
    }

    func startTutorial() {
        tutorial = TutorialFlow()
        screen = .tutorial
    }

#if DEBUG
    func openPuzzleEditor() {
        screen = .puzzleEditor
    }
#endif

    func finishTutorial() {
        settings.hasSeenTutorial = true
        tutorial = nil
        screen = .home
    }
}

struct RootView: View {
    @State private var appState = AppState()
    @State private var showSettings: Bool = false
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
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                settings: appState.settings,
                onTutorial: {
                    showSettings = false
                    appState.startTutorial()
                },
                onClose: { showSettings = false },
                onPuzzleEditor: {
#if DEBUG
                    showSettings = false
                    appState.openPuzzleEditor()
#endif
                }
            )
            .environment(\.palette, palette)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
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
                title: "Welcome to Rootline",
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
                onArchive: { appState.openArchive() },
                onStats: { appState.openStats() },
                onHowToPlay: { appState.startTutorial() },
                onSettings: { showSettings = true }
            )
            .transition(.opacity)
        case .difficulty:
            DifficultyView(
                selected: appState.settings.tier,
                onBack: { appState.goHome() },
                onPick: { tier in appState.startGame(tier: tier) }
            )
            .transition(.opacity)
        case .play:
            if let board = appState.activeBoard {
                PlayView(
                    board: board,
                    settings: appState.settings,
                    playedDate: appState.playingDate,
                    onRecordClear: { appState.recordClear(seconds: $0) },
                    onArchive: { appState.openArchive() },
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
#if DEBUG
        case .puzzleEditor:
            PuzzleEditorView(onClose: { appState.goHome() })
                .transition(.opacity)
#endif
        }
    }
}
