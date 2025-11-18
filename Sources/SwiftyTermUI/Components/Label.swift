import Foundation

/// Static text label
public final class Label {
    public var x: Int
    public var y: Int
    public var text: String
    
    public var attributes: TextAttributes = []
    public var foregroundColor: Color = .default
    public var backgroundColor: Color = .default
    
    public var alignment: Alignment = .left
    public var width: Int?
    
    public enum Alignment {
        case left
        case center
        case right
    }
    
    public init(x: Int, y: Int, text: String) {
        self.x = x
        self.y = y
        self.text = text
    }
    
    /// Renders label on screen
    @MainActor public func render(to tui: SwiftyTermUI) {
        let displayText: String
        let startX: Int
        
        if let width = width {
            switch alignment {
            case .left:
                displayText = TextUtils.padRight(text, to: width)
                startX = x
            case .center:
                displayText = TextUtils.padCenter(text, to: width)
                startX = x
            case .right:
                displayText = TextUtils.padLeft(text, to: width)
                startX = x
            }
        } else {
            displayText = text
            startX = x
        }
        
        tui.drawString(
            row: y,
            column: startX,
            text: displayText,
            attributes: attributes,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }
}
