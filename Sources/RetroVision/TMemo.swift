import SwiftyTermUI

@MainActor
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
    public var selectionStart: TextPosition?
    
    public var hasSelection: Bool { selectionStart != nil }
    
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
        contextMenu = { [weak self] in
            guard let self else { return [] }
            return [
                TMenuItem(title: "Cut", action: { self.cutSelection() }),
                TMenuItem(title: "Copy", action: { self.copySelection() }),
                TMenuItem(title: "Paste", action: { self.pasteFromClipboard() }),
                TMenuItem.separator,
                TMenuItem(title: "Clear", action: { self.deleteSelection() })
            ]
        }
        clampCursor()
    }
    
    @MainActor
    public override func preferredContextMenuPosition() -> Point {
        let localX = min(frame.width - 1, max(0, cursorColumn - scrollOffsetX))
        var localY = min(frame.height - 1, max(0, cursorRow - scrollOffsetY))
        if localY + 1 < frame.height { localY += 1 }
        return localToGlobal(Point(x: localX, y: localY))
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
        
        let selRange = selectedRange()
        
        for row in 0..<drawHeight {
            let lineIndex = scrollOffsetY + row
            let lineText = lineIndex < lines.count ? lines[lineIndex] : ""
            let lineArr = Array(lineText)
            
            for col in 0..<drawWidth {
                let charIndex = scrollOffsetX + col
                let ch: Character = charIndex < lineArr.count ? lineArr[charIndex] : " "
                
                var charBg = bg
                var charFg = fg
                
                if let (selStart, selEnd) = selRange {
                    let pos = TextPosition(row: lineIndex, column: charIndex)
                    if pos >= selStart && pos < selEnd {
                        charBg = .white
                        charFg = .black
                    }
                }
                
                tui.drawChar(
                    row: origin.y + row,
                    column: origin.x + col,
                    character: ch,
                    attributes: [],
                    foregroundColor: charFg,
                    backgroundColor: charBg
                )
            }
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
            let targetRow = scrollOffsetY + localPos.y
            let clampedRow = max(0, min(lines.count - 1, targetRow))
            let lineLength = lines[clampedRow].count
            let targetCol = scrollOffsetX + localPos.x
            let clampedCol = max(0, min(lineLength, targetCol))
            
            if selectionStart == nil {
                selectionStart = TextPosition(row: cursorRow, column: cursorColumn)
            }
            
            cursorRow = clampedRow
            cursorColumn = clampedCol
            
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
        
        let targetRow = scrollOffsetY + localPos.y
        let clampedRow = max(0, min(lines.count - 1, targetRow))
        let lineLength = lines[clampedRow].count
        let targetCol = scrollOffsetX + localPos.x
        let clampedCol = max(0, min(lineLength, targetCol))
        
        let prevRow = cursorRow
        let prevCol = cursorColumn
        
        cursorRow = clampedRow
        cursorColumn = clampedCol
        
        if event.modifiers.contains(.shift) {
            if selectionStart == nil {
                selectionStart = TextPosition(row: prevRow, column: prevCol)
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
        case .enter:
            if hasSelection { deleteSelection() }
            insertNewline()
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
            moveLeft()
            return true
        case .right:
            clearSelection()
            moveRight()
            return true
        case .up:
            clearSelection()
            moveUp()
            return true
        case .down:
            clearSelection()
            moveDown()
            return true
        case .shiftLeft:
            startSelection()
            moveLeft()
            copySelection()
            return true
        case .shiftRight:
            startSelection()
            moveRight()
            copySelection()
            return true
        case .shiftUp:
            startSelection()
            moveUp()
            copySelection()
            return true
        case .shiftDown:
            startSelection()
            moveDown()
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
            cursorColumn = 0
            clampCursor()
            return true
        case .end:
            if !hasSelection { clearSelection() }
            cursorColumn = currentLine().count
            clampCursor()
            return true
        case .pageUp:
            if !hasSelection { clearSelection() }
            cursorRow = max(0, cursorRow - max(1, frame.height))
            clampCursor()
            return true
        case .pageDown:
            if !hasSelection { clearSelection() }
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
        // Batch mutations to avoid intermediate didSet → clampCursor
        var newLines = lines
        newLines[row] = left
        newLines.insert(right, at: row + 1)
        cursorRow = row + 1
        cursorColumn = 0
        lines = newLines
    }
    
    private func deleteCharBeforeCursor() {
        if cursorColumn > 0 {
            let row = max(0, min(lines.count - 1, cursorRow))
            var line = lines[row]
            let deleteAt = cursorColumn - 1
            let index = line.index(line.startIndex, offsetBy: deleteAt)
            line.remove(at: index)
            cursorColumn = deleteAt
            lines[row] = line
        } else if cursorRow > 0 {
            // Batch mutations to avoid intermediate didSet → clampCursor
            let prevRow = cursorRow - 1
            let prevLineLength = lines[prevRow].count
            let merged = lines[prevRow] + lines[cursorRow]
            var newLines = lines
            newLines[prevRow] = merged
            newLines.remove(at: prevRow + 1)
            cursorRow = prevRow
            cursorColumn = prevLineLength
            lines = newLines
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
            // Batch mutations to avoid intermediate didSet → clampCursor
            var newLines = lines
            newLines[row] = line + newLines[row + 1]
            newLines.remove(at: row + 1)
            lines = newLines
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
    
    // MARK: - Selection and Clipboard
    
    public func selectedRange() -> (start: TextPosition, end: TextPosition)? {
        guard let start = selectionStart else { return nil }
        let current = TextPosition(row: cursorRow, column: cursorColumn)
        if start == current { return nil }
        return start < current ? (start, current) : (current, start)
    }
    
    private func startSelection() {
        if selectionStart == nil {
            selectionStart = TextPosition(row: cursorRow, column: cursorColumn)
        }
    }
    
    @MainActor
    public func clearSelection() {
        selectionStart = nil
    }
    
    @MainActor
    public func copySelection() {
        guard let (start, end) = selectedRange() else { return }
        
        if start.row == end.row {
            let line = lines[start.row]
            let sIdx = line.index(line.startIndex, offsetBy: start.column)
            let eIdx = line.index(line.startIndex, offsetBy: end.column)
            TClipboard.text = String(line[sIdx..<eIdx])
        } else {
            var copied = [String]()
            
            let startLine = lines[start.row]
            let sIdx = startLine.index(startLine.startIndex, offsetBy: start.column)
            copied.append(String(startLine[sIdx...]))
            
            for r in (start.row + 1)..<end.row {
                copied.append(lines[r])
            }
            
            let endLine = lines[end.row]
            let eIdx = endLine.index(endLine.startIndex, offsetBy: end.column)
            copied.append(String(endLine[..<eIdx]))
            
            TClipboard.text = copied.joined(separator: "\n")
        }
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
        guard !textToPaste.isEmpty else { return }
        
        let pasteLines = textToPaste.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        
        let row = cursorRow
        let line = lines[row]
        let insertIdx = line.index(line.startIndex, offsetBy: cursorColumn)
        
        let leftPart = String(line[..<insertIdx])
        let rightPart = String(line[insertIdx...])
        
        if pasteLines.count == 1 {
            lines[row] = leftPart + pasteLines[0] + rightPart
            cursorColumn += pasteLines[0].count
        } else {
            var newLines = lines
            newLines[row] = leftPart + pasteLines[0]
            
            var insertRow = row + 1
            for i in 1..<(pasteLines.count - 1) {
                newLines.insert(pasteLines[i], at: insertRow)
                insertRow += 1
            }
            
            let lastPaste = pasteLines.last!
            newLines.insert(lastPaste + rightPart, at: insertRow)
            
            cursorRow = insertRow
            cursorColumn = lastPaste.count
            lines = newLines
        }
        clampCursor()
    }
    
    @MainActor
    public func deleteSelection() {
        guard let (start, end) = selectedRange() else { return }
        
        if start.row == end.row {
            var line = lines[start.row]
            let sIdx = line.index(line.startIndex, offsetBy: start.column)
            let eIdx = line.index(line.startIndex, offsetBy: end.column)
            line.removeSubrange(sIdx..<eIdx)
            lines[start.row] = line
        } else {
            let startLine = lines[start.row]
            let endLine = lines[end.row]
            
            let sIdx = startLine.index(startLine.startIndex, offsetBy: start.column)
            let leftPart = String(startLine[..<sIdx])
            
            let eIdx = endLine.index(endLine.startIndex, offsetBy: end.column)
            let rightPart = String(endLine[eIdx...])
            
            var newLines = lines
            newLines[start.row] = leftPart + rightPart
            newLines.removeSubrange((start.row + 1)...end.row)
            lines = newLines
        }
        
        cursorRow = start.row
        cursorColumn = start.column
        clearSelection()
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
