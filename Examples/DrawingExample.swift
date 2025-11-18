import Foundation
import SwiftyTermUI

@main
@MainActor
struct DrawingExample {
    static func main() async throws {
        let tui = SwiftyTermUI.shared
        
        try tui.initialize()
        defer { tui.shutdown() }
        
        tui.hideCursor()
        tui.clear()
        
        let (cols, rows) = tui.getTerminalSize()
         
         // Title
         tui.drawCenteredString(row: 1, width: cols, text: "Drawing Utilities Demonstration", attributes: [.bold], foregroundColor: .brightYellow)
         
         // Draw filled rectangle as background
         tui.fillRect(row: 3, column: 5, width: 30, height: 10, character: "░", foregroundColor: .brightBlack)
         
         // Draw rectangle outline
         tui.drawRect(row: 3, column: 5, width: 30, height: 10, character: "█", foregroundColor: .cyan)
         
         // Text inside
         tui.drawString(row: 5, column: 10, text: "fillRect + drawRect", attributes: [.bold], foregroundColor: .white)
         
         // Diagonal line
         tui.drawLine(fromRow: 3, fromColumn: 40, toRow: 12, toColumn: 70, character: "●", foregroundColor: .green)
         tui.drawString(row: 2, column: 42, text: "drawLine", foregroundColor: .green)
         
         // Horizontal line
         tui.drawLine(fromRow: 15, fromColumn: 5, toRow: 15, toColumn: 70, character: "═", foregroundColor: .magenta)
         
         // Vertical line
         tui.drawLine(fromRow: 17, fromColumn: 20, toRow: 25, toColumn: 20, character: "║", foregroundColor: .blue)
         
         // Centered text
         tui.drawCenteredString(row: 17, width: cols, text: "Centered text", attributes: [.bold, .underline], foregroundColor: .brightWhite)
         
         // TextUtils example
         let longText = "This is a very long text that needs to be truncated to a certain width otherwise it won't fit"
         let truncated = TextUtils.truncate(longText, to: 40)
         tui.drawString(row: 19, column: 5, text: truncated, foregroundColor: .yellow)
         
         // Text wrapping example
         let wrappedLines = TextUtils.wrap("Text that wraps and breaks into multiple lines automatically", width: 30)
         for (index, line) in wrappedLines.enumerated() {
             tui.drawString(row: 21 + index, column: 5, text: line, foregroundColor: .brightGreen)
         }
         
         // Colors from HEX
         if let hexColor = Helpers.colorFromHex("#FF5500") {
             tui.fillRect(row: 3, column: 75, width: 10, height: 3, character: " ", backgroundColor: hexColor)
             tui.drawString(row: 4, column: 76, text: "#FF5500", attributes: [.bold], foregroundColor: .white, backgroundColor: hexColor)
         }
         
         // Instructions
         tui.drawString(row: rows - 2, column: 2, text: "Press ESC to exit", attributes: [.italic], foregroundColor: .brightBlack)
         
         try tui.refresh()
         
         // Wait for ESC
        var running = true
        while running {
            if let event = tui.readEvent() {
                if case .keyPress(let key) = event, key == .escape {
                    running = false
                }
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        
        tui.clear()
        tui.showCursor()
    }
}
