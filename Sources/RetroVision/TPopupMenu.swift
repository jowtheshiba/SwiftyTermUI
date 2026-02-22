import SwiftyTermUI

@MainActor
public class TPopupMenu: TView {
    public var items: [TMenuItem]
    public var onDismiss: (() -> Void)?
    
    private var selectedIndex: Int = 0
    
    public init(position: Point, items: [TMenuItem]) {
        self.items = items
        super.init(frame: Rect(x: position.x, y: position.y, width: 1, height: 1))
        updateLayout()
        selectedIndex = firstSelectableIndex()
    }
    
    private func updateLayout() {
        let (columns, rows) = SwiftyTermUI.shared.getTerminalSize()
        var maxWidth = 20
        for item in items {
            let itemWidth = item.title.count + (item.shortcut?.count ?? 0) + 4
            maxWidth = max(maxWidth, itemWidth)
        }
        
        let availableWidth = max(4, columns - frame.x)
        let width = max(4, min(maxWidth, availableWidth))
        let height = items.count + 2
        
        if frame.y + height > rows {
            frame.y = max(0, rows - height)
        }
        
        self.frame.width = width
        self.frame.height = height
    }
    
    public func dismiss() {
        onDismiss?()
        removeFromSuperview()
        TApplication.shared.redraw()
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        
        // Draw shadow
        tui.fillRect(
            row: origin.y + 1,
            column: origin.x + 1,
            width: frame.width + 1,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .black
        )
        
        // Draw background
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        // Draw borders
        tui.drawString(
            row: origin.y,
            column: origin.x,
            text: "┌" + String(repeating: "─", count: frame.width - 2) + "┐",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        tui.drawString(
            row: origin.y + frame.height - 1,
            column: origin.x,
            text: "└" + String(repeating: "─", count: frame.width - 2) + "┘",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        let selectedBg: Color = .green
        
        // Draw items
        for (index, item) in items.enumerated() {
            let itemY = origin.y + 1 + index
            
            if item.isSeparator {
                tui.drawString(
                    row: itemY,
                    column: origin.x,
                    text: "├" + String(repeating: "─", count: frame.width - 2) + "┤",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
            } else {
                tui.drawChar(
                    row: itemY,
                    column: origin.x,
                    character: "│",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
                tui.drawChar(
                    row: itemY,
                    column: origin.x + frame.width - 1,
                    character: "│",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
                
                let isSelected = index == selectedIndex
                let itemFg: Color = isSelected ? .brightWhite : .black
                let itemBg: Color = isSelected ? selectedBg : .white
                let itemText = buildItemLine(item, contentWidth: frame.width - 2)
                
                tui.drawString(
                    row: itemY,
                    column: origin.x + 1,
                    text: itemText,
                    attributes: [],
                    foregroundColor: itemFg,
                    backgroundColor: itemBg
                )
            }
        }
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        switch event {
        case .key(let key):
            if handleKeyEvent(key) { return }
        case .mouse(let mouseEvent):
            if handleMouseEvent(mouseEvent) { return }
        default:
            break
        }
        
        super.handleEvent(event)
    }
    
    @MainActor
    @discardableResult
    public override func handleMouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard isVisible else { return false }
        let localPoint = globalToLocal(event.position)
        
        if !bounds.contains(localPoint) {
            if event.action == .down {
                dismiss() // Clicked outside, so dismiss
            }
            return true // Consume click to prevent clicking items under menu
        }
        
        if event.action == .move || event.action == .drag {
            let itemIndex = localPoint.y - 1
            if itemIndex >= 0 && itemIndex < items.count {
                if !items[itemIndex].isSeparator {
                    if selectedIndex != itemIndex {
                        selectedIndex = itemIndex
                        TApplication.shared.redraw()
                    }
                }
            }
            return true
        }
        
        if event.action == .down && event.button == .left {
            let itemIndex = localPoint.y - 1
            if itemIndex >= 0 && itemIndex < items.count {
                let item = items[itemIndex]
                if !item.isSeparator {
                    item.action?()
                    dismiss()
                }
            }
            return true
        }
        
        return true
    }
    
    @MainActor
    private func handleKeyEvent(_ key: Key) -> Bool {
        switch key {
        case .escape:
            dismiss()
            return true
        case .up:
            selectedIndex = moveSelection(from: selectedIndex, direction: -1)
            return true
        case .down:
            selectedIndex = moveSelection(from: selectedIndex, direction: 1)
            return true
        case .enter:
            if selectedIndex >= 0 && selectedIndex < items.count {
                let item = items[selectedIndex]
                if !item.isSeparator {
                    item.action?()
                    dismiss()
                }
            }
            return true
        default:
            return true // Consume all keys while open
        }
    }
    
    private func firstSelectableIndex() -> Int {
        for (index, item) in items.enumerated() {
            if !item.isSeparator {
                return index
            }
        }
        return 0
    }
    
    private func moveSelection(from index: Int, direction: Int) -> Int {
        guard !items.isEmpty else { return 0 }
        var idx = index
        for _ in 0..<items.count {
            idx = (idx + direction + items.count) % items.count
            if !items[idx].isSeparator {
                return idx
            }
        }
        return index
    }
    
    private func buildItemLine(_ item: TMenuItem, contentWidth: Int) -> String {
        guard contentWidth > 0 else { return "" }
        
        var chars = Array(repeating: Character(" "), count: contentWidth)
        let shortcut = item.shortcut ?? ""
        let shortcutWidth = shortcut.count
        let rightReserved = shortcutWidth > 0 ? shortcutWidth + 1 : 0
        let titleAvailable = max(0, contentWidth - rightReserved - 1)
        let titleText = String(item.title.prefix(titleAvailable))
        
        for (i, ch) in titleText.enumerated() {
            let idx = 1 + i
            if idx >= 0 && idx < contentWidth {
                chars[idx] = ch
            }
        }
        
        if shortcutWidth > 0 {
            let shortcutStart = max(0, contentWidth - shortcutWidth)
            for (i, ch) in shortcut.enumerated() {
                let idx = shortcutStart + i
                if idx >= 0 && idx < contentWidth {
                    chars[idx] = ch
                }
            }
        }
        
        return String(chars)
    }
}
