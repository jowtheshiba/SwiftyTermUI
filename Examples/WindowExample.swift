import Foundation
import SwiftyTermUI

@main
@MainActor
struct WindowExample {
    static func main() async throws {
        let tui = SwiftyTermUI.shared
        
        try tui.initialize()
        defer { tui.shutdown() }
        
        tui.hideCursor()
        tui.clear()
        
        let window1 = tui.createWindow(x: 5, y: 3, width: 30, height: 10, hasBorder: true, borderStyle: .single)
        window1.title = "Вікно 1"
        window1.hasFocus = true
        window1.addString(row: 1, column: 2, text: "Це перше вікно", attributes: [.bold], foregroundColor: .green)
        window1.addString(row: 3, column: 2, text: "З рамкою single", foregroundColor: .cyan)
        
        let window2 = tui.createWindow(x: 40, y: 5, width: 35, height: 12, hasBorder: true, borderStyle: .double)
        window2.title = "Вікно 2"
        window2.addString(row: 1, column: 2, text: "Друге вікно", attributes: [.bold], foregroundColor: .yellow)
        window2.addString(row: 3, column: 2, text: "З рамкою double", foregroundColor: .magenta)
        window2.addString(row: 5, column: 2, text: "Це вікно вище першого", foregroundColor: .brightWhite)
        
        let window3 = tui.createWindow(x: 20, y: 8, width: 25, height: 8, hasBorder: true, borderStyle: .rounded)
        window3.title = "Вікно 3"
        window3.addString(row: 1, column: 2, text: "Третє вікно", attributes: [.bold, .underline], foregroundColor: .brightBlue)
        window3.addString(row: 3, column: 2, text: "Перекриває інші", foregroundColor: .white)
        
        tui.addPanel(window1)
        tui.addPanel(window2)
        tui.addPanel(window3)
        
        try tui.refresh()
        
        try await Task.sleep(for: .seconds(3))
        
        tui.sendToBack(window3)
        try tui.refresh()
        
        try await Task.sleep(for: .seconds(2))
        
        tui.hideWindow(window2)
        try tui.refresh()
        
        try await Task.sleep(for: .seconds(2))
        
        tui.showCursor()
    }
}
