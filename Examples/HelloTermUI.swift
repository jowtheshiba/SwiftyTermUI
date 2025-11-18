import Foundation
import SwiftyTermUI

@main
@MainActor
struct HelloTermUIApp {
    static func main() async throws {
        let tui = SwiftyTermUI.shared

        try tui.initialize()
        defer { tui.shutdown() }

        let (cols, rows) = tui.getTerminalSize()

        tui.clear()

        tui.drawString(row: 2, column: 2, text: "Hello, SwiftyTermUI! 👋")
        tui.drawString(row: 4, column: 2, text: "Terminal size: \(cols) x \(rows)")

        tui.drawString(
            row: 6,
            column: 2,
            text: "Bold text",
            attributes: [.bold],
            foregroundColor: .red
        )

        tui.drawString(
            row: 7,
            column: 2,
            text: "Green background",
            foregroundColor: .black,
            backgroundColor: .green
        )

        tui.drawString(
            row: 9,
            column: 2,
            text: "Press any key to continue...",
            attributes: [.italic]
        )

        try tui.refresh()

        var inputDetected = false
        while !inputDetected {
            if let event = tui.readEvent() {
                switch event {
                case .keyPress:
                    inputDetected = true
                case .terminalResize:
                    break
                }
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
