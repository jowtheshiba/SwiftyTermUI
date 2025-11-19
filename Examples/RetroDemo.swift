import Foundation
import RetroVision
import SwiftyTermUI

@main
struct RetroDemo {
    static func main() {
        let app = TApplication.shared
        
        // Create Menu Bar
        let fileMenu = TMenu(title: "File", items: [
            TMenuItem(title: "New", action: { print("New file") }, shortcut: "F4"),
            TMenuItem(title: "Open...", action: { print("Open file") }, shortcut: "F3"),
            TMenuItem(title: "Save", action: { print("Save file") }, shortcut: "F2"),
            TMenuItem.separator,
            TMenuItem(title: "Exit", action: { 
                print("Exiting...")
                exit(0)
            }, shortcut: "Alt+X")
        ])
        
        let editMenu = TMenu(title: "Edit", items: [
            TMenuItem(title: "Undo", action: { print("Undo") }, shortcut: "Alt+BkSp"),
            TMenuItem(title: "Redo", action: { print("Redo") }),
            TMenuItem.separator,
            TMenuItem(title: "Cut", action: { print("Cut") }, shortcut: "Shift+Del"),
            TMenuItem(title: "Copy", action: { print("Copy") }, shortcut: "Ctrl+Ins"),
            TMenuItem(title: "Paste", action: { print("Paste") }, shortcut: "Shift+Ins"),
            TMenuItem.separator,
            TMenuItem(title: "Clear", action: { print("Clear") })
        ])
        
        let windowMenu = TMenu(title: "Window", items: [
            TMenuItem(title: "Size/Move", action: { print("Size/Move") }, shortcut: "Ctrl+F5"),
            TMenuItem(title: "Zoom", action: { print("Zoom") }, shortcut: "F5"),
            TMenuItem(title: "Tile", action: { print("Tile") }),
            TMenuItem(title: "Cascade", action: { print("Cascade") }),
            TMenuItem.separator,
            TMenuItem(title: "Next", action: { print("Next window") }, shortcut: "F6"),
            TMenuItem(title: "Previous", action: { print("Previous window") }, shortcut: "Shift+F6"),
            TMenuItem(title: "Close", action: { print("Close window") }, shortcut: "Alt+F3")
        ])
        
        let (cols, _) = SwiftyTermUI.shared.getTerminalSize()
        let menuBar = TMenuBar(frame: Rect(x: 0, y: 0, width: cols, height: 1), menus: [fileMenu, editMenu, windowMenu])
        app.menuBar = menuBar
        
        // Create Editor Window (Blue)
        let editorWindow = TWindow(frame: Rect(x: 5, y: 3, width: 50, height: 15), title: "Editor Window", style: .window)
        
        // Add buttons to editor window
        let okButton = TButton(frame: Rect(x: 10, y: 11, width: 12, height: 1), title: "OK") {
            print("OK pressed in Editor")
        }
        okButton.isFocused = true
        
        let cancelButton = TButton(frame: Rect(x: 25, y: 11, width: 12, height: 1), title: "Cancel") {
            print("Cancel pressed in Editor")
        }
        
        editorWindow.addSubview(okButton)
        editorWindow.addSubview(cancelButton)
        app.desktop.addSubview(editorWindow)
        
        // Create Dialog Window (Grey)
        let dialogWindow = TWindow(frame: Rect(x: 20, y: 8, width: 40, height: 12), title: "Find Dialog", style: .dialog)
        
        // Add buttons to dialog
        let findButton = TButton(frame: Rect(x: 5, y: 8, width: 12, height: 1), title: "Find") {
            print("Find pressed")
        }
        
        let replaceButton = TButton(frame: Rect(x: 20, y: 8, width: 15, height: 1), title: "Replace") {
            print("Replace pressed")
        }
        
        dialogWindow.addSubview(findButton)
        dialogWindow.addSubview(replaceButton)
        app.desktop.addSubview(dialogWindow)
        
        app.run()
    }
}
