import Foundation
import SwiftyTermUI

/// A 2D line chart rendered with Braille sub-cell resolution for smooth,
/// colorful curves. Supports several series drawn on a shared axis.
public struct LineChart {
    public var series: [GraphSeries]
    public var title: String?
    public var showLegend: Bool

    public init(series: [GraphSeries], title: String? = nil, showLegend: Bool = true) {
        self.series = series
        self.title = title
        self.showLegend = showLegend
    }

    @MainActor
    public func render(in tui: SwiftyTermUI, row: Int, column: Int, width: Int, height: Int) {
        guard width > 6, height > 4, !series.isEmpty else { return }

        var top = row
        let bottom = row + height - 1

        if let title {
            let clipped = title.count > width ? String(title.prefix(width)) : title
            let startColumn = column + max(0, (width - clipped.count) / 2)
            tui.drawString(row: top, column: startColumn, text: clipped, attributes: [.bold], foregroundColor: .brightWhite)
            top += 2
        }

        let showLegendRow = showLegend
        let legendRow = bottom
        var plotBottom = showLegendRow ? bottom - 1 : bottom
        let xLabelRow = plotBottom
        plotBottom -= 1
        let axisRow = plotBottom
        plotBottom -= 1

        let plotTop = top
        let plotRows = plotBottom - plotTop + 1
        guard plotRows > 0 else { return }

        let allValues = series.flatMap(\.values)
        guard let rawMin = allValues.min(), let rawMax = allValues.max() else { return }

        var minValue = rawMin
        var maxValue = rawMax
        if minValue == maxValue {
            minValue -= 1
            maxValue += 1
        } else {
            let padding = (maxValue - minValue) * 0.05
            minValue -= padding
            maxValue += padding
        }
        let midValue = (minValue + maxValue) / 2

        let maxLabel = formatAxisValue(maxValue)
        let midLabel = formatAxisValue(midValue)
        let minLabel = formatAxisValue(minValue)
        let yLabelWidth = max(maxLabel.count, midLabel.count, minLabel.count)

        let axisColumn = column + yLabelWidth + 1
        let plotLeft = axisColumn + 1
        let plotWidth = column + width - plotLeft
        guard plotWidth > 0 else { return }

        func drawYLabel(_ label: String, atRow labelRow: Int) {
            let startColumn = column + (yLabelWidth - label.count)
            tui.drawString(row: labelRow, column: startColumn, text: label, foregroundColor: .brightBlack)
        }

        for r in plotTop...plotBottom {
            tui.addChar(row: r, column: axisColumn, character: "│", foregroundColor: .brightBlack)
        }
        drawYLabel(maxLabel, atRow: plotTop)
        drawYLabel(minLabel, atRow: plotBottom)
        if plotRows >= 3 {
            drawYLabel(midLabel, atRow: plotTop + plotRows / 2)
        }

        tui.addChar(row: axisRow, column: axisColumn, character: "└", foregroundColor: .brightBlack)
        for c in plotLeft..<(plotLeft + plotWidth) {
            tui.addChar(row: axisRow, column: c, character: "─", foregroundColor: .brightBlack)
        }

        let maxCount = series.map(\.values.count).max() ?? 0
        if maxCount > 0 {
            let xMinLabel = "0"
            let xMaxLabel = "\(maxCount - 1)"
            tui.drawString(row: xLabelRow, column: plotLeft, text: xMinLabel, foregroundColor: .brightBlack)
            let xMaxColumn = max(plotLeft, plotLeft + plotWidth - xMaxLabel.count)
            tui.drawString(row: xLabelRow, column: xMaxColumn, text: xMaxLabel, foregroundColor: .brightBlack)
        }

        var canvas = BrailleCanvas(cellWidth: plotWidth, cellHeight: plotRows)

        func mapX(_ index: Int, count: Int) -> Int {
            guard count > 1 else { return canvas.pixelWidth - 1 }
            return Int((Double(index) / Double(count - 1) * Double(canvas.pixelWidth - 1)).rounded())
        }

        func mapY(_ value: Double) -> Int {
            let ratio = (value - minValue) / (maxValue - minValue)
            let y = Double(canvas.pixelHeight - 1) - ratio * Double(canvas.pixelHeight - 1)
            return Int(y.rounded().clamped(to: 0...Double(canvas.pixelHeight - 1)))
        }

        for s in series where !s.values.isEmpty {
            if s.values.count == 1 {
                canvas.setPixel(x: canvas.pixelWidth - 1, y: mapY(s.values[0]), color: s.color)
                continue
            }
            for i in 0..<(s.values.count - 1) {
                canvas.drawLine(
                    fromX: mapX(i, count: s.values.count), fromY: mapY(s.values[i]),
                    toX: mapX(i + 1, count: s.values.count), toY: mapY(s.values[i + 1]),
                    color: s.color
                )
            }
        }

        canvas.render(in: tui, row: plotTop, column: plotLeft)

        if showLegendRow {
            var c = column
            for s in series {
                let text = "\(s.name)"
                let entryWidth = 2 + text.count
                guard c + entryWidth <= column + width else { break }
                tui.addChar(row: legendRow, column: c, character: "●", foregroundColor: s.color)
                tui.drawString(row: legendRow, column: c + 2, text: text, foregroundColor: .brightBlack)
                c += entryWidth + 2
            }
        }
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
