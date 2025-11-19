import RetroVision
import SwiftyTermUI

@main
struct RetroDemo {
    static func main() {
        let app = TApplication.shared
        
        // Create a window (Editor Style - Blue)
        let window1 = TWindow(frame: Rect(x: 5, y: 3, width: 40, height: 15), title: "Editor Window", style: .window)
        app.desktop.addSubview(window1)
        
        // Create a dialog (Dialog Style - Grey)
        let window2 = TWindow(frame: Rect(x: 20, y: 8, width: 30, height: 10), title: "Find Dialog", style: .dialog)
        app.desktop.addSubview(window2)
        
        app.run()
    }
}
