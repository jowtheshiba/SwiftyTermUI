import Foundation
import RetroVision
import SwiftyTermUI

@main
struct RetroDemo {
    static func main() {
        let app = TApplication.shared
        
        // Create Menu Bar
        let fileMenu = TMenu(title: "File", items: [
            TMenuItem(title: "New", action: {}, shortcut: "F4"),
            TMenuItem(title: "Open...", action: {}, shortcut: "F3"),
            TMenuItem(title: "Save", action: {}, shortcut: "F2"),
            TMenuItem.separator,
            TMenuItem(title: "Exit", action: { 
                exit(0)
            }, shortcut: "Alt+X")
        ])
        
        let editMenu = TMenu(title: "Edit", items: [
            TMenuItem(title: "Undo", action: {}, shortcut: "Alt+BkSp"),
            TMenuItem(title: "Redo", action: {}),
            TMenuItem.separator,
            TMenuItem(title: "Cut", action: {}, shortcut: "Shift+Del"),
            TMenuItem(title: "Copy", action: {}, shortcut: "Ctrl+Ins"),
            TMenuItem(title: "Paste", action: {}, shortcut: "Shift+Ins"),
            TMenuItem.separator,
            TMenuItem(title: "Clear", action: {})
        ])
        
        let arrangeSubmenu = [
            TMenuItem(title: "Tile", action: {}),
            TMenuItem(title: "Cascade", action: {})
        ]
        
        let windowMenu = TMenu(title: "Window", items: [
            TMenuItem(title: "Size/Move", action: {}, shortcut: "Ctrl+F5"),
            TMenuItem(title: "Zoom", action: {}, shortcut: "F5"),
            TMenuItem(title: "Arrange", submenu: arrangeSubmenu),
            TMenuItem.separator,
            TMenuItem(title: "Next", action: {}, shortcut: "F6"),
            TMenuItem(title: "Previous", action: {}, shortcut: "Shift+F6"),
            TMenuItem(title: "Close", action: {}, shortcut: "Alt+F3")
        ])
        
        let (cols, rows) = SwiftyTermUI.shared.getTerminalSize()
        let menuBar = TMenuBar(frame: Rect(x: 0, y: 0, width: cols, height: 1), menus: [fileMenu, editMenu, windowMenu])
        app.menuBar = menuBar
        
        // Create Edit Window (Blue)
        let editorText = """
        RetroVision editor demo
        This is a multi-line text buffer.
        You can edit text, move the cursor,
        and scroll both horizontally and vertically.
        
        Line 6: The quick brown fox jumps over the lazy dog.
        Line 7: 0123456789 0123456789 0123456789 0123456789
        Line 8: A very long line to force horizontal scrolling:
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        """
        let editWindow = TEditWindow(frame: Rect(x: 5, y: 3, width: 50, height: 15), title: "Edit Window", text: editorText)
        
        // Create Controls Window (Grey)
        let controlsWindow = TDialog(frame: Rect(x: 7, y: 6, width: 50, height: 16), title: "Controls")
        
        // Examples: Static text + checkbox
        let editorHelpText = TStaticText(
            frame: Rect(x: 2, y: 2, width: 30, height: 2),
            text: "RetroVision examples\n(static text)"
        )
        let editorCheckBox = TCheckBox(frame: Rect(x: 2, y: 5, width: 25, height: 1), title: "Auto-indent", isChecked: true)
        
        let editorList = TListBox(
            frame: Rect(x: 2, y: 7, width: 18, height: 4),
            items: ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6"]
        )
        let editorScroll = TScrollBar(frame: Rect(x: 20, y: 7, width: 1, height: 4))
        editorList.scrollBar = editorScroll
        
        controlsWindow.addSubview(editorHelpText)
        controlsWindow.addSubview(editorCheckBox)
        controlsWindow.addSubview(editorList)
        controlsWindow.addSubview(editorScroll)
        
        // Examples: Radio group
        let radioLight = TRadioBox(frame: Rect(x: 30, y: 4, width: 18, height: 1), title: "Light", groupID: "theme", isSelected: true)
        let radioDark = TRadioBox(frame: Rect(x: 30, y: 5, width: 18, height: 1), title: "Dark", groupID: "theme", isSelected: false)
        let radioAuto = TRadioBox(frame: Rect(x: 30, y: 6, width: 18, height: 1), title: "Auto", groupID: "theme", isSelected: false)
        controlsWindow.addSubview(radioLight)
        controlsWindow.addSubview(radioDark)
        controlsWindow.addSubview(radioAuto)
        
        // Add buttons to controls window
        let okButton = TButton(frame: Rect(x: 12, y: 12, width: 12, height: 1), title: "OK") {
        }
        okButton.isFocused = true
        
        let cancelButton = TButton(frame: Rect(x: 29, y: 12, width: 12, height: 1), title: "Cancel") {
        }
        
        controlsWindow.addSubview(okButton)
        controlsWindow.addSubview(cancelButton)
        app.desktop.addSubview(editWindow)
        app.desktop.addSubview(controlsWindow)
        
        // Create Dialog Window (Grey)
        let dialogWindow = TDialog(frame: Rect(x: 20, y: 8, width: 40, height: 12), title: "Find Dialog")
        
        // Examples: Label + checkbox
        let matchCaseBox = TCheckBox(frame: Rect(x: 3, y: 3, width: 30, height: 1), title: "Match case", isChecked: false)
        let matchCaseLabel = TLabel(frame: Rect(x: 3, y: 2, width: 30, height: 1), text: "~Match case:", target: matchCaseBox)
        let findLabel = TLabel(frame: Rect(x: 3, y: 5, width: 8, height: 1), text: "~Find:", target: nil)
        let findInput = TInputLine(frame: Rect(x: 10, y: 5, width: 24, height: 1))
        findLabel.target = findInput
        dialogWindow.addSubview(matchCaseLabel)
        dialogWindow.addSubview(matchCaseBox)
        dialogWindow.addSubview(findLabel)
        dialogWindow.addSubview(findInput)
        
        // Add buttons to dialog
        let findButton = TButton(frame: Rect(x: 5, y: 8, width: 12, height: 1), title: "Find") {
        }
        
        let replaceButton = TButton(frame: Rect(x: 20, y: 8, width: 15, height: 1), title: "Replace") {
        }
        
        dialogWindow.addSubview(findButton)
        dialogWindow.addSubview(replaceButton)
        app.desktop.addSubview(dialogWindow)
        
        // Create Tab Demo Window (Grey)
        let tabDemoWindow = TDialog(frame: Rect(x: 25, y: 2, width: 46, height: 17), title: "Tab Demo")
        
        let tabControl = TTabControl(frame: Rect(x: 1, y: 2, width: 44, height: 13))
        
        // Tab 1: General settings
        let generalTab = TTab(title: "General")
        let settingsLabel = TStaticText(
            frame: Rect(x: 2, y: 1, width: 30, height: 1),
            text: "Editor settings:"
        )
        let autoSaveCheck = TCheckBox(frame: Rect(x: 2, y: 3, width: 30, height: 1), title: "Auto-save", isChecked: true)
        let lineNumCheck = TCheckBox(frame: Rect(x: 2, y: 4, width: 30, height: 1), title: "Show line numbers")
        let wordWrapCheck = TCheckBox(frame: Rect(x: 2, y: 5, width: 30, height: 1), title: "Word wrap", isChecked: true)
        let tabSizeCheck = TCheckBox(frame: Rect(x: 2, y: 6, width: 30, height: 1), title: "Use tabs (not spaces)")
        generalTab.addSubview(settingsLabel)
        generalTab.addSubview(autoSaveCheck)
        generalTab.addSubview(lineNumCheck)
        generalTab.addSubview(wordWrapCheck)
        generalTab.addSubview(tabSizeCheck)
        
        // Tab 2: Theme settings
        let themeTab = TTab(title: "Colors")
        let themeLabel = TStaticText(
            frame: Rect(x: 2, y: 1, width: 20, height: 1),
            text: "Select theme:"
        )
        let lightRadio2 = TRadioBox(frame: Rect(x: 2, y: 3, width: 22, height: 1), title: "Light", groupID: "tabtheme", isSelected: true)
        let darkRadio2 = TRadioBox(frame: Rect(x: 2, y: 4, width: 22, height: 1), title: "Dark", groupID: "tabtheme")
        let solarizedRadio = TRadioBox(frame: Rect(x: 2, y: 5, width: 22, height: 1), title: "Solarized", groupID: "tabtheme")
        let monoRadio = TRadioBox(frame: Rect(x: 2, y: 6, width: 22, height: 1), title: "Monochrome", groupID: "tabtheme")
        themeTab.addSubview(themeLabel)
        themeTab.addSubview(lightRadio2)
        themeTab.addSubview(darkRadio2)
        themeTab.addSubview(solarizedRadio)
        themeTab.addSubview(monoRadio)
        
        // Tab 3: About
        let aboutTab = TTab(title: "About")
        let aboutText = TStaticText(
            frame: Rect(x: 2, y: 1, width: 38, height: 5),
            text: "RetroVision TUI Framework\nVersion 1.0\n\nA classic Turbo Vision-style\ntext user interface for Swift."
        )
        let aboutButton = TButton(frame: Rect(x: 14, y: 7, width: 14, height: 1), title: "OK") {
        }
        aboutTab.addSubview(aboutText)
        aboutTab.addSubview(aboutButton)
        
        // Tab 4: Progress
        let progressTab = TTab(title: "Progress")
        let progressLabel = TStaticText(
            frame: Rect(x: 2, y: 1, width: 30, height: 1),
            text: "Download progress:"
        )
        let progressBar = TProgressBar(
            frame: Rect(x: 2, y: 2, width: 36, height: 3),
            value: 42,
            maxValue: 100
        )
        progressBar.palette = .dialog
        let progressLabel2 = TStaticText(
            frame: Rect(x: 2, y: 5, width: 30, height: 1),
            text: "Build progress:"
        )
        let progressBar2 = TProgressBar(
            frame: Rect(x: 2, y: 6, width: 36, height: 3),
            value: 87,
            maxValue: 100
        )
        progressBar2.palette = .dialog
        progressTab.addSubview(progressLabel)
        progressTab.addSubview(progressBar)
        progressTab.addSubview(progressLabel2)
        progressTab.addSubview(progressBar2)
        
        tabControl.addTab(generalTab)
        tabControl.addTab(themeTab)
        tabControl.addTab(aboutTab)
        tabControl.addTab(progressTab)
        
        tabDemoWindow.addSubview(tabControl)
        app.desktop.addSubview(tabDemoWindow)
        
        let statusLine = TStatusLine(
            frame: Rect(x: 0, y: rows - 1, width: cols, height: 1),
            items: [
                TStatusItem(key: .f1, keyText: "F1", title: "Help"),
                TStatusItem(key: .f2, keyText: "F2", title: "Save"),
                TStatusItem(key: .f10, keyText: "F10", title: "Menu")
            ]
        )
        app.desktop.addSubview(statusLine)
        
        app.run()
    }
}
