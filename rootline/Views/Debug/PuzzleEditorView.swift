#if DEBUG
import SwiftUI
import UIKit
import ShroomKit

/// Dev-only puzzle authoring screen. Tap cells to mark them inside the loop;
/// the engine auto-derives the loop and clues on top. "Copy Swift" puts a
/// ready-to-paste `Puzzle(...)` declaration on your clipboard.
struct PuzzleEditorView: View {
    let onClose: () -> Void

    @Environment(\.palette) private var palette
    @State private var cols: Int = 4
    @State private var rows: Int = 6
    @State private var inside: Set<Cell> = []
    @State private var hide: Set<Cell> = []
    @State private var mode: EditorMode = .inside
    @State private var flashCopied: Bool = false

    enum EditorMode: String, CaseIterable, Identifiable {
        case inside
        case hide
        var id: String { rawValue }
        var label: String {
            switch self {
            case .inside: return "Inside cells"
            case .hide:   return "Hide clues"
            }
        }
    }

    private enum DragAction { case adding, removing }

    @State private var dragAction: DragAction? = nil
    @State private var dragVisited: Set<Cell> = []

    private static let editorSpace = "rootline.editor.grid"

    private var puzzle: Puzzle {
        Puzzle(
            cols: cols,
            rows: rows,
            inside: inside.map { [$0.c, $0.r] },
            hide: hide.map { [$0.c, $0.r] }
        )
    }

    private var model: PuzzleModel { PuzzleModel(puzzle) }

    var body: some View {
        VStack(spacing: 12) {
            header
            tierShortcuts
            sizeControls
            grid
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 8)
            statusLine
            modeToggle
            actions
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .background(palette.appBg.ignoresSafeArea())
    }

    // MARK: Tier shortcuts

    private var tierShortcuts: some View {
        HStack(spacing: 6) {
            ForEach(Tier.allCases) { tier in
                Button {
                    cols = tier.cols
                    rows = tier.rows
                    inside.removeAll()
                    hide.removeAll()
                } label: {
                    VStack(spacing: 2) {
                        Text(tier.label)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(palette.text)
                        Text(tier.shortMeta)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(palette.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(palette.tierBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(palette.tierBorder, lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.sub)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.pill)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text("DEBUG")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .tracking(1.3)
                    .foregroundStyle(palette.sub)
                Text("Puzzle editor")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.text)
            }
            Spacer()
            Button(action: clearAll) {
                Text("Clear")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.sub)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.pill)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Size controls

    private var sizeControls: some View {
        HStack(spacing: 12) {
            stepper(label: "Cols", value: $cols, range: 2...10)
            stepper(label: "Rows", value: $rows, range: 2...12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.pill)
        )
        .onChange(of: cols) { _, _ in pruneOutOfBounds() }
        .onChange(of: rows) { _, _ in pruneOutOfBounds() }
    }

    private func stepper(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(palette.sub)
            Stepper("\(value.wrappedValue)", value: value, in: range)
                .labelsHidden()
            Text("\(value.wrappedValue)")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.text)
                .monospacedDigit()
                .frame(minWidth: 18, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Grid

    private var grid: some View {
        GeometryReader { geo in
            let cell = min(
                geo.size.width / CGFloat(cols),
                geo.size.height / CGFloat(rows)
            )
            let totalW = cell * CGFloat(cols)
            let totalH = cell * CGFloat(rows)

            ZStack(alignment: .topLeading) {
                cellsLayer(cell: cell)
                Canvas { ctx, _ in
                    drawSolution(ctx: ctx, cell: cell)
                }
                .allowsHitTesting(false)
                .frame(width: totalW, height: totalH)
                cluesLayer(cell: cell)
            }
            .frame(width: totalW, height: totalH)
            .contentShape(Rectangle())
            .coordinateSpace(name: Self.editorSpace)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.editorSpace))
                    .onChanged { value in
                        applyDrag(at: value.location, cellSize: cell)
                    }
                    .onEnded { _ in
                        dragAction = nil
                        dragVisited.removeAll()
                    }
            )
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private func cellsLayer(cell: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<cols, id: \.self) { c in
                        cellVisual(at: Cell(c: c, r: r), size: cell)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func cellVisual(at cell: Cell, size: CGFloat) -> some View {
        let isInside = inside.contains(cell)
        let isHidden = hide.contains(cell)
        return ZStack {
            Rectangle()
                .fill(isInside ? palette.tierSelBg : palette.boardBg)
            Rectangle()
                .strokeBorder(palette.tierBorder.opacity(0.4), lineWidth: 0.5)
            if mode == .hide && isHidden {
                Rectangle()
                    .stroke(palette.sub.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .padding(4)
            }
        }
        .frame(width: size, height: size)
    }

    /// Map a drag point to a cell and paint the drag's chosen direction
    /// (adding or removing) into it, once per drag.
    private func applyDrag(at point: CGPoint, cellSize: CGFloat) {
        guard cellSize > 0 else { return }
        let c = Int(point.x / cellSize)
        let r = Int(point.y / cellSize)
        guard c >= 0, c < cols, r >= 0, r < rows else { return }
        let cell = Cell(c: c, r: r)
        guard !dragVisited.contains(cell) else { return }
        dragVisited.insert(cell)

        let currentSet = mode == .inside ? inside : hide
        if dragAction == nil {
            dragAction = currentSet.contains(cell) ? .removing : .adding
        }
        let adding = dragAction == .adding

        switch mode {
        case .inside:
            if adding { inside.insert(cell) } else { inside.remove(cell) }
        case .hide:
            if adding { hide.insert(cell) } else { hide.remove(cell) }
        }
    }

    private func cluesLayer(cell: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<rows, id: \.self) { r in
                ForEach(0..<cols, id: \.self) { c in
                    clueText(at: Cell(c: c, r: r), size: cell)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func clueText(at cell: Cell, size: CGFloat) -> some View {
        if let val = model.clues[cell], !hide.contains(cell) {
            Text("\(val)")
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.text)
                .frame(width: size, height: size)
                .offset(x: CGFloat(cell.c) * size, y: CGFloat(cell.r) * size)
        }
    }

    private func drawSolution(ctx: GraphicsContext, cell: CGFloat) {
        var path = Path()
        for e in model.solution {
            switch e {
            case .h(let r, let c):
                path.move(to: CGPoint(x: CGFloat(c) * cell, y: CGFloat(r) * cell))
                path.addLine(to: CGPoint(x: CGFloat(c + 1) * cell, y: CGFloat(r) * cell))
            case .v(let r, let c):
                path.move(to: CGPoint(x: CGFloat(c) * cell, y: CGFloat(r) * cell))
                path.addLine(to: CGPoint(x: CGFloat(c) * cell, y: CGFloat(r + 1) * cell))
            }
        }
        ctx.stroke(
            path,
            with: .color(palette.accent),
            style: StrokeStyle(lineWidth: cell * 0.11, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: Status

    private var simplyConnected: Bool {
        var outside: Set<Cell> = []
        for r in 0..<rows {
            for c in 0..<cols {
                let cell = Cell(c: c, r: r)
                if !inside.contains(cell) { outside.insert(cell) }
            }
        }
        if outside.isEmpty { return true }
        var visited: Set<Cell> = []
        var stack: [Cell] = []
        for cell in outside where cell.c == 0 || cell.r == 0 || cell.c == cols - 1 || cell.r == rows - 1 {
            if !visited.contains(cell) {
                visited.insert(cell)
                stack.append(cell)
            }
        }
        while let c = stack.popLast() {
            let neighbors = [
                Cell(c: c.c - 1, r: c.r),
                Cell(c: c.c + 1, r: c.r),
                Cell(c: c.c, r: c.r - 1),
                Cell(c: c.c, r: c.r + 1)
            ]
            for n in neighbors where outside.contains(n) && !visited.contains(n) {
                visited.insert(n)
                stack.append(n)
            }
        }
        return visited.count == outside.count
    }

    private var statusLine: some View {
        let valid = simplyConnected
        let count = inside.count
        return HStack(spacing: 8) {
            Image(systemName: valid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(valid ? palette.accent : palette.warn)
            Text(valid
                 ? "Simply-connected · \(count) inside · \(model.solution.count) loop edges"
                 : "Enclosed hole detected — shape is not simply connected")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(palette.sub)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.pill)
        )
    }

    // MARK: Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 6) {
            ForEach(EditorMode.allCases) { m in
                Button { mode = m } label: {
                    Text(m.label)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.vertical, 4)
                        .foregroundStyle(mode == m ? palette.accentText : palette.sub)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(mode == m ? palette.accent : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.pill)
        )
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: copyToClipboard) {
                HStack {
                    Image(systemName: flashCopied ? "checkmark" : "doc.on.clipboard")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(flashCopied ? "Copied!" : "Copy Swift")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(palette.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.accent)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: flashCopied)

            ShareLink(item: swiftSource()) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.text)
                    .frame(minWidth: 50, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.pill)
                    )
                    .contentShape(Rectangle())
            }
        }
    }

    // MARK: Behaviour

    private func clearAll() {
        inside.removeAll()
        hide.removeAll()
    }

    private func pruneOutOfBounds() {
        inside = inside.filter { $0.c < cols && $0.r < rows }
        hide = hide.filter { $0.c < cols && $0.r < rows }
    }

    private func copyToClipboard() {
        let src = swiftSource()
        UIPasteboard.general.string = src
        // Also dump to the Xcode console when tethered — handy when you're
        // authoring on the phone and the console window is open on your Mac.
        print("// Rootline puzzle —")
        print(src)
        flashCopied = true
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            flashCopied = false
        }
    }

    private func swiftSource() -> String {
        var s = "Puzzle(cols: \(cols), rows: \(rows), inside: [\n"
        s += formatRows(cells: inside)
        s += "\n]"
        if !hide.isEmpty {
            s += ", hide: [\n"
            s += formatRows(cells: hide)
            s += "\n]"
        }
        s += ")"
        return s
    }

    private func formatRows(cells: Set<Cell>) -> String {
        var byRow: [Int: [Cell]] = [:]
        for c in cells { byRow[c.r, default: []].append(c) }
        let lines = byRow.keys.sorted().map { r -> String in
            let row = byRow[r]!.sorted { $0.c < $1.c }
                .map { "[\($0.c),\($0.r)]" }
                .joined(separator: ",")
            return "    \(row)"
        }
        return lines.joined(separator: ",\n")
    }
}
#endif
