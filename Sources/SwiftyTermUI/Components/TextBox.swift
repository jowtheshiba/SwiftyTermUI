import Foundation

/// Multi-line text box
public final class TextBox {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
    
    public var lines: [String] = []
    public var scrollOffset: Int = 0
    
    public var hasBorder: Bool = true
    public var title: String?
    
    public var foregroundColor: Color = .white
    public var backgroundColor: Color = .default
    
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    /// Adds text (automatically splits into lines)
    public func setText(_ text: String) {
        lines = TextUtils.splitLines(text)
    }
    
    /// Adds line
    public func appendLine(_ line: String) {
        lines.append(line)
        
        // Auto-scroll to bottom
        if lines.count > height {
            scrollOffset = lines.count - height
        }
    }
    
    /// Clears text
    public func clear() {
        lines.removeAll()
        scrollOffset = 0
    }
    
    /// Scrolls up
    public func scrollUp() {
        if scrollOffset > 0 {
            scrollOffset -= 1
        }
    }
    
    /// Scrolls down
    public func scrollDown() {
        let maxScroll = max(0, lines.count - height)
        if scrollOffset < maxScroll {
            scrollOffset += 1
        }
    }
    
    /// Renders textbox on screen
    @MainActor public func render(to tui: SwiftyTermUI) {
        var currentY = y
        let contentWidth = hasBorder ? width - 2 : width
        let contentHeight = hasBorder ? height - 2 : height
        
        // Title and border
        if hasBorder {
            tui.drawRect(row: y, column: x, width: width, height: height, character: "│", foregroundColor: .cyan)
            
            if let title = title {
                let titleText = " \(title) "
                let startX = x + (width - titleText.count) / 2
                tui.drawString(row: y, column: startX, text: titleText, attributes: [.bold], foregroundColor: .brightYellow)
            }
            
            currentY += 1
        }
        
        // Content
        let startLine = scrollOffset
        let endLine = min(startLine + contentHeight, lines.count)
        
        for i in startLine..<endLine {
            let line = lines[i]
            let truncated = TextUtils.truncate(line, to: contentWidth)
            let padded = TextUtils.padRight(truncated, to: contentWidth)
            
            tui.drawString(
                row: currentY,
                column: hasBorder ? x + 1 : x,
                text: padded,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
            
            currentY += 1
        }
        
        // Fill empty lines
        while currentY < y + (hasBorder ? height - 1 : height) {
            tui.fillRect(
                row: currentY,
                column: hasBorder ? x + 1 : x,
                width: contentWidth,
                height: 1,
                character: " ",
                backgroundColor: backgroundColor
            )
            currentY += 1
        }
        
        // Scroll indicator
        if hasBorder && lines.count > contentHeight {
            let scrollbarHeight = contentHeight
            let thumbPosition = Int((Double(scrollOffset) / Double(lines.count - contentHeight)) * Double(scrollbarHeight - 1))
            
            for i in 0..<scrollbarHeight {
                let char: Character = i == thumbPosition ? "█" : "│"
                tui.drawChar(
                    row: y + 1 + i,
                    column: x + width - 1,
                    character: char,
                    foregroundColor: .brightBlue
                )
            }
        }
    }
    
    /// Handles keyboard event
    public func handleInput(_ event: InputEvent) -> Bool {
        guard case .keyPress(let key) = event else { return false }
        
        switch key {
        case .up:
            scrollUp()
            return true
        case .down:
            scrollDown()
            return true
        case .pageUp:
            for _ in 0..<height {
                scrollUp()
            }
            return true
        case .pageDown:
            for _ in 0..<height {
                scrollDown()
            }
            return true
        case .home:
            scrollOffset = 0
            return true
        case .end:
            scrollOffset = max(0, lines.count - height)
            return true
        default:
            return false
        }
    }
}
