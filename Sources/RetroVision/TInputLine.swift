import SwiftyTermUI

public class TInputLine: TView {
    public var text: String {
        didSet {
            clampCursor()
            onChange?(text)
        }
    }
    public var maxLength: Int?
    public var isPassword: Bool
    public var cursorPosition: Int
    public var onChange: ((String) -> Void)?
    
    private var scrollOffset: Int = 0
    
    public init(frame: Rect, text: String = "", maxLength: Int? = nil, isPassword: Bool = false, cursorPosition: Int = 0) {
        self.text = text
        self.maxLength = maxLength
        self.isPassword = isPassword
        self.cursorPosition = cursorPosition
        super.init(frame: frame)
        clampCursor()
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 0, frame.height > 0 else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let drawWidth = max(1, frame.width)
        let drawHeight = max(1, frame.height)
        
        // Input field: fixed width, blue background (Turbo Vision style)
        let fg: Color = .white
        let bg: Color = .blue
        
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: drawWidth,
            height: drawHeight,
            character: " ",
            attributes: [],
            foregroundColor: fg,
            backgroundColor: bg
        )
        
        let row = origin.y + (drawHeight - 1) / 2
        let displayText = isPassword ? String(repeating: "*", count: text.count) : text
        let visible = visibleSlice(text: displayText, width: drawWidth)
        tui.drawString(
            row: row,
            column: origin.x,
            text: visible,
            attributes: [],
            foregroundColor: fg,
            backgroundColor: bg
        )
        
        if isFocused {
            let cursorColumn = origin.x + max(0, min(drawWidth - 1, cursorPosition - scrollOffset))
            tui.drawChar(
                row: row,
                column: cursorColumn,
                character: "▌",
                attributes: [],
                foregroundColor: .brightWhite,
                backgroundColor: bg
            )
        }
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event, isFocused, handleKey(key) {
            return
        }
        super.handleEvent(event)
    }
    
    @MainActor
    public override func mouseEvent(_ event: TEvent.MouseEvent) {
        guard event.action == .down, event.button == .left else { return }
        let localPos = event.position
        guard bounds.contains(localPos) else { return }
        RetroTextUtils.focus(view: self)
        let clickIndex = max(0, min(max(1, frame.width) - 1, localPos.x))
        cursorPosition = min(text.count, scrollOffset + clickIndex)
        clampCursor()
    }
    
    // MARK: - Private
    
    private func handleKey(_ key: Key) -> Bool {
        switch key {
        case .character(let ch):
            insertChar(ch)
            return true
        case .backspace:
            deleteCharBeforeCursor()
            return true
        case .delete:
            deleteCharAtCursor()
            return true
        case .left:
            cursorPosition = max(0, cursorPosition - 1)
            clampCursor()
            return true
        case .right:
            cursorPosition = min(text.count, cursorPosition + 1)
            clampCursor()
            return true
        case .home:
            cursorPosition = 0
            clampCursor()
            return true
        case .end:
            cursorPosition = text.count
            clampCursor()
            return true
        default:
            return false
        }
    }
    
    private func insertChar(_ ch: Character) {
        if let maxLength, text.count >= maxLength {
            return
        }
        let index = text.index(text.startIndex, offsetBy: min(cursorPosition, text.count))
        text.insert(ch, at: index)
        cursorPosition = min(text.count, cursorPosition + 1)
        clampCursor()
    }
    
    private func deleteCharBeforeCursor() {
        guard cursorPosition > 0 else { return }
        let index = text.index(text.startIndex, offsetBy: cursorPosition - 1)
        text.remove(at: index)
        cursorPosition = max(0, cursorPosition - 1)
        clampCursor()
    }
    
    private func deleteCharAtCursor() {
        guard cursorPosition < text.count else { return }
        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        text.remove(at: index)
        clampCursor()
    }
    
    private func clampCursor() {
        cursorPosition = max(0, min(cursorPosition, text.count))
        updateScrollOffset()
    }
    
    private func updateScrollOffset() {
        let width = max(1, frame.width)
        if cursorPosition < scrollOffset {
            scrollOffset = cursorPosition
        } else if cursorPosition >= scrollOffset + width {
            scrollOffset = max(0, cursorPosition - width + 1)
        }
    }
    
    private func visibleSlice(text: String, width: Int) -> String {
        guard width > 0 else { return "" }
        let start = min(scrollOffset, text.count)
        let end = min(text.count, start + width)
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        let slice = String(text[startIndex..<endIndex])
        if slice.count < width {
            return slice + String(repeating: " ", count: width - slice.count)
        }
        return slice
    }
}
