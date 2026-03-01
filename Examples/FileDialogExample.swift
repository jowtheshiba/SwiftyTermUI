import Foundation
import SwiftyTermUI
import RetroVision

class FileDialogApp: TApplication {
    override func run() {
        // Setup menu before running
        let (cols, _) = SwiftyTermUI.shared.getTerminalSize()
        let menuBar = TMenuBar(frame: Rect(x: 0, y: 0, width: cols == 0 ? 80 : cols, height: 1), menus: [])
        
        var fileMenu = TMenu(title: "File", items: [])
        
        let openMenuItem = TMenuItem(title: "Open...", action: { [weak self] in
            self?.showFileDialog()
        })
        
        let exitMenuItem = TMenuItem(title: "Exit", action: {
            // Send Ctrl+C equivalent event to stop the loop
            let quitEvent = TEvent.key(.ctrl("c"))
            TApplication.shared.desktop.handleEvent(quitEvent)
            SwiftyTermUI.shared.shutdown()
            exit(0)
        })
        
        fileMenu.items.append(openMenuItem)
        fileMenu.items.append(exitMenuItem)
        
        menuBar.menus.append(fileMenu)
        self.menuBar = menuBar // Use TApplication's menuBar property
        
        super.run()
    }
    
    private func showFileDialog() {
        let fileDialog = TFileDialog(title: "Open File")
        
        fileDialog.onFileSelected = { [weak self] path in
            self?.showMessage(text: "Selected file: \(path)")
        }
        
        fileDialog.onCancel = { [weak self] in
            self?.showMessage(text: "File selection cancelled.")
        }
        desktop.addSubview(fileDialog)
        fileDialog.isFocused = true
        fileDialog.inputLine.isFocused = true
    }
    
    private func showMessage(text: String) {
        let msgBox = TDialog(frame: Rect(x: 20, y: 10, width: 40, height: 8), title: "Information")
        let label = TLabel(frame: Rect(x: 2, y: 2, width: 36, height: 2), text: text)
        msgBox.addSubview(label)
        
        let okBtn = TButton(frame: Rect(x: 14, y: 5, width: 10, height: 1), title: "OK", action: { [weak msgBox] in
            msgBox?.removeFromSuperview()
        })
        msgBox.addSubview(okBtn)
        
        desktop.addSubview(msgBox)
        msgBox.isFocused = true
        okBtn.isFocused = true
    }
}

@main
struct FileDialogExample {
    static func main() {
        let app = FileDialogApp()
        app.run()
    }
}
