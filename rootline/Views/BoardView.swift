import SwiftUI
import ShroomKit

/// The board: dot lattice + ghost slots + threads + clue digits + X marks.
/// Tap maps to the nearest edge within the hit threshold.
struct BoardView: View {
    @Bindable var board: Board
    let interactive: Bool

    @Environment(\.palette) private var palette

    private var cols: Int { board.puzzle.cols }
    private var rows: Int { board.puzzle.rows }

    init(board: Board, interactive: Bool = true) {
        self.board = board
        self.interactive = interactive
    }

    var body: some View {
        GeometryReader { geo in
            let layout = BoardLayout(
                availableWidth: geo.size.width,
                availableHeight: geo.size.height,
                cols: cols,
                rows: rows
            )
            board(layout: layout)
                .frame(width: layout.boardWidth, height: layout.boardHeight)
                .contentShape(Rectangle())
                .coordinateSpace(name: Self.boardSpace)
                .gesture(tapGesture(layout: layout))
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private static let boardSpace = "rootline.board"

    @ViewBuilder
    private func board(layout: BoardLayout) -> some View {
        ZStack {
            // Ghost slots — dotted lines for every un-touched edge.
            Canvas { ctx, _ in
                drawGhosts(ctx: ctx, layout: layout)
            }

            // Threads layer with optional glow.
            Canvas { ctx, _ in
                drawThreads(ctx: ctx, layout: layout)
            }
            .modifier(GlowModifier(
                color: palette.accent,
                enabled: true,
                pulsing: board.isSolved
            ))

            // Dead-root X marks.
            Canvas { ctx, _ in
                drawXMarks(ctx: ctx, layout: layout)
            }

            // Dots + junction nodes.
            Canvas { ctx, _ in
                drawDots(ctx: ctx, layout: layout)
            }

            // Clue digits — Text views (not Canvas) so we get proper text rendering
            // with the halo. Halo is achieved with a stacked shadow stroke.
            ForEach(0..<rows, id: \.self) { r in
                ForEach(0..<cols, id: \.self) { c in
                    clueText(c: c, r: r, layout: layout)
                }
            }
        }
        .animation(.easeInOut(duration: 0.16), value: board.activeEdges)
        .animation(.easeInOut(duration: 0.16), value: board.xEdges)
        .animation(.easeInOut(duration: 0.16), value: board.isSolved)
    }

    @ViewBuilder
    private func clueText(c: Int, r: Int, layout: BoardLayout) -> some View {
        let cell = Cell(c: c, r: r)
        if let val = board.model.clues[cell], !board.puzzle.hideClues.contains(cell) {
            let count = board.model.count(cell: cell, in: board.activeEdges)
            let (color, opacity): (Color, Double) = {
                if count == val { return (palette.accent, 0.72) }
                if count > val { return (palette.warn, 1.0) }
                return (palette.text, 1.0)
            }()
            let origin = layout.dot(c: c, r: r)
            ZStack {
                // Halo: same digit, in board color, drawn slightly behind.
                Text("\(val)")
                    .font(.system(size: layout.cell * 0.36, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.boardBg)
                    .shadow(color: palette.boardBg, radius: 0, x: 1, y: 0)
                    .shadow(color: palette.boardBg, radius: 0, x: -1, y: 0)
                    .shadow(color: palette.boardBg, radius: 0, x: 0, y: 1)
                    .shadow(color: palette.boardBg, radius: 0, x: 0, y: -1)
                    .shadow(color: palette.boardBg, radius: 2)
                Text("\(val)")
                    .font(.system(size: layout.cell * 0.36, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(opacity))
            }
            .allowsHitTesting(false)
            .position(
                x: origin.x + layout.cell / 2,
                y: origin.y + layout.cell / 2
            )
            .animation(.easeInOut(duration: 0.15), value: count)
        }
    }

    // MARK: Drawing helpers

    private func drawGhosts(ctx: GraphicsContext, layout: BoardLayout) {
        let ghostColor = palette.sub.opacity(0.15)
        var path = Path()
        // Horizontal slots.
        for r in 0...rows {
            for c in 0..<cols {
                let e = Edge.h(r: r, c: c)
                if board.activeEdges.contains(e) || board.xEdges.contains(e) { continue }
                let a = layout.dot(c: c, r: r)
                let b = layout.dot(c: c + 1, r: r)
                path.move(to: a)
                path.addLine(to: b)
            }
        }
        // Vertical slots.
        for r in 0..<rows {
            for c in 0...cols {
                let e = Edge.v(r: r, c: c)
                if board.activeEdges.contains(e) || board.xEdges.contains(e) { continue }
                let a = layout.dot(c: c, r: r)
                let b = layout.dot(c: c, r: r + 1)
                path.move(to: a)
                path.addLine(to: b)
            }
        }
        ctx.stroke(
            path,
            with: .color(ghostColor),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 6])
        )
    }

    private func drawThreads(ctx: GraphicsContext, layout: BoardLayout) {
        let stroke = layout.cell * 0.13
        var path = Path()
        for e in board.activeEdges {
            switch e {
            case .h(let r, let c):
                path.move(to: layout.dot(c: c, r: r))
                path.addLine(to: layout.dot(c: c + 1, r: r))
            case .v(let r, let c):
                path.move(to: layout.dot(c: c, r: r))
                path.addLine(to: layout.dot(c: c, r: r + 1))
            }
        }
        ctx.stroke(
            path,
            with: .color(palette.accent),
            style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawXMarks(ctx: GraphicsContext, layout: BoardLayout) {
        let size = layout.cell * 0.13
        var path = Path()
        for e in board.xEdges {
            let m: CGPoint
            switch e {
            case .h(let r, let c):
                m = CGPoint(
                    x: layout.pad + (CGFloat(c) + 0.5) * layout.cell,
                    y: layout.pad + CGFloat(r) * layout.cell
                )
            case .v(let r, let c):
                m = CGPoint(
                    x: layout.pad + CGFloat(c) * layout.cell,
                    y: layout.pad + (CGFloat(r) + 0.5) * layout.cell
                )
            }
            path.move(to: CGPoint(x: m.x - size, y: m.y - size))
            path.addLine(to: CGPoint(x: m.x + size, y: m.y + size))
            path.move(to: CGPoint(x: m.x - size, y: m.y + size))
            path.addLine(to: CGPoint(x: m.x + size, y: m.y - size))
        }
        ctx.stroke(
            path,
            with: .color(palette.sub.opacity(0.7)),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
        )
    }

    private func drawDots(ctx: GraphicsContext, layout: BoardLayout) {
        // Degree per dot.
        var degree: [Dot: Int] = [:]
        for e in board.activeEdges {
            let (a, b) = e.endpoints
            degree[a, default: 0] += 1
            degree[b, default: 0] += 1
        }
        let onR = layout.cell * 0.07
        let offR = layout.cell * 0.05
        for r in 0...rows {
            for c in 0...cols {
                let p = layout.dot(c: c, r: r)
                let lit = (degree[Dot(c: c, r: r)] ?? 0) > 0
                if lit {
                    let rect = CGRect(x: p.x - onR, y: p.y - onR, width: onR * 2, height: onR * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(palette.accent))
                } else {
                    let rect = CGRect(x: p.x - offR, y: p.y - offR, width: offR * 2, height: offR * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(palette.sub.opacity(0.32)))
                }
            }
        }
    }

    // MARK: Tap handling

    private func tapGesture(layout: BoardLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.boardSpace))
            .onEnded { value in
                guard interactive else { return }
                if let edge = nearestEdge(at: value.location, layout: layout) {
                    board.toggle(edge)
                }
            }
    }

    /// Find the edge whose midpoint is closest to the tap, within hit radius.
    private func nearestEdge(at point: CGPoint, layout: BoardLayout) -> Edge? {
        // Tap location is in the inner ZStack coordinate space (board frame).
        // Iterate edges, compute perpendicular distance to the segment; require
        // along-segment projection within bounds. Cap at `0.46 * cell / 2`.
        let maxDist = layout.cell * 0.46 / 2
        var best: (edge: Edge, dist: CGFloat)? = nil

        func consider(edge: Edge, a: CGPoint, b: CGPoint) {
            let d = pointToSegmentDistance(point: point, a: a, b: b)
            if d <= maxDist, best == nil || d < best!.dist {
                best = (edge, d)
            }
        }

        for r in 0...rows {
            for c in 0..<cols {
                consider(
                    edge: .h(r: r, c: c),
                    a: layout.dot(c: c, r: r),
                    b: layout.dot(c: c + 1, r: r)
                )
            }
        }
        for r in 0..<rows {
            for c in 0...cols {
                consider(
                    edge: .v(r: r, c: c),
                    a: layout.dot(c: c, r: r),
                    b: layout.dot(c: c, r: r + 1)
                )
            }
        }
        return best?.edge
    }

    private func pointToSegmentDistance(point p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let apx = p.x - a.x
        let apy = p.y - a.y
        let lenSq = abx * abx + aby * aby
        guard lenSq > 0 else {
            return hypot(p.x - a.x, p.y - a.y)
        }
        var t = (apx * abx + apy * aby) / lenSq
        t = max(0, min(1, t))
        let cx = a.x + t * abx
        let cy = a.y + t * aby
        return hypot(p.x - cx, p.y - cy)
    }
}

// MARK: - Layout

struct BoardLayout {
    let cell: CGFloat
    let pad: CGFloat
    let boardWidth: CGFloat
    let boardHeight: CGFloat

    init(availableWidth: CGFloat, availableHeight: CGFloat, cols: Int, rows: Int) {
        // cell = availableWidth / (cols + 1.24) per the spec ("fill the width").
        // But also clamp so the board fits vertically.
        let widthCell = availableWidth / (CGFloat(cols) + 1.24)
        let heightCell = availableHeight / (CGFloat(rows) + 1.24)
        let cell = max(8, min(widthCell, heightCell))
        self.cell = cell
        self.pad = cell * 0.62
        self.boardWidth = CGFloat(cols) * cell + 2 * pad
        self.boardHeight = CGFloat(rows) * cell + 2 * pad
    }

    func dot(c: Int, r: Int) -> CGPoint {
        CGPoint(x: pad + CGFloat(c) * cell, y: pad + CGFloat(r) * cell)
    }
}

// MARK: - Glow modifier

private struct GlowModifier: ViewModifier {
    let color: Color
    let enabled: Bool
    let pulsing: Bool

    @State private var pulse = false

    func body(content: Content) -> some View {
        if enabled {
            content
                .shadow(color: color.opacity(pulsing && pulse ? 0.5 : 1.0), radius: pulsing ? 6 : 4)
                .shadow(color: color.opacity(pulsing && pulse ? 0.5 : 1.0), radius: pulsing ? 13 : 9)
                .onAppear {
                    if pulsing {
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
                }
                .onChange(of: pulsing) { _, newValue in
                    if newValue {
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    } else {
                        pulse = false
                    }
                }
        } else {
            content
        }
    }
}
