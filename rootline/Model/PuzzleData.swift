import Foundation

/// Tutorial lessons. Shipping puzzles are generated and bundled via
/// `puzzles.json` — see `PuzzleBundle` / `DailyService`.
enum PuzzleData {

    struct Lesson: Sendable {
        let title: String
        /// Single short instruction shown above the board the whole lesson.
        let instruction: String
        /// Nudge surfaced if the player is idle for ~30 seconds.
        let stuckHint: String
        /// Rule statement revealed after solving.
        let unlock: String
        let puzzle: Puzzle
    }

    static let lessons: [Lesson] = [
        // Lesson 1 — Drawing a loop. All clues hidden so any closed loop wins.
        Lesson(
            title: "Drawing a loop",
            instruction: "Tap edges between dots to draw one closed loop.",
            stuckHint: "Tap the four edges that wrap around the outside of the grid.",
            unlock: "Any single closed loop counts. Now let's see what the numbers do.",
            puzzle: Puzzle(cols: 2, rows: 2, inside: [
                [0,0],[1,0],[0,1],[1,1]
            ], hide: [
                [0,0],[1,0],[0,1],[1,1]
            ])
        ),
        // Lesson 2 — Reading the numbers. 3×1 strip; clues read 3, 2, 3.
        Lesson(
            title: "Reading the numbers",
            instruction: "The number tells you how many of that cell's edges have thread. Make every clue happy.",
            stuckHint: "The loop is just the rectangle's outline — eight edges around the three cells.",
            unlock: "Green means satisfied. Red means too many.",
            puzzle: Puzzle(cols: 3, rows: 1, inside: [
                [0,0],[1,0],[2,0]
            ])
        ),
        // Lesson 3 — The Zero.
        Lesson(
            title: "The Zero",
            instruction: "A 0 means none of its edges carry thread. Switch to Mark dead to X them out.",
            stuckHint: "The 0 sits in the top-left corner. In Mark dead mode, tap each of its four edges.",
            unlock: "A 0 means no threads pass through. Cross them all out.",
            puzzle: Puzzle(cols: 3, rows: 3, inside: [
                [1,1],[2,1],[1,2],[2,2]
            ], hide: [
                [1,0],[2,0],[0,1],[0,2]
            ])
        ),
        // Lesson 4 — Corner Three.
        Lesson(
            title: "Corner Three",
            instruction: "A 3 in a corner forces the two edges that hug the corner.",
            stuckHint: "Both 3s sit in corners — each one forces the two edges hugging its corner.",
            unlock: "A 3 in a corner gives you two free threads.",
            puzzle: Puzzle(cols: 2, rows: 2, inside: [
                [0,0],[1,0],[1,1]
            ])
        ),
        // Lesson 5 — Continuity. 7 of 8 boundary edges pre-drawn.
        Lesson(
            title: "Continuity",
            instruction: "One thread is missing. Find the dot with only one connection.",
            stuckHint: "Look along the top — one dot has just one thread reaching it.",
            unlock: "Every dot the thread touches needs exactly two connections.",
            puzzle: Puzzle(cols: 3, rows: 3, inside: [
                [1,1],[2,1],[1,2],[2,2]
            ], hide: [
                [0,0],[1,0],[2,0],[0,1],[0,2]
            ], presetActive: [
                .h(r: 1, c: 1),
                .h(r: 3, c: 1),
                .h(r: 3, c: 2),
                .v(r: 1, c: 1),
                .v(r: 2, c: 1),
                .v(r: 1, c: 3),
                .v(r: 2, c: 3)
            ])
        ),
        // Lesson 6 — Adjacent Threes.
        Lesson(
            title: "Adjacent Threes",
            instruction: "Two 3s side by side always share a thread.",
            stuckHint: "The vertical edge between the two 3s carries thread.",
            unlock: "Two 3s next to each other nearly solve themselves — look for pairs.",
            puzzle: Puzzle(cols: 2, rows: 2, inside: [
                [0,0],[1,0]
            ], hide: [
                [0,1],[1,1]
            ])
        )
    ]
}
