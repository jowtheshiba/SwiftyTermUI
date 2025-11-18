import Foundation

/// Press button
public final class Button {
    public var x: Int
    public var y: Int
    public var text: String
    
    public var isFocused: Bool = false
    public var isPressed: Bool = false
    
    public var onPress: (() -> Void)?
    
    public var focusedForeground: Color = .black
    public var focusedBackground: Color = .brightYellow
    public var normalForeground: Color = .white
    public var normalBackground: Color = .blue
    public var pressedBackground: Color = .green
    
    public init(x: Int, y: Int, text: String) {
        self.x = x
        self.y = y
        self.text = text
    }
    
    /// Presses button
    public func press() {
        isPressed = true
        onPress?()
    }
    
    /// Renders button on screen
    @MainActor public func render(to tui: SwiftyTermUI) {
        let bg = isPressed ? pressedBackground : (isFocused ? focusedBackground : normalBackground)
        let fg = isFocused ? focusedForeground : normalForeground
        
        let buttonText = " \(text) "
        
        tui.fillRect(
            row: y,
            column: x,
            width: buttonText.count,
            height: 1,
            character: " ",
            backgroundColor: bg
        )
        
        tui.drawString(
            row: y,
            column: x,
            text: buttonText,
            attributes: isFocused ? [.bold] : [],
            foregroundColor: fg,
            backgroundColor: bg
        )
        
        // Reset pressed state after render
        if isPressed {
            isPressed = false
        }
    }
    
    /// Handles keyboard event
    public func handleInput(_ event: InputEvent) -> Bool {
        guard isFocused else { return false }
        guard case .keyPress(let key) = event else { return false }
        
        if key == .enter {
            press()
            return true
        }
        
        return false
    }
}
