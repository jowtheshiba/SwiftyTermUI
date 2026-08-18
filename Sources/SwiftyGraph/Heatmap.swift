import Foundation
import SwiftyTermUI

/// A grid of values rendered as colored cells on a low-to-high color scale,
/// with an optional gradient legend and row/column labels.
public struct Heatmap {
    public var values: [[Double]]
    public var title: String?
    public var rowLabels: [String]?
    public var columnLabels: [String]?
    public var lowColor: Color
    public var highColor: Color
    public var cellWidth: Int

    public init(
        values: [[Double]],
        title: String? = nil,
        rowLabels: [String]? = nil,
        columnLabels: [String]? = nil,
        lowColor: Color = .rgb(35, 35, 80),
        highColor: Color = .rgb(255, 100, 60),
        cellWidth: Int = 3
    ) {
        self.values = values
        self.title = title
        self.rowLabels = rowLabels
        self.columnLabels = columnLabels
        self.lowColor = lowColor
        self.highColor = highColor
        self.cellWidth = max(cellWidth, 1)
    }

    @MainActor
    public func render(in tui: SwiftyTermUI, row: Int, column: Int, width: Int, height: Int) {
        guard width > 4, height > 3, !values.isEmpty,
              let columnCount = values.map(\.count).max(), columnCount > 0
        else { return }

        var top = row
        if let title {
            let clipped = title.count > width ? String(title.prefix(width)) : title
            let startColumn = column + max(0, (width - clipped.count) / 2)
            tui.drawString(row: top, column: startColumn, text: clipped, attributes: [.bold], foregroundColor: .brightWhite)
            top += 2
        }

        let allValues = values.flatMap { $0 }
        guard let minValue = allValues.min(), let maxValue = allValues.max() else { return }
        let range = maxValue - minValue

        func color(for value: Double) -> Color {
            let t = range == 0 ? 0.5 : (value - minValue) / range
            return interpolateColor(lowColor, highColor, t: t)
        }

        let hasColumnLabels = columnLabels != nil
        let legendRow = row + height - 1
        let columnLabelRow = legendRow - 1
        let gridBottomLimit = (hasColumnLabels ? columnLabelRow : legendRow) - 1

        let rowLabelWidth = rowLabels?.map(\.count).max() ?? 0
        let gridColumn = rowLabelWidth > 0 ? column + rowLabelWidth + 1 : column
        // One blank column between cells so adjacent swatches and labels stay legible.
        let columnStride = cellWidth + 1

        let gridRows = min(values.count, gridBottomLimit - top + 1)
        guard gridRows > 0 else { return }

        for r in 0..<gridRows {
            let rowValues = values[r]
            if let rowLabels, r < rowLabels.count, rowLabelWidth > 0 {
                let label = rowLabels[r]
                let startColumn = column + (rowLabelWidth - label.count)
                tui.drawString(row: top + r, column: startColumn, text: label, foregroundColor: .brightBlack)
            }
            for c in 0..<min(rowValues.count, columnCount) {
                let cellColumn = gridColumn + c * columnStride
                guard cellColumn + cellWidth <= column + width else { break }
                let cellColor = color(for: rowValues[c])
                for cx in 0..<cellWidth {
                    tui.addChar(row: top + r, column: cellColumn + cx, character: " ", backgroundColor: cellColor)
                }
            }
        }

        if hasColumnLabels, let columnLabels {
            for c in 0..<min(columnLabels.count, columnCount) {
                let cellColumn = gridColumn + c * columnStride
                guard cellColumn + cellWidth <= column + width else { break }
                let label = columnLabels[c]
                let clipped = label.count > cellWidth ? String(label.prefix(cellWidth)) : label
                let startColumn = cellColumn + max(0, (cellWidth - clipped.count) / 2)
                tui.drawString(row: columnLabelRow, column: startColumn, text: clipped, foregroundColor: .brightBlack)
            }
        }

        let minLabel = formatAxisValue(minValue)
        let maxLabel = formatAxisValue(maxValue)
        let legendWidth = min(20, column + width - (gridColumn + minLabel.count + maxLabel.count + 2))
        if legendWidth > 4 {
            tui.drawString(row: legendRow, column: gridColumn, text: minLabel, foregroundColor: .brightBlack)
            let barStart = gridColumn + minLabel.count + 1
            for i in 0..<legendWidth {
                let t = Double(i) / Double(max(legendWidth - 1, 1))
                tui.addChar(row: legendRow, column: barStart + i, character: " ", backgroundColor: interpolateColor(lowColor, highColor, t: t))
            }
            tui.drawString(row: legendRow, column: barStart + legendWidth + 1, text: maxLabel, foregroundColor: .brightBlack)
        }
    }
}
