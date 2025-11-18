import Foundation

/// Text field for input
public final class TextField {
    public var x: Int
    public var y: Int
    public var width: Int
    
    public var value: String = ""
    public var placeholder: String = ""
    public var label: String?
    
    public var maxLength: Int?
    public var isPassword: Bool = false
    public var isFocused: Bool = false
    
    public var validator: ((String) -> Bool)?
    public var onChange: ((String) -> Void)?
    
    public var cursorPosition: Int = 0
    
    public var focusedForeground: Color = .brightWhite
    public var focusedBackground: Color = .blue
    public var normalForeground: Color = .white
    public var normalBackground: Color = .brightBlack
    
    public init(x: Int, y: Int, width: Int, label: String? = nil, placeholder: String = "") {
        self.x = x
        self.y = y
        self.width = width
        self.label = label
        self.placeholder = placeholder
    }
    
    /// Inserts character at cursor position
    public func insertChar(_ char: Character) {
        if let maxLength = maxLength, value.count >= maxLength {
            return
        }
        
        let index = value.index(value.startIndex, offsetBy: min(cursorPosition, value.count))
        value.insert(char, at: index)
        cursorPosition += 1
        onChange?(value)
    }
    
    /// Deletes character before cursor
    public func deleteChar() {
        guard cursorPosition > 0 else { return }
        
        let index = value.index(value.startIndex, offsetBy: cursorPosition - 1)
        value.remove(at: index)
        cursorPosition -= 1
        onChange?(value)
    }
    
    /// Moves cursor left
    public func moveCursorLeft() {
        if cursorPosition > 0 {
            cursorPosition -= 1
        }
    }
    
    /// Moves cursor right
    public func moveCursorRight() {
        if cursorPosition < value.count {
            cursorPosition += 1
        }
    }
    
    /// Validates value
    public func isValid() -> Bool {
        validator?(value) ?? true
    }
    
    /// Renders field on screen
    @MainActor public func render(to tui: SwiftyTermUI) {
        var currentY = y
        
        // Label
        if let label = label {
            tui.drawString(row: currentY, column: x, text: label, attributes: [.bold], foregroundColor: .cyan)
            currentY += 1
        }
        
        // Field background
        let bg = isFocused ? focusedBackground : normalBackground
        let fg = isFocused ? focusedForeground : normalForeground
        
        tui.fillRect(row: currentY, column: x, width: width, height: 1, character: " ", backgroundColor: bg)
        
        // Text
        let displayText: String
        if value.isEmpty {
            displayText = placeholder
        } else if isPassword {
            displayText = String(repeating: "*", count: value.count)
        } else {
            displayText = value
        }
        
        let truncated = TextUtils.truncate(displayText, to: width - 2)
        tui.drawString(
            row: currentY,
            column: x + 1,
            text: truncated,
            foregroundColor: value.isEmpty ? .brightBlack : fg,
            backgroundColor: bg
        )
        
        // Cursor
        if isFocused {
            let cursorX = x + 1 + min(cursorPosition, truncated.count)
            tui.drawChar(
                row: currentY,
                column: cursorX,
                character: "▌",
                foregroundColor: .brightYellow,
                backgroundColor: bg
            )
        }
    }
    
    /// Handles keyboard event
    public func handleInput(_ event: InputEvent) -> Bool {
        guard isFocused else { return false }
        guard case .keyPress(let key) = event else { return false }
        
        switch key {
        case .character(let char):
            insertChar(char)
            return true
        case .backspace:
            deleteChar()
            return true
        case .left:
            moveCursorLeft()
            return true
        case .right:
            moveCursorRight()
            return true
        case .home:
            cursorPosition = 0
            return true
        case .end:
            cursorPosition = value.count
            return true
        default:
            return false
        }
    }
}
