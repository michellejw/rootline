# Puzzle authoring workflow

Notes for future-you on how to design and ship new Rootline puzzles.

## TL;DR

1. In the app: **Settings → Debug → Puzzle editor**.
2. Tap a **tier shortcut** (Sprout / Mycelium / Ancient / Old Growth) to set the grid.
3. **Drag** across cells to paint them inside the loop. The engine derives the loop + clues live; the status line warns if you've created an enclosed hole.
4. Tap **Copy Swift**. The source lands on your clipboard (and prints to the Xcode console if you're tethered).
5. On your Mac, from the `rootline/` repo root:
   ```sh
   swift scripts/add-puzzle.swift sprout   # or mycelium, ancient, oldGrowth
   ```
6. Build the app. Done.

Universal Clipboard (iCloud + Handoff) gets the source from phone to Mac without AirDrop. There's also a Share button in the editor for AirDrop if you're untethered.

## The model

A puzzle is a `cols × rows` grid plus a **simply-connected region of "inside" cells**. The engine derives everything else:

- **Solution loop** = the boundary between inside and outside cells (off-grid counts as outside).
- **Clue for each cell** = how many of its four edges are in the solution (0–4).

You can also hide some clues so the puzzle is harder. Hidden cells still have to be satisfied by the final loop — they just don't display the number.

## Tier sizes

| Tier | Cols × Rows | Density |
|---|---|---|
| Sprout | 4 × 6 | Dense (most clues shown) |
| Mycelium | 5 × 7 | Medium |
| Ancient | 6 × 9 | Sparse |
| Old Growth | 7 × 10 | Minimal |

The script will reject any puzzle whose dimensions don't match its target tier, and suggest the right one if there's a mismatch.

## Authoring rules

The script enforces these — but it's faster to know them up front:

1. **Simply connected.** One connected blob of inside cells, with no outside cell trapped *inside* the inside blob. A trapped hole would create a second loop and the puzzle becomes invalid.
2. **Match the tier dimensions** exactly. 4×6 only goes into Sprout, 5×7 only into Mycelium, etc.
3. **No duplicates.** Two puzzles with the same `cols/rows/inside` set in the same tier get rejected. Order of cells doesn't matter — the comparison is normalized.
4. **Uniqueness of solution.** *Not* enforced by the script — that's on you. The engine guarantees the loop is valid; whether the *visible* clues uniquely determine that loop depends on which clues you reveal. For dense tiers showing all clues this is automatic; for sparse tiers you need to think about which clues to hide.

## The editor screen (debug only)

Only visible in `#if DEBUG` builds. Lives at `Views/Debug/PuzzleEditorView.swift`.

- **Tier shortcuts** (top row): tap to set both dimensions and clear the grid.
- **Cols / Rows steppers**: free-form sizes for tutorial sketches and experiments.
- **Inside cells / Hide clues** modes: drag in either mode. First cell tapped sets the direction (adding or removing); the rest of the drag follows.
- **Status line**: shows `Simply-connected · N inside · M loop edges` in green, or a warning in the warn color if there's an enclosed hole.
- **Copy Swift / Share**: clipboard + ShareLink. Copy also `print()`s to the Xcode console.
- **Clear**: wipes inside + hide. Doesn't reset dimensions.

## The script

`scripts/add-puzzle.swift` does the heavy lifting on the Mac side. Invocation:

```sh
swift scripts/add-puzzle.swift <tier>
```

It will:

1. Read your clipboard (must start with `Puzzle(`).
2. Parse out `cols`, `rows`, and `inside`.
3. Check the tier dimensions match.
4. Check the inside region is simply connected.
5. Check it's not already in that tier's array.
6. Insert the new puzzle into `Model/PuzzleData.swift` with a `// Grove #N` comment, fixing the previous puzzle's trailing comma if missing.
7. Print a one-line summary of what landed.

Any failure exits non-zero with an `error:` line. Nothing in the file changes if validation fails.

## When the script can't help

If you're authoring puzzles at sizes that *aren't* shipping tiers (tutorial lessons, one-off experiments), the script will refuse the dimensions. For those, paste the source into `PuzzleData.swift` by hand at the right spot — the tutorial `lessons` array is the main case.

## Files involved

- `Views/Debug/PuzzleEditorView.swift` — the in-app editor screen
- `scripts/add-puzzle.swift` — the Mac-side inserter
- `scripts/README.md` — this file
- `Model/PuzzleData.swift` — the destination
- `Model/Engine.swift` — the solution/clue derivation logic (only worth knowing about if you're changing how the engine works)
- `Model/Tier.swift` — the canonical dimensions per tier (keep in sync with `tierDims` in the script if you ever change them)
