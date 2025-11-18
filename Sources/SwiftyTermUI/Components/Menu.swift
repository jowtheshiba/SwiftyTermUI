import Foundation

/// Menu component with list of items and navigation
public final class Menu {
    public var x: Int
    public var y: Int
    public var width: Int
    
    public var items: [String]
    public private(set) var selectedIndex: Int = 0
    
    public var onSelect: ((Int, String) -> Void)?
    
    public var selectedStyle: TextAttributes = [.bold]
    public var selectedForeground: Color = .brightWhite
    public var selectedBackground: Color = .blue
    
    public var normalForeground: Color = .white
    public var normalBackground: Color = .default
    
    public var title: String?
    public var hasBorder: Bool = true
    
    public init(x: Int, y: Int, width: Int, items: [String]) {
        self.x = x
        self.y = y
        self.width = width
        self.items = items
    }
    
    /// Moves selection up
    public func moveUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        } else {
            selectedIndex = items.count - 1
        }
    }
    
    /// Moves selection down
    public func moveDown() {
        if selectedIndex < items.count - 1 {
            selectedIndex += 1
        } else {
            selectedIndex = 0
        }
    }
    
    /// Selects current item
    public func selectCurrent() {
        guard selectedIndex < items.count else { return }
        onSelect?(selectedIndex, items[selectedIndex])
    }
    
    /// Renders menu on screen
    @MainActor public func render(to tui: SwiftyTermUI) {
        var currentY = y
        
        // Title
        if let title = title {
            tui.drawString(row: currentY, column: x, text: title, attributes: [.bold], foregroundColor: .brightYellow)
            currentY += 1
        }
        
        // Border
        if hasBorder {
            let height = items.count + 2
            tui.drawRect(row: currentY, column: x, width: width, height: height, character: "│", foregroundColor: .cyan)
            currentY += 1
        }
        
        // Menu items
        for (index, item) in items.enumerated() {
            let isSelected = index == selectedIndex
            let displayText = isSelected ? "► \(item)" : "  \(item)"
            let truncated = TextUtils.truncate(displayText, to: width - 4)
            let padded = TextUtils.padRight(truncated, to: width - 4)
            
            if isSelected {
                tui.fillRect(
                    row: currentY,
                    column: x + 2,
                    width: width - 4,
                    height: 1,
                    character: " ",
                    backgroundColor: selectedBackground
                )
                
                tui.drawString(
                    row: currentY,
                    column: x + 2,
                    text: padded,
                    attributes: selectedStyle,
                    foregroundColor: selectedForeground,
                    backgroundColor: selectedBackground
                )
            } else {
                tui.drawString(
                    row: currentY,
                    column: x + 2,
                    text: padded,
                    foregroundColor: normalForeground,
                    backgroundColor: normalBackground
                )
            }
            
            currentY += 1
        }
    }
    
    /// Handles keyboard event
    public func handleInput(_ event: InputEvent) -> Bool {
        guard case .keyPress(let key) = event else { return false }
        
        switch key {
        case .up:
            moveUp()
            return true
        case .down:
            moveDown()
            return true
        case .enter:
            selectCurrent()
            return true
        default:
            return false
        }
    }
}
