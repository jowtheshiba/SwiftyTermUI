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
        
        // Заголовок
        tui.drawCenteredString(row: 1, width: cols, text: "Демонстрація утиліт рисування", attributes: [.bold], foregroundColor: .brightYellow)
        
        // Малюємо заповнений прямокутник як фон
        tui.fillRect(row: 3, column: 5, width: 30, height: 10, character: "░", foregroundColor: .brightBlack)
        
        // Малюємо контур прямокутника
        tui.drawRect(row: 3, column: 5, width: 30, height: 10, character: "█", foregroundColor: .cyan)
        
        // Текст всередині
        tui.drawString(row: 5, column: 10, text: "fillRect + drawRect", attributes: [.bold], foregroundColor: .white)
        
        // Діагональна лінія
        tui.drawLine(fromRow: 3, fromColumn: 40, toRow: 12, toColumn: 70, character: "●", foregroundColor: .green)
        tui.drawString(row: 2, column: 42, text: "drawLine", foregroundColor: .green)
        
        // Горизонтальна лінія
        tui.drawLine(fromRow: 15, fromColumn: 5, toRow: 15, toColumn: 70, character: "═", foregroundColor: .magenta)
        
        // Вертикальна лінія
        tui.drawLine(fromRow: 17, fromColumn: 20, toRow: 25, toColumn: 20, character: "║", foregroundColor: .blue)
        
        // Центрований текст
        tui.drawCenteredString(row: 17, width: cols, text: "Центрований текст", attributes: [.bold, .underline], foregroundColor: .brightWhite)
        
        // Приклад TextUtils
        let longText = "Це дуже довгий текст який потрібно обрізати до певної ширини інакше він не вміститься"
        let truncated = TextUtils.truncate(longText, to: 40)
        tui.drawString(row: 19, column: 5, text: truncated, foregroundColor: .yellow)
        
        // Приклад обтікання тексту
        let wrappedLines = TextUtils.wrap("Текст який обтікає і розбивається на декілька рядків автоматично", width: 30)
        for (index, line) in wrappedLines.enumerated() {
            tui.drawString(row: 21 + index, column: 5, text: line, foregroundColor: .brightGreen)
        }
        
        // Кольори з HEX
        if let hexColor = Helpers.colorFromHex("#FF5500") {
            tui.fillRect(row: 3, column: 75, width: 10, height: 3, character: " ", backgroundColor: hexColor)
            tui.drawString(row: 4, column: 76, text: "#FF5500", attributes: [.bold], foregroundColor: .white, backgroundColor: hexColor)
        }
        
        // Інструкція
        tui.drawString(row: rows - 2, column: 2, text: "Натисніть ESC для виходу", attributes: [.italic], foregroundColor: .brightBlack)
        
        try tui.refresh()
        
        // Чекаємо на ESC
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
