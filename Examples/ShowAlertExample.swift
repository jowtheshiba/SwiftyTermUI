import Foundation
import RetroVision
import SwiftyTermUI

@main
struct ShowAlertExample {
    @MainActor
    static func main() {
        let app = TApplication.shared
        
        // Create Menu Bar
        let fileMenu = TMenu(title: "File", items: [
            TMenuItem(title: "Show Alert", action: {
                showAlert()
            }, shortcut: "F5", shortcutKey: .f5),
            TMenuItem.separator,
            TMenuItem(title: "Exit", action: {
                TApplication.shared.postCommand(.quit)
            }, shortcut: "Alt+X", shortcutKey: .alt("x"))
        ])
        
        let helpMenu = TMenu(title: "Help", items: [
            TMenuItem(title: "About", action: {
                showAboutAlert()
            })
        ])
        
        let (cols, rows) = SwiftyTermUI.shared.getTerminalSize()
        let menuBar = TMenuBar(frame: Rect(x: 0, y: 0, width: cols, height: 1), menus: [fileMenu, helpMenu])
        app.menuBar = menuBar
        
        // Create a simple info window
        let infoWindow = TDialog(frame: Rect(x: 5, y: 2, width: 60, height: 8), title: "Show Alert Example")
        
        let infoText = TStaticText(
            frame: Rect(x: 2, y: 2, width: 40, height: 3),
            text: "Use File menu to:\n- Show Alert (F5)\n- About (Help menu)"
        )
        
        infoWindow.addSubview(infoText)
        app.desktop.addSubview(infoWindow)
        
        let statusLine = TStatusLine(
            frame: Rect(x: 0, y: rows - 1, width: cols, height: 1),
            items: [
                TStatusItem(key: .f5, keyText: "F5", title: "Show Alert"),
                TStatusItem(key: .f10, keyText: "F10", title: "Menu")
            ]
        )
        app.desktop.addSubview(statusLine)
        
        app.run()
    }
    
    @MainActor
    private static func showAlert() {
        let (cols, rows) = SwiftyTermUI.shared.getTerminalSize()
        let alertWidth = 30
        let alertHeight = 6
        
        let x = (cols - alertWidth) / 2
        let y = (rows - alertHeight) / 2
        
        let alert = TAlertDialog(
            frame: Rect(x: x, y: y, width: alertWidth, height: alertHeight),
            type: .information,
            message: "Test alert"
        )
        
        TApplication.shared.present(modal: alert)
    }
    
    @MainActor
    private static func showAboutAlert() {
        let (cols, rows) = SwiftyTermUI.shared.getTerminalSize()
        let alertWidth = 35
        let alertHeight = 8
        
        let x = (cols - alertWidth) / 2
        let y = (rows - alertHeight) / 2
        
        let alert = TAlertDialog(
            frame: Rect(x: x, y: y, width: alertWidth, height: alertHeight),
            type: .information,
            message: "Show Alert Example\nDemonstrates TAlertDialog"
        )
        
        TApplication.shared.present(modal: alert)
    }
}
