import Foundation

/// Hand-curated puzzles per tier, plus the 4 tutorial lessons.
///
/// Puzzles are stored as a simply-connected `inside` region (col/row pairs); the
/// engine derives the solution loop + clues from the region. `hide` is the set
/// of cells whose clue digit is hidden from the player.
enum PuzzleData {

    // MARK: Shipping tiers
    //
    // Each tier ships with a small set of hand-curated puzzles. The "grove
    // number" displayed on the play screen is the 1-based index into the list.

    static let sprout: [Puzzle] = [
        // Grove #1 — the canonical Sprout shape, all clues shown.
        Puzzle(cols: 4, rows: 6, inside: [
            [1,0],[2,0],
            [0,1],[1,1],[2,1],[3,1],
            [0,2],[1,2],[2,2],[3,2],
            [0,3],[1,3],[2,3],[3,3],
            [0,4],[1,4],[2,4],[3,4],
            [1,5],[2,5]
        ]),
        // Grove #2 — an S-bend.
        Puzzle(cols: 4, rows: 6, inside: [
            [0,0],[1,0],[2,0],
            [2,1],[3,1],
            [1,2],[2,2],[3,2],
            [0,3],[1,3],[2,3],
            [0,4],[1,4],
            [1,5],[2,5],[3,5]
        ]),
        // Grove #3 — pinched mushroom cap.
        Puzzle(cols: 4, rows: 6, inside: [
            [1,0],[2,0],
            [0,1],[1,1],[2,1],[3,1],
            [1,2],[2,2],
            [1,3],[2,3],
            [0,4],[1,4],[2,4],[3,4],
            [1,5],[2,5]
        ]),
        // Grove #4
        Puzzle(cols: 4, rows: 6, inside: [
            [1,1],[2,1],
            [0,2],[1,2],[2,2],
            [1,3],[2,3],[3,3],
            [1,4],[2,4]
        ])
    ]

    static let mycelium: [Puzzle] = [
        // Grove #1 — the canonical Mycelium shape with medium clue density.
        Puzzle(cols: 5, rows: 7, inside: [
            [1,0],[2,0],
            [0,1],[1,1],[2,1],[3,1],
            [0,2],[1,2],[2,2],[3,2],[4,2],
            [0,3],[1,3],[2,3],[3,3],[4,3],
            [1,4],[2,4],[3,4],[4,4],
            [1,5],[2,5],[3,5],
            [2,6]
        ], hide: [
            [0,1],[3,1],[0,2],[2,2],[4,2],[1,3],[3,3],[4,3],
            [2,4],[1,5],[3,5],[2,6]
        ]),
        // Grove #2 — branching root.
        Puzzle(cols: 5, rows: 7, inside: [
            [2,0],
            [1,1],[2,1],[3,1],
            [0,2],[1,2],[2,2],[3,2],[4,2],
            [1,3],[2,3],[3,3],
            [0,4],[1,4],[2,4],[3,4],[4,4],
            [1,5],[2,5],[3,5],
            [2,6]
        ], hide: [
            [2,0],[1,1],[3,1],[0,2],[2,2],[4,2],[2,3],
            [0,4],[2,4],[4,4],[1,5],[3,5],[2,6]
        ])
    ]

    static let ancient: [Puzzle] = [
        // Grove #1 — a sparse spore cluster.
        Puzzle(cols: 6, rows: 9, inside: [
            [2,0],[3,0],
            [1,1],[2,1],[3,1],[4,1],
            [0,2],[1,2],[2,2],[3,2],[4,2],[5,2],
            [0,3],[1,3],[2,3],[3,3],[4,3],[5,3],
            [1,4],[2,4],[3,4],[4,4],[5,4],
            [0,5],[1,5],[2,5],[3,5],[4,5],
            [0,6],[1,6],[2,6],[3,6],[4,6],[5,6],
            [1,7],[2,7],[3,7],[4,7],
            [2,8],[3,8]
        ], hide: [
            [2,0],[3,0],
            [1,1],[3,1],
            [0,2],[2,2],[4,2],
            [1,3],[3,3],[5,3],
            [2,4],[4,4],
            [0,5],[2,5],[4,5],
            [1,6],[3,6],[5,6],
            [2,7],[4,7],
            [3,8]
        ])
    ]

    static let oldGrowth: [Puzzle] = [
        // Grove #1 — a tall mycorrhizal lattice with minimal clues.
        Puzzle(cols: 7, rows: 10, inside: [
            [2,0],[3,0],[4,0],
            [1,1],[2,1],[3,1],[4,1],[5,1],
            [0,2],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],
            [0,3],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],
            [0,4],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],
            [0,5],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],
            [0,6],[1,6],[2,6],[3,6],[4,6],[5,6],[6,6],
            [0,7],[1,7],[2,7],[3,7],[4,7],[5,7],[6,7],
            [1,8],[2,8],[3,8],[4,8],[5,8],
            [2,9],[3,9],[4,9]
        ], hide: [
            [2,0],[4,0],
            [1,1],[3,1],[5,1],
            [0,2],[2,2],[4,2],[6,2],
            [1,3],[3,3],[5,3],
            [0,4],[2,4],[4,4],[6,4],
            [1,5],[3,5],[5,5],
            [0,6],[2,6],[4,6],[6,6],
            [1,7],[3,7],[5,7],
            [2,8],[4,8],
            [3,9]
        ])
    ]

    static func puzzles(for tier: Tier) -> [Puzzle] {
        switch tier {
        case .sprout:    return sprout
        case .mycelium:  return mycelium
        case .ancient:   return ancient
        case .oldGrowth: return oldGrowth
        }
    }

    // MARK: Tutorial lessons

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
