import Foundation
import SwiftyTermUI

@main
@MainActor
struct InputExample {
    static func main() async throws {
        let tui = SwiftyTermUI.shared
        
        try tui.initialize()
        defer { tui.shutdown() }
        
        tui.hideCursor()
        tui.clear()
        
        tui.drawString(row: 1, column: 2, text: "Keyboard Input Demonstration", attributes: [.bold], foregroundColor: .brightYellow)
        tui.drawString(row: 2, column: 2, text: "Press any key (ESC to exit)", foregroundColor: .cyan)
        tui.drawString(row: 4, column: 2, text: "Last pressed key:", attributes: [.bold])
        
        try tui.refresh()
        
        var running = true
        var lastKey = ""
        var row = 6
        
        while running {
            if let event = tui.readEvent() {
                switch event {
                case .keyPress(let key):
                    var keyDescription = ""
                    
                    switch key {
                    case .character(let char):
                        keyDescription = "Character: '\(char)'"
                    case .enter:
                        keyDescription = "Enter"
                    case .escape:
                        keyDescription = "Escape (exit)"
                        running = false
                    case .tab:
                        keyDescription = "Tab"
                    case .backspace:
                        keyDescription = "Backspace"
                    case .delete:
                        keyDescription = "Delete"
                    case .insert:
                        keyDescription = "Insert"
                    case .home:
                        keyDescription = "Home"
                    case .end:
                        keyDescription = "End"
                    case .pageUp:
                        keyDescription = "Page Up"
                    case .pageDown:
                        keyDescription = "Page Down"
                    case .up:
                        keyDescription = "Arrow up ↑"
                    case .down:
                        keyDescription = "Arrow down ↓"
                    case .left:
                        keyDescription = "Arrow left ←"
                    case .right:
                        keyDescription = "Arrow right →"
                    case .f1:
                        keyDescription = "F1"
                    case .f2:
                        keyDescription = "F2"
                    case .f3:
                        keyDescription = "F3"
                    case .f4:
                        keyDescription = "F4"
                    case .f5:
                        keyDescription = "F5"
                    case .f6:
                        keyDescription = "F6"
                    case .f7:
                        keyDescription = "F7"
                    case .f8:
                        keyDescription = "F8"
                    case .f9:
                        keyDescription = "F9"
                    case .f10:
                        keyDescription = "F10"
                    case .f11:
                        keyDescription = "F11"
                    case .f12:
                        keyDescription = "F12"
                    case .ctrl(let char):
                        keyDescription = "Ctrl+\(char)"
                    case .alt(let char):
                        keyDescription = "Alt+\(char)"
                    case .unknown:
                        keyDescription = "Unknown key"
                    }
                    
                    if keyDescription != lastKey {
                        lastKey = keyDescription
                        
                        tui.clearArea(row: 6, column: 2, width: 80, height: 20)
                        
                        tui.drawString(row: row, column: 2, text: "→ \(keyDescription)", foregroundColor: .green)
                        row += 1
                        
                        if row > 20 {
                            row = 6
                        }
                        
                        try tui.refresh()
                    }
                    
                case .mouse:
                    break
                    
                case .terminalResize:
                    tui.clear()
                    tui.drawString(row: 1, column: 2, text: "Terminal resized!", attributes: [.bold], foregroundColor: .brightRed)
                    try tui.refresh()
                }
            }
            
            try await Task.sleep(for: .milliseconds(10))
        }
        
        tui.clear()
        tui.showCursor()
    }
}
