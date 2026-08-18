import Foundation
import SwiftyGraph
import SwiftyTermUI

@main
@MainActor
struct GraphDemo {
    struct Example {
        let name: String
        let render: @MainActor (SwiftyTermUI, Int, Int, Int, Int) -> Void
    }

    static func randomWalk(seed: Double, steps: Int) -> [Double] {
        var value = seed
        return (0..<steps).map { _ in
            value += Double.random(in: -3...3)
            return value
        }
    }

    static var examples: [Example] {
        [
            Example(name: "Sine & Cosine") { tui, row, column, width, height in
                let sine = (0..<40).map { sin(Double($0) * 0.3) * 10 + 15 }
                let cosine = (0..<40).map { cos(Double($0) * 0.3) * 8 + 15 }
                LineChart(
                    series: [
                        GraphSeries(name: "sin", values: sine, color: GraphPalette.color(at: 0)),
                        GraphSeries(name: "cos", values: cosine, color: GraphPalette.color(at: 1)),
                    ],
                    title: "Sine & Cosine"
                ).render(in: tui, row: row, column: column, width: width, height: height)
            },
            Example(name: "Weekly Usage") { tui, row, column, width, height in
                BarChart(
                    series: GraphSeries(name: "usage", values: [12, 27, 8, 34, 19, 41, 5], color: GraphPalette.color(at: 2)),
                    labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                    title: "Weekly Usage"
                ).render(in: tui, row: row, column: column, width: width, height: height)
            },
            Example(name: "Random Walk") { tui, row, column, width, height in
                LineChart(
                    series: [
                        GraphSeries(name: "asset A", values: randomWalk(seed: 50, steps: 50), color: GraphPalette.color(at: 3)),
                        GraphSeries(name: "asset B", values: randomWalk(seed: 50, steps: 50), color: GraphPalette.color(at: 4)),
                    ],
                    title: "Random Walk"
                ).render(in: tui, row: row, column: column, width: width, height: height)
            },
            Example(name: "Sales by Region") { tui, row, column, width, height in
                BarChart(
                    series: GraphSeries(name: "sales", values: [120, 95, 143, 61], color: GraphPalette.color(at: 5)),
                    labels: ["EU", "US", "APAC", "LATAM"],
                    title: "Sales by Region"
                ).render(in: tui, row: row, column: column, width: width, height: height)
            },
            Example(name: "Exponential Growth") { tui, row, column, width, height in
                let values = (0..<40).map { pow(1.12, Double($0)) }
                LineChart(
                    series: [GraphSeries(name: "growth", values: values, color: GraphPalette.color(at: 0))],
                    title: "Exponential Growth",
                    showLegend: false
                ).render(in: tui, row: row, column: column, width: width, height: height)
            },
            Example(name: "Scatter Clusters") { tui, row, column, width, height in
                func cluster(cx: Double, cy: Double, count: Int, spread: Double) -> [GraphPoint] {
                    (0..<count).map { _ in
                        let dx = (Double.random(in: -1...1) + Double.random(in: -1...1)) * spread
                        let dy = (Double.random(in: -1...1) + Double.random(in: -1...1)) * spread
                        return GraphPoint(x: cx + dx, y: cy + dy)
                    }
                }
                ScatterChart(
                    series: [
                        ScatterSeries(name: "group A", points: cluster(cx: 12, cy: 12, count: 35, spread: 4), color: GraphPalette.color(at: 0)),
                        ScatterSeries(name: "group B", points: cluster(cx: 30, cy: 25, count: 35, spread: 4), color: GraphPalette.color(at: 1)),
                    ],
                    title: "Scatter Clusters"
                ).render(in: tui, row: row, column: column, width: width, height: height)
            },
            Example(name: "Activity Heatmap") { tui, row, column, width, height in
                let rowLabels = ["00h", "06h", "12h", "18h"]
                let columnLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                let values = rowLabels.map { _ in columnLabels.map { _ in Double.random(in: 0...100) } }
                Heatmap(
                    values: values,
                    title: "Activity Heatmap",
                    rowLabels: rowLabels,
                    columnLabels: columnLabels
                ).render(in: tui, row: row, column: column, width: width, height: height)
            },
            Example(name: "Quarterly Revenue (3D)") { tui, row, column, width, height in
                Pseudo3DBarChart(
                    series: GraphSeries(name: "revenue", values: [82, 95, 110, 76], color: .rgb(22, 122, 63)),
                    labels: ["Q1", "Q2", "Q3", "Q4"],
                    title: "Quarterly Revenue"
                ).render(in: tui, row: row, column: column, width: width, height: height)
            },
        ]
    }

    static func main() async throws {
        let tui = SwiftyTermUI.shared

        try tui.initialize()
        defer { tui.shutdown() }

        tui.hideCursor()
        tui.clear()

        let (cols, rows) = tui.getTerminalSize()
        let examples = examples

        let menuX = 1
        let menuWidth = 30
        let dividerColumn = menuX + menuWidth + 1
        let chartColumn = dividerColumn + 2
        let chartRow = 1
        let chartWidth = cols - chartColumn - 1
        let chartHeight = rows - 3

        let menu = Menu(x: menuX, y: 1, width: menuWidth, items: examples.map(\.name))
        menu.title = "Examples"
        menu.selectedBackground = GraphPalette.color(at: 0)
        menu.selectedForeground = .black

        func drawSelectedChart() {
            tui.clearArea(row: chartRow, column: chartColumn, width: chartWidth, height: chartHeight)
            examples[menu.selectedIndex].render(tui, chartRow, chartColumn, chartWidth, chartHeight)
        }

        for r in 0..<(rows - 1) {
            tui.addChar(row: r, column: dividerColumn, character: "│", foregroundColor: .brightBlack)
        }

        menu.render(to: tui)
        drawSelectedChart()

        tui.drawString(row: rows - 1, column: 2, text: "↑/↓ select example   ESC exit", attributes: [.italic], foregroundColor: .brightBlack)

        try tui.refresh()

        var running = true
        while running {
            if let event = tui.readEvent() {
                if case .keyPress(let key) = event, key == .escape {
                    running = false
                    continue
                }
                if menu.handleInput(event) {
                    menu.render(to: tui)
                    drawSelectedChart()
                    try tui.refresh()
                }
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        tui.clear()
        tui.showCursor()
    }
}
