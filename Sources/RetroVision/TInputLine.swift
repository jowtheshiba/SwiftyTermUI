import SwiftyTermUI

@MainActor
public class TInputLine: TView {
    @MainActor public static var cursorBlinkVisible: Bool = true

    public var text: String {
        didSet {
            clampCursor()
            onChange?(text)
        }
    }
    public var maxLength: Int?
    public var isPassword: Bool
    public var cursorPosition: Int
    public var selectionStart: Int?
    public var hasSelection: Bool { selectionStart != nil }
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
        let displayArr = Array(displayText)
        let selRange = selectedRange()
        
        for col in 0..<drawWidth {
            let charIndex = scrollOffset + col
            let ch: Character = charIndex < displayArr.count ? displayArr[charIndex] : " "
            
            var charBg = bg
            var charFg = fg
            
            if let (selStart, selEnd) = selRange, charIndex >= selStart && charIndex < selEnd {
                charBg = .white
                charFg = .black
            }
            
            tui.drawChar(
                row: row,
                column: origin.x + col,
                character: ch,
                attributes: [],
                foregroundColor: charFg,
                backgroundColor: charBg
            )
        }
        
        if isFocused, Self.cursorBlinkVisible {
            let cursorColumn = origin.x + max(0, min(drawWidth - 1, cursorPosition - scrollOffset))
            tui.drawChar(
                row: row,
                column: cursorColumn,
                character: "_",
                attributes: [],
                foregroundColor: .brightWhite,
                backgroundColor: bg
            )
        }
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        if isFocused {
            if case .key(let key) = event, handleKey(key) {
                TApplication.shared.resetInputBlink()
                return
            }
            if case .paste(let text) = event {
                paste(text: text)
                TApplication.shared.resetInputBlink()
                return
            }
        }
        super.handleEvent(event)
    }
    
    @MainActor
    public override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard event.button == .left else { return false }
        let localPos = event.position
        
        // Handle drag to select
        if event.action == .drag {
            let clickIndex = max(0, min(max(1, frame.width) - 1, localPos.x))
            let targetPos = min(text.count, scrollOffset + clickIndex)
            
            if selectionStart == nil {
                selectionStart = cursorPosition
            }
            
            cursorPosition = targetPos
            clampCursor()
            return true
        }
        
        // Handle selection complete
        if event.action == .up {
            if hasSelection {
                copySelection()
            }
            return true
        }
        
        guard event.action == .down else { return false }
        guard bounds.contains(localPos) else { return false }
        RetroTextUtils.focus(view: self)
        TApplication.shared.resetInputBlink()
        let prevPos = cursorPosition
        let clickIndex = max(0, min(max(1, frame.width) - 1, localPos.x))
        cursorPosition = min(text.count, scrollOffset + clickIndex)
        
        if event.modifiers.contains(.shift) {
            if selectionStart == nil {
                selectionStart = prevPos
            }
        } else {
            clearSelection()
        }
        
        clampCursor()
        return true
    }
    
    // MARK: - Private
    
    private func handleKey(_ key: Key) -> Bool {
        switch key {
        case .character(let ch):
            if hasSelection { deleteSelection() }
            insertChar(ch)
            return true
        case .backspace:
            if hasSelection {
                deleteSelection()
            } else {
                deleteCharBeforeCursor()
            }
            return true
        case .delete:
            if hasSelection {
                deleteSelection()
            } else {
                deleteCharAtCursor()
            }
            return true
        case .left:
            clearSelection()
            cursorPosition = max(0, cursorPosition - 1)
            clampCursor()
            return true
        case .right:
            clearSelection()
            cursorPosition = min(text.count, cursorPosition + 1)
            clampCursor()
            return true
        case .shiftLeft:
            startSelection()
            cursorPosition = max(0, cursorPosition - 1)
            clampCursor()
            copySelection()
            return true
        case .shiftRight:
            startSelection()
            cursorPosition = min(text.count, cursorPosition + 1)
            clampCursor()
            copySelection()
            return true
        case .ctrl("c"), .ctrlInsert:
            copySelection()
            return true
        case .ctrl("x"), .shiftDelete:
            cutSelection()
            return true
        case .ctrl("v"), .shiftInsert:
            pasteFromClipboard()
            return true
        case .home:
            if !hasSelection { clearSelection() }
            cursorPosition = 0
            clampCursor()
            return true
        case .end:
            if !hasSelection { clearSelection() }
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
        let deleteAt = cursorPosition - 1
        let index = text.index(text.startIndex, offsetBy: deleteAt)
        cursorPosition = deleteAt
        text.remove(at: index)
        clampCursor()
    }
    
    private func deleteCharAtCursor() {
        guard cursorPosition < text.count else { return }
        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        text.remove(at: index)
        clampCursor()
    }
    
    // MARK: - Selection and Clipboard
    
    public func selectedRange() -> (start: Int, end: Int)? {
        guard let start = selectionStart else { return nil }
        if start == cursorPosition { return nil }
        return start < cursorPosition ? (start, cursorPosition) : (cursorPosition, start)
    }
    
    private func startSelection() {
        if selectionStart == nil {
            selectionStart = cursorPosition
        }
    }
    
    @MainActor
    public func clearSelection() {
        selectionStart = nil
    }
    
    @MainActor
    public func copySelection() {
        guard let (start, end) = selectedRange(), !isPassword else { return }
        let sIdx = text.index(text.startIndex, offsetBy: start)
        let eIdx = text.index(text.startIndex, offsetBy: end)
        TClipboard.text = String(text[sIdx..<eIdx])
    }
    
    @MainActor
    public func cutSelection() {
        copySelection()
        deleteSelection()
    }
    
    @MainActor
    public func pasteFromClipboard() {
        paste(text: TClipboard.text)
    }
    
    @MainActor
    public func paste(text textToPaste: String) {
        if hasSelection {
            deleteSelection()
        }
        let cleanText = textToPaste.replacingOccurrences(of: "\n", with: " ")
        guard !cleanText.isEmpty else { return }
        
        var charArray = Array(cleanText)
        if let maxLen = maxLength {
            let spaceLeft = maxLen - text.count
            if spaceLeft <= 0 { return }
            if charArray.count > spaceLeft {
                charArray = Array(charArray.prefix(spaceLeft))
            }
        }
        
        let insertIdx = text.index(text.startIndex, offsetBy: cursorPosition)
        text.insert(contentsOf: String(charArray), at: insertIdx)
        cursorPosition += charArray.count
        clampCursor()
    }
    
    @MainActor
    public func deleteSelection() {
        guard let (start, end) = selectedRange() else { return }
        let sIdx = text.index(text.startIndex, offsetBy: start)
        let eIdx = text.index(text.startIndex, offsetBy: end)
        text.removeSubrange(sIdx..<eIdx)
        cursorPosition = start
        clearSelection()
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
        // Don't scroll past the end of text — avoid showing blank space
        // while the actual text is hidden off the left edge
        let maxScroll = max(0, text.count - width + 1)
        scrollOffset = max(0, min(scrollOffset, maxScroll))
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
