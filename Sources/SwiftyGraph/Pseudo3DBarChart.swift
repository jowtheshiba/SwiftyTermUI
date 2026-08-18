import Foundation
import SwiftyTermUI

/// A bar chart drawn as filled isometric boxes: a flat front face, a lighter
/// sheared top cap, and a same-colored side face, echoing the classic
/// "3D column chart" look. Filled cells (not line junctions) carry the
/// depth cue, so it renders identically regardless of terminal font.
public struct Pseudo3DBarChart {
    public var series: GraphSeries
    public var labels: [String]?
    public var title: String?
    public var showValues: Bool
    /// How many rows/columns the top and side faces are sheared by. Larger
    /// values read as "deeper" 3D but need more headroom and horizontal room.
    public var depth: Int

    public init(series: GraphSeries, labels: [String]? = nil, title: String? = nil, showValues: Bool = true, depth: Int = 3) {
        self.series = series
        self.labels = labels
        self.title = title
        self.showValues = showValues
        self.depth = max(1, depth)
    }

    @MainActor
    public func render(in tui: SwiftyTermUI, row: Int, column: Int, width: Int, height: Int) {
        guard width > 6, height > depth + 4, !series.values.isEmpty else { return }

        var top = row
        if let title {
            let clipped = title.count > width ? String(title.prefix(width)) : title
            let startColumn = column + max(0, (width - clipped.count) / 2)
            tui.drawString(row: top, column: startColumn, text: clipped, attributes: [.bold], foregroundColor: .brightWhite)
            top += 2
        }

        let hasLabels = labels != nil
        let baselineRow = hasLabels ? row + height - 2 : row + height - 1
        let labelRow = row + height - 1

        // Headroom above the tallest bar for the sheared cap and its value label.
        let plotTop = top + depth + (showValues ? 1 : 0)
        let plotBottom = baselineRow - 1
        let plotRows = plotBottom - plotTop + 1
        guard plotRows > 0 else { return }

        let count = series.values.count
        let slotWidth = max(1, width / count)
        // Keep bars narrow and let the gap between slots carry the depth offset.
        let idealBarWidth = slotWidth - depth - 2
        let barWidth = max(3, min(idealBarWidth, 10))

        let maxValue = max(series.values.max() ?? 0, 0.0001)
        let capColor = shaded(series.color, by: 0.4)
        // A stronger factor than the cap's: on the 256-color ANSI palette a
        // small RGB change can round-trip to the exact same index as the
        // front color (the terminal only has 6 brightness steps per
        // channel), silently erasing the side/front contrast. -0.55 keeps
        // enough margin to reliably land in a different palette cell.
        let sideColor = shaded(series.color, by: -0.55)

        for c in column..<(column + width) {
            tui.addChar(row: baselineRow, column: c, character: "─", foregroundColor: .brightBlack)
        }

        for (i, value) in series.values.enumerated() {
            let slotStart = column + i * slotWidth
            let barStart = slotStart + max(0, (slotWidth - (barWidth + depth)) / 2)
            let barRight = barStart + barWidth - 1

            let barHeight = min(plotRows, max(value > 0 ? 1 : 0, Int(((max(value, 0) / maxValue) * Double(plotRows)).rounded())))
            guard barHeight > 0 else { continue }
            let barTop = plotBottom - barHeight + 1
            let backTopRow = barTop - depth

            // Front face: a plain filled rectangle.
            for r in barTop...plotBottom {
                for c in barStart...barRight {
                    tui.addChar(row: r, column: c, character: "█", foregroundColor: series.color)
                }
            }

            // Side face: a plain solid rectangle over its whole bounding box.
            // The cap is drawn on top of it next, so wherever the cap only
            // partially covers a cell over these columns, this solid color
            // shows through as that cell's background instead of a gap.
            for r in backTopRow...plotBottom {
                for c in (barRight + 1)...(barRight + depth) {
                    tui.addChar(row: r, column: c, character: "█", foregroundColor: sideColor)
                }
            }

            // Top cap: a parallelogram of constant width barWidth, sheared
            // right by one sub-column per sub-row as it rises toward the back
            // edge. Rasterized at 2x2 sub-cell resolution so the diagonal
            // edges aren't a hard one-cell staircase. Cells that fall over
            // the side face use it as their background (so the seam blends
            // instead of erasing whatever the side drew there); cells over
            // open space keep the default background.
            var capCanvas = QuadrantCanvas(cellWidth: barWidth + depth, cellHeight: depth)
            for sy in 0..<capCanvas.pixelHeight {
                let leftSubCol = capCanvas.pixelHeight - sy
                let rightSubCol = min(capCanvas.pixelWidth - 1, leftSubCol + barWidth * 2 - 1)
                guard leftSubCol <= rightSubCol else { continue }
                for sx in leftSubCol...rightSubCol {
                    capCanvas.setPixel(x: sx, y: sy)
                }
            }
            for cellY in 0..<capCanvas.cellHeight {
                for cellX in 0..<capCanvas.cellWidth {
                    let x0 = cellX * 2, x1 = cellX * 2 + 1
                    let y0 = cellY * 2, y1 = cellY * 2 + 1
                    let ul = capCanvas.isSet(x0, y0)
                    let ur = capCanvas.isSet(x1, y0)
                    let ll = capCanvas.isSet(x0, y1)
                    let lr = capCanvas.isSet(x1, y1)
                    guard let char = QuadrantCanvas.quadrantChar(ul, ur, ll, lr) else { continue }
                    let background: Color = cellX >= barWidth ? sideColor : .default
                    tui.addChar(row: backTopRow + cellY, column: barStart + cellX, character: char, foregroundColor: capColor, backgroundColor: background)
                }
            }

            // Round off the two outer bottom corners of the silhouette (front-
            // bottom-left, side-bottom-right) so the foot isn't a hard square.
            tui.addChar(row: plotBottom, column: barStart, character: "▜", foregroundColor: series.color)
            tui.addChar(row: plotBottom, column: barRight + depth, character: "▛", foregroundColor: sideColor)

            if showValues {
                let valueRow = backTopRow - 1
                let text = formatAxisValue(value)
                if valueRow >= top, text.count <= barWidth + depth {
                    let textColumn = barStart + max(0, (barWidth + depth - text.count) / 2)
                    tui.drawString(row: valueRow, column: textColumn, text: text, attributes: [.bold], foregroundColor: .brightWhite)
                }
            }

            if hasLabels, let labels, i < labels.count {
                let label = labels[i]
                let clipped = label.count > slotWidth ? String(label.prefix(slotWidth)) : label
                let textColumn = slotStart + max(0, (slotWidth - clipped.count) / 2)
                tui.drawString(row: labelRow, column: textColumn, text: clipped, foregroundColor: .brightBlack)
            }
        }
    }
}
