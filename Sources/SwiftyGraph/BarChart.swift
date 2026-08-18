import Foundation
import SwiftyTermUI

/// A vertical bar chart. Bar tops use eighth-block characters so heights
/// aren't limited to whole terminal rows, which keeps short bars visible
/// and tall ones proportionally accurate.
public struct BarChart {
    public var series: GraphSeries
    public var labels: [String]?
    public var title: String?
    public var showValues: Bool

    public init(series: GraphSeries, labels: [String]? = nil, title: String? = nil, showValues: Bool = true) {
        self.series = series
        self.labels = labels
        self.title = title
        self.showValues = showValues
    }

    @MainActor
    public func render(in tui: SwiftyTermUI, row: Int, column: Int, width: Int, height: Int) {
        guard width > 4, height > 3, !series.values.isEmpty else { return }

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

        let plotTop = top
        let plotBottom = baselineRow - 1
        let plotRows = plotBottom - plotTop + 1
        guard plotRows > 0 else { return }

        let count = series.values.count
        let slotWidth = max(1, width / count)
        let barWidth = max(1, slotWidth - 1)

        let rawMax = max(series.values.max() ?? 0, 0.0001)
        // Leave headroom above the tallest bar so its value label has a row to sit on.
        let maxValue = showValues ? rawMax * 1.15 : rawMax
        let eighthChars: [Character] = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

        for c in column..<(column + width) {
            tui.addChar(row: baselineRow, column: c, character: "─", foregroundColor: .brightBlack)
        }

        for (i, value) in series.values.enumerated() {
            let slotStart = column + i * slotWidth
            let barStart = slotStart + (slotWidth - barWidth) / 2

            let totalEighths = min(max(Int(((max(value, 0) / maxValue) * Double(plotRows * 8)).rounded()), 0), plotRows * 8)

            var topFilledRow: Int?
            for r in stride(from: plotBottom, through: plotTop, by: -1) {
                let rowIndexFromBottom = plotBottom - r
                let rowStart = rowIndexFromBottom * 8
                let filled = min(max(totalEighths - rowStart, 0), 8)
                guard filled > 0 else { break }
                let char = filled == 8 ? "█" : eighthChars[filled]
                for bc in barStart..<(barStart + barWidth) {
                    tui.addChar(row: r, column: bc, character: char, foregroundColor: series.color)
                }
                topFilledRow = r
            }

            if showValues, let topFilledRow, topFilledRow - 1 >= plotTop {
                let text = formatAxisValue(value)
                if text.count <= slotWidth {
                    let textColumn = slotStart + max(0, (slotWidth - text.count) / 2)
                    tui.drawString(row: topFilledRow - 1, column: textColumn, text: text, attributes: [.bold], foregroundColor: .brightWhite)
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
