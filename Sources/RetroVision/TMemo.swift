import SwiftyTermUI

/// Simple multi-line text editor with scrolling
public class TMemo: TView {
    public var lines: [String] {
        didSet {
            if lines.isEmpty { lines = [""] }
            clampCursor()
            syncScrollBars()
        }
    }
    
    public var text: String {
        get { lines.joined(separator: "\n") }
        set { lines = Self.splitLines(newValue) }
    }
    
    public var cursorRow: Int
    public var cursorColumn: Int
    
    public weak var verticalScrollBar: TScrollBar? {
        didSet { configureScrollBars() }
    }
    public weak var horizontalScrollBar: TScrollBar? {
        didSet { configureScrollBars() }
    }
    
    private var scrollOffsetY: Int = 0
    private var scrollOffsetX: Int = 0
    
    public init(frame: Rect, text: String = "") {
        let initialLines = Self.splitLines(text)
        self.lines = initialLines.isEmpty ? [""] : initialLines
        self.cursorRow = 0
        self.cursorColumn = 0
        super.init(frame: frame)
        clampCursor()
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 0, frame.height > 0 else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let drawWidth = frame.width
        let drawHeight = frame.height
        
        let colors = RetroTextUtils.resolvedContentColors(for: self)
        let fg = colors.fg
        let bg = colors.bg
        
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
        
        for row in 0..<drawHeight {
            let lineIndex = scrollOffsetY + row
            let lineText = lineIndex < lines.count ? lines[lineIndex] : ""
            let visible = visibleSlice(text: lineText, width: drawWidth, offset: scrollOffsetX)
            tui.drawString(
                row: origin.y + row,
                column: origin.x,
                text: visible,
                attributes: [],
                foregroundColor: fg,
                backgroundColor: bg
            )
        }
        
        if isFocused, TInputLine.cursorBlinkVisible {
            let cursorX = cursorColumn - scrollOffsetX
            let cursorY = cursorRow - scrollOffsetY
            if cursorX >= 0, cursorX < drawWidth, cursorY >= 0, cursorY < drawHeight {
                let lineIndex = max(0, min(lines.count - 1, cursorRow))
                let lineText = lines[lineIndex]
                let charIndex = cursorColumn
                let charToDraw: Character
                if charIndex >= 0, charIndex < lineText.count {
                    let index = lineText.index(lineText.startIndex, offsetBy: charIndex)
                    charToDraw = lineText[index]
                } else {
                    charToDraw = " "
                }
                tui.drawChar(
                    row: origin.y + cursorY,
                    column: origin.x + cursorX,
                    character: charToDraw,
                    attributes: [.reverse],
                    foregroundColor: fg,
                    backgroundColor: bg
                )
            }
        }
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event, isFocused, handleKey(key) {
            TApplication.shared.resetInputBlink()
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
        TApplication.shared.resetInputBlink()
        
        let targetRow = scrollOffsetY + localPos.y
        let clampedRow = max(0, min(lines.count - 1, targetRow))
        let lineLength = lines[clampedRow].count
        let targetCol = scrollOffsetX + localPos.x
        let clampedCol = max(0, min(lineLength, targetCol))
        cursorRow = clampedRow
        cursorColumn = clampedCol
        clampCursor()
    }
    
    // MARK: - Private
    
    private func handleKey(_ key: Key) -> Bool {
        switch key {
        case .character(let ch):
            insertChar(ch)
            return true
        case .enter:
            insertNewline()
            return true
        case .backspace:
            deleteCharBeforeCursor()
            return true
        case .delete:
            deleteCharAtCursor()
            return true
        case .left:
            moveLeft()
            return true
        case .right:
            moveRight()
            return true
        case .up:
            moveUp()
            return true
        case .down:
            moveDown()
            return true
        case .home:
            cursorColumn = 0
            clampCursor()
            return true
        case .end:
            cursorColumn = currentLine().count
            clampCursor()
            return true
        case .pageUp:
            cursorRow = max(0, cursorRow - max(1, frame.height))
            clampCursor()
            return true
        case .pageDown:
            cursorRow = min(lines.count - 1, cursorRow + max(1, frame.height))
            clampCursor()
            return true
        default:
            return false
        }
    }
    
    private func currentLine() -> String {
        let row = max(0, min(lines.count - 1, cursorRow))
        return lines[row]
    }
    
    private func insertChar(_ ch: Character) {
        let row = max(0, min(lines.count - 1, cursorRow))
        var line = lines[row]
        let index = line.index(line.startIndex, offsetBy: min(cursorColumn, line.count))
        line.insert(ch, at: index)
        lines[row] = line
        cursorColumn += 1
        clampCursor()
    }
    
    private func insertNewline() {
        let row = max(0, min(lines.count - 1, cursorRow))
        let line = lines[row]
        let splitIndex = line.index(line.startIndex, offsetBy: min(cursorColumn, line.count))
        let left = String(line[..<splitIndex])
        let right = String(line[splitIndex...])
        lines[row] = left
        lines.insert(right, at: row + 1)
        cursorRow += 1
        cursorColumn = 0
        clampCursor()
    }
    
    private func deleteCharBeforeCursor() {
        if cursorColumn > 0 {
            let row = max(0, min(lines.count - 1, cursorRow))
            var line = lines[row]
            let index = line.index(line.startIndex, offsetBy: cursorColumn - 1)
            line.remove(at: index)
            lines[row] = line
            cursorColumn -= 1
        } else if cursorRow > 0 {
            let prevRow = cursorRow - 1
            let merged = lines[prevRow] + lines[cursorRow]
            lines[prevRow] = merged
            lines.remove(at: cursorRow)
            cursorRow = prevRow
            cursorColumn = lines[prevRow].count
        }
        clampCursor()
    }
    
    private func deleteCharAtCursor() {
        let row = max(0, min(lines.count - 1, cursorRow))
        var line = lines[row]
        if cursorColumn < line.count {
            let index = line.index(line.startIndex, offsetBy: cursorColumn)
            line.remove(at: index)
            lines[row] = line
        } else if row < lines.count - 1 {
            lines[row] = line + lines[row + 1]
            lines.remove(at: row + 1)
        }
        clampCursor()
    }
    
    private func moveLeft() {
        if cursorColumn > 0 {
            cursorColumn -= 1
        } else if cursorRow > 0 {
            cursorRow -= 1
            cursorColumn = lines[cursorRow].count
        }
        clampCursor()
    }
    
    private func moveRight() {
        let lineLength = currentLine().count
        if cursorColumn < lineLength {
            cursorColumn += 1
        } else if cursorRow < lines.count - 1 {
            cursorRow += 1
            cursorColumn = 0
        }
        clampCursor()
    }
    
    private func moveUp() {
        cursorRow = max(0, cursorRow - 1)
        cursorColumn = min(cursorColumn, currentLine().count)
        clampCursor()
    }
    
    private func moveDown() {
        cursorRow = min(lines.count - 1, cursorRow + 1)
        cursorColumn = min(cursorColumn, currentLine().count)
        clampCursor()
    }
    
    private func clampCursor() {
        cursorRow = max(0, min(lines.count - 1, cursorRow))
        let lineLength = lines[cursorRow].count
        cursorColumn = max(0, min(lineLength, cursorColumn))
        updateScrollOffsets()
        syncScrollBars()
    }
    
    private func updateScrollOffsets() {
        let width = max(1, frame.width)
        let height = max(1, frame.height)
        let maxScrollY = max(0, lines.count - height)
        let maxLineLen = maxLineLength()
        let maxScrollX = max(0, maxLineLen - width)
        
        if cursorRow < scrollOffsetY {
            scrollOffsetY = cursorRow
        } else if cursorRow >= scrollOffsetY + height {
            scrollOffsetY = min(maxScrollY, max(0, cursorRow - height + 1))
        }
        
        if cursorColumn < scrollOffsetX {
            scrollOffsetX = cursorColumn
        } else if cursorColumn >= scrollOffsetX + width {
            scrollOffsetX = min(maxScrollX, max(0, cursorColumn - width + 1))
        }
        
        scrollOffsetY = max(0, min(scrollOffsetY, maxScrollY))
        scrollOffsetX = max(0, min(scrollOffsetX, maxScrollX))
    }
    
    private func configureScrollBars() {
        verticalScrollBar?.onChange = { [weak self] value in
            self?.scrollOffsetY = max(0, value)
            self?.clampScrollOffsets()
        }
        horizontalScrollBar?.onChange = { [weak self] value in
            self?.scrollOffsetX = max(0, value)
            self?.clampScrollOffsets()
        }
        syncScrollBars()
    }
    
    private func syncScrollBars() {
        let height = max(1, frame.height)
        let width = max(1, frame.width)
        let maxLen = maxLineLength()
        
        verticalScrollBar?.totalItems = lines.count
        verticalScrollBar?.pageSize = height
        verticalScrollBar?.value = min(scrollOffsetY, max(0, lines.count - height))
        
        horizontalScrollBar?.totalItems = maxLen
        horizontalScrollBar?.pageSize = width
        horizontalScrollBar?.value = min(scrollOffsetX, max(0, maxLen - width))
    }
    
    private func clampScrollOffsets() {
        let height = max(1, frame.height)
        let width = max(1, frame.width)
        let maxLen = maxLineLength()
        let maxScrollY = max(0, lines.count - height)
        let maxScrollX = max(0, maxLen - width)
        scrollOffsetY = max(0, min(scrollOffsetY, maxScrollY))
        scrollOffsetX = max(0, min(scrollOffsetX, maxScrollX))
    }
    
    private func maxLineLength() -> Int {
        lines.map { $0.count }.max() ?? 0
    }
    
    private func visibleSlice(text: String, width: Int, offset: Int) -> String {
        guard width > 0 else { return "" }
        let start = min(offset, text.count)
        let end = min(text.count, start + width)
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        let slice = String(text[startIndex..<endIndex])
        if slice.count < width {
            return slice + String(repeating: " ", count: width - slice.count)
        }
        return slice
    }
    
    private static func splitLines(_ text: String) -> [String] {
        let parts = text.split(separator: "\n", omittingEmptySubsequences: false)
        if parts.isEmpty { return [""] }
        return parts.map(String.init)
    }
}
