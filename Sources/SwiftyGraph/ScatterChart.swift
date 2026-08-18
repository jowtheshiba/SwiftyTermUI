import Foundation
import SwiftyTermUI

/// A 2D scatter chart: points are plotted at their true (x, y) position
/// with Braille sub-cell resolution and are never connected by lines.
public struct ScatterChart {
    public var series: [ScatterSeries]
    public var title: String?
    public var showLegend: Bool

    public init(series: [ScatterSeries], title: String? = nil, showLegend: Bool = true) {
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

        let legendRow = bottom
        var plotBottom = showLegend ? bottom - 1 : bottom
        let xLabelRow = plotBottom
        plotBottom -= 1
        let axisRow = plotBottom
        plotBottom -= 1

        let plotTop = top
        let plotRows = plotBottom - plotTop + 1
        guard plotRows > 0 else { return }

        let allPoints = series.flatMap(\.points)
        guard let rawMinX = allPoints.map(\.x).min(), let rawMaxX = allPoints.map(\.x).max(),
              let rawMinY = allPoints.map(\.y).min(), let rawMaxY = allPoints.map(\.y).max()
        else { return }

        func padded(_ lo: Double, _ hi: Double) -> (Double, Double) {
            if lo == hi { return (lo - 1, hi + 1) }
            let pad = (hi - lo) * 0.08
            return (lo - pad, hi + pad)
        }
        let (minX, maxX) = padded(rawMinX, rawMaxX)
        let (minY, maxY) = padded(rawMinY, rawMaxY)
        let midY = (minY + maxY) / 2

        let maxYLabel = formatAxisValue(maxY)
        let midYLabel = formatAxisValue(midY)
        let minYLabel = formatAxisValue(minY)
        let yLabelWidth = max(maxYLabel.count, midYLabel.count, minYLabel.count)

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
        drawYLabel(maxYLabel, atRow: plotTop)
        drawYLabel(minYLabel, atRow: plotBottom)
        if plotRows >= 3 {
            drawYLabel(midYLabel, atRow: plotTop + plotRows / 2)
        }

        tui.addChar(row: axisRow, column: axisColumn, character: "└", foregroundColor: .brightBlack)
        for c in plotLeft..<(plotLeft + plotWidth) {
            tui.addChar(row: axisRow, column: c, character: "─", foregroundColor: .brightBlack)
        }

        let xMinLabel = formatAxisValue(minX)
        let xMaxLabel = formatAxisValue(maxX)
        tui.drawString(row: xLabelRow, column: plotLeft, text: xMinLabel, foregroundColor: .brightBlack)
        let xMaxColumn = max(plotLeft, plotLeft + plotWidth - xMaxLabel.count)
        tui.drawString(row: xLabelRow, column: xMaxColumn, text: xMaxLabel, foregroundColor: .brightBlack)

        var canvas = BrailleCanvas(cellWidth: plotWidth, cellHeight: plotRows)

        func mapX(_ x: Double) -> Int {
            let ratio = (x - minX) / (maxX - minX)
            return Int((ratio * Double(canvas.pixelWidth - 1)).rounded().clamped(to: 0...Double(canvas.pixelWidth - 1)))
        }

        func mapY(_ y: Double) -> Int {
            let ratio = (y - minY) / (maxY - minY)
            let value = Double(canvas.pixelHeight - 1) - ratio * Double(canvas.pixelHeight - 1)
            return Int(value.rounded().clamped(to: 0...Double(canvas.pixelHeight - 1)))
        }

        for s in series {
            for p in s.points {
                canvas.setPixel(x: mapX(p.x), y: mapY(p.y), color: s.color)
            }
        }

        canvas.render(in: tui, row: plotTop, column: plotLeft)

        if showLegend {
            var c = column
            for s in series {
                let entryWidth = 2 + s.name.count
                guard c + entryWidth <= column + width else { break }
                tui.addChar(row: legendRow, column: c, character: "●", foregroundColor: s.color)
                tui.drawString(row: legendRow, column: c + 2, text: s.name, foregroundColor: .brightBlack)
                c += entryWidth + 2
            }
        }
    }
}
