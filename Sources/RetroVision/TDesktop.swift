import SwiftyTermUI

/// The background view that contains all windows
public class TDesktop: TView {
    private let backgroundChar: Character
    private let backgroundAttr: TextAttributes
    
    public init(frame: Rect, backgroundChar: Character = "░", backgroundAttr: TextAttributes = TextAttributes()) {
        self.backgroundChar = backgroundChar
        self.backgroundAttr = backgroundAttr
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        
        let tui = SwiftyTermUI.shared
        
        // Draw background pattern
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                tui.drawChar(
                    row: frame.y + y,
                    column: frame.x + x,
                    character: backgroundChar,
                    attributes: backgroundAttr,
                    foregroundColor: .black,
                    backgroundColor: .white
                )
            }
        }
        
        // Draw subviews (windows)
        super.draw()
    }
}
