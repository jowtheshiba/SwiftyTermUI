import Foundation
import SwiftyTermUI

/// Demonstrates render optimization features:
/// - Escape sequence caching
/// - Command batching
/// - System call minimization
func main() {
    let ui = SwiftyTermUI.shared

    do {
        try ui.initialize()
        defer { ui.shutdown() }

        // Clear screen
        ui.clear()

        // Draw title
        let titleAttrs: TextAttributes = [.bold]
        ui.drawString(row: 0, column: 2, text: "Render Optimization Demo", attributes: titleAttrs, foregroundColor: .cyan)

        // Draw performance info section
        ui.drawString(row: 2, column: 2, text: "Optimizer Features:", attributes: [.underline], foregroundColor: .yellow)

        var row = 4
        ui.drawString(row: row, column: 4, text: "✓ Escape Sequence Caching", foregroundColor: .green)
        ui.drawString(row: row + 1, column: 6, text: "ANSI codes are cached to reduce string generation overhead", foregroundColor: .white)

        row += 3
        ui.drawString(row: row, column: 4, text: "✓ Command Batching", foregroundColor: .green)
        ui.drawString(row: row + 1, column: 6, text: "Commands are grouped into buffers (default 4KB) before rendering", foregroundColor: .white)

        row += 3
        ui.drawString(row: row, column: 4, text: "✓ System Call Minimization", foregroundColor: .green)
        ui.drawString(row: row + 1, column: 6, text: "Write buffer (8KB) reduces file write() system calls", foregroundColor: .white)

        // Draw separator line
        row += 3
        for col in 2..<(ui.columns - 2) {
            ui.addChar(row: row, column: col, character: "─", foregroundColor: .brightBlack)
        }

        // Render performance test
        row += 2
        ui.drawString(row: row, column: 2, text: "Performance Test:", attributes: [.underline], foregroundColor: .yellow)

        // Create a grid with many colored cells to test caching
        row += 2
        let testStartRow = row
        let testColors: [Color] = [.red, .green, .yellow, .blue, .magenta, .cyan]

        for y in 0..<6 {
            for x in 0..<20 {
                let color = testColors[(y * 20 + x) % testColors.count]
                ui.addChar(
                    row: testStartRow + y,
                    column: 4 + x,
                    character: "█",
                    foregroundColor: color
                )
            }
        }

        // Get and display stats
        try ui.refresh()

        let stats = ui.getRenderStatistics()
        let statsRow = testStartRow + 8

        ui.drawString(
            row: statsRow,
            column: 2,
            text: "Cache Statistics:",
            attributes: [.underline],
            foregroundColor: .yellow
        )

        ui.drawString(
            row: statsRow + 1,
            column: 4,
            text: "Cached Attributes: \(stats.cachedAttributes)",
            foregroundColor: .white
        )
        ui.drawString(
            row: statsRow + 2,
            column: 4,
            text: "Cached FG Colors: \(stats.cachedForegroundColors)",
            foregroundColor: .white
        )
        ui.drawString(
            row: statsRow + 3,
            column: 4,
            text: "Cached BG Colors: \(stats.cachedBackgroundColors)",
            foregroundColor: .white
        )
        ui.drawString(
            row: statsRow + 4,
            column: 4,
            text: "Dirty Regions: \(stats.dirtyRegionsTracked)",
            foregroundColor: .white
        )

        let infoRow = statsRow + 6
        ui.drawString(
            row: infoRow,
            column: 2,
            text: "Press any key to exit...",
            attributes: [.dim],
            foregroundColor: .white
        )

        try ui.refresh()

        // Wait for input
        while true {
            if let event = ui.readEvent() {
                if case .keyPress = event.type {
                    break
                }
            }
            usleep(50000) // Sleep 50ms to avoid busy loop
        }

    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

main()
