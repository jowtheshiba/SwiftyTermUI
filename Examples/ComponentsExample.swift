import Foundation
import SwiftyTermUI

@main
@MainActor
struct ComponentsExample {
    static func main() async throws {
        let tui = SwiftyTermUI.shared
        
        try tui.initialize()
        defer { tui.shutdown() }
        
        tui.hideCursor()
        tui.clear()
        
        // Заголовок
        let title = Label(x: 0, y: 1, text: "SwiftyTermUI Components Demo")
        title.attributes = [.bold, .underline]
        title.foregroundColor = .brightYellow
        title.width = tui.columns
        title.alignment = .center
        
        // Меню
        let menu = Menu(x: 5, y: 4, width: 30, items: ["Option 1", "Option 2", "Option 3", "Exit"])
        menu.title = "Main Menu"
        menu.hasBorder = true
        var selectedOption = ""
        
        menu.onSelect = { index, item in
            selectedOption = "Selected: \(item)"
        }
        
        // Label з результатом
        let resultLabel = Label(x: 40, y: 5, text: "")
        resultLabel.foregroundColor = .green
        
        // Кнопки
        let button1 = Button(x: 40, y: 8, text: "Press me")
        button1.isFocused = false
        button1.onPress = {
            selectedOption = "Button pressed!"
        }
        
        // ProgressBar
        let progressBar = ProgressBar(x: 40, y: 11, width: 30)
        progressBar.label = "Progress:"
        progressBar.style = .blocks
        var progress = 0.0
        
        // TextBox з логами
        let textBox = TextBox(x: 5, y: 13, width: 65, height: 8)
        textBox.title = "Event Log"
        textBox.appendLine("Application started")
        textBox.appendLine("Components initialized")
        
        var running = true
        var focusedComponent: String = "menu"
        
        while running {
            tui.clear()
            
            // Рендеринг
            title.render(to: tui)
            menu.render(to: tui)
            
            resultLabel.text = selectedOption
            resultLabel.render(to: tui)
            
            button1.render(to: tui)
            
            progressBar.setProgress(progress)
            progressBar.render(to: tui)
            
            textBox.render(to: tui)
            
            // Інструкції
            tui.drawString(row: tui.rows - 2, column: 2, text: "Tab - switch | Arrows - navigate | Enter - select | ESC - exit", foregroundColor: .brightBlack)
            
            try tui.refresh()
            
            // Обробка вводу
            if let event = tui.readEvent() {
                if case .keyPress(let key) = event {
                    switch key {
                    case .escape:
                        running = false
                        textBox.appendLine("Exiting...")
                        
                    case .tab:
                        focusedComponent = focusedComponent == "menu" ? "button" : "menu"
                        button1.isFocused = (focusedComponent == "button")
                        textBox.appendLine("Focus: \(focusedComponent)")
                        
                    default:
                        if focusedComponent == "menu" {
                            if menu.handleInput(event) {
                                if menu.items[menu.selectedIndex] == "Exit" {
                                    running = false
                                }
                                textBox.appendLine("Menu: \(selectedOption)")
                            }
                        } else if focusedComponent == "button" {
                            if button1.handleInput(event) {
                                textBox.appendLine(selectedOption)
                            }
                        }
                    }
                }
                
                // Анімація прогресбару
                progress += 0.01
                if progress > 1.0 {
                    progress = 0.0
                }
            }
            
            try await Task.sleep(for: .milliseconds(16))
        }
        
        tui.clear()
        tui.showCursor()
    }
}
