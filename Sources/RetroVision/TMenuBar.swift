import SwiftyTermUI

public struct TMenuItem {
    public var title: String
    public var action: (() -> Void)?
    public var shortcut: String?
    public var isSeparator: Bool
    
    public init(title: String, action: (() -> Void)? = nil, shortcut: String? = nil) {
        self.title = title
        self.action = action
        self.shortcut = shortcut
        self.isSeparator = false
    }
    
    public static var separator: TMenuItem {
        var item = TMenuItem(title: "")
        item.isSeparator = true
        return item
    }
}

public struct TMenu {
    public var title: String
    public var items: [TMenuItem]
    
    public init(title: String, items: [TMenuItem]) {
        self.title = title
        self.items = items
    }
}

public class TMenuBar: TView {
    public var menus: [TMenu]
    
    // State for dropdown
    private var isMenuOpen: Bool = false
    private var selectedMenuIndex: Int = 0
    private var selectedItemIndex: Int = 0
    
    public init(frame: Rect, menus: [TMenu]) {
        self.menus = menus
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        
        let tui = SwiftyTermUI.shared
        let globalPos = localToGlobal(Point(x: 0, y: 0))
        
        // Draw Bar Background
        // Color: Black on Grey (White/LightGrey)
        let fg: Color = .black
        let bg: Color = .white // ANSI White is usually Light Grey
        
        // Fill the entire bar
        tui.fillRect(
            row: globalPos.y,
            column: globalPos.x,
            width: frame.width,
            height: 1,
            character: " ",
            attributes: [],
            foregroundColor: fg,
            backgroundColor: bg
        )
        
        // Draw Menu Items
        var currentX = globalPos.x + 1
        
        for (index, menu) in menus.enumerated() {
            let text = " \(menu.title) "
            let isSelected = isMenuOpen && index == selectedMenuIndex
            
            // Highlight selected menu
            let menuFg: Color = isSelected ? .white : .black
            let menuBg: Color = isSelected ? .black : .white
            
            tui.drawString(
                row: globalPos.y,
                column: currentX,
                text: text,
                attributes: [],
                foregroundColor: menuFg,
                backgroundColor: menuBg
            )
            
            currentX += text.count
        }
        
        // Draw dropdown if menu is open
        if isMenuOpen && selectedMenuIndex < menus.count {
            drawDropdown(at: globalPos)
        }
    }
    
    @MainActor
    private func drawDropdown(at globalPos: Point) {
        let tui = SwiftyTermUI.shared
        let menu = menus[selectedMenuIndex]
        
        // Calculate dropdown position
        var dropdownX = globalPos.x + 1
        for i in 0..<selectedMenuIndex {
            dropdownX += menus[i].title.count + 2
        }
        let dropdownY = globalPos.y + 1
        
        // Calculate dropdown width (longest item + padding)
        var maxWidth = menu.title.count
        for item in menu.items {
            let itemWidth = item.title.count + (item.shortcut?.count ?? 0) + 4
            maxWidth = max(maxWidth, itemWidth)
        }
        maxWidth = max(maxWidth, 20) // Minimum width
        
        let dropdownHeight = menu.items.count + 2 // +2 for borders
        
        // Draw shadow
        tui.fillRect(
            row: dropdownY + 1,
            column: dropdownX + 1,
            width: maxWidth,
            height: dropdownHeight,
            character: " ",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .black
        )
        
        // Draw dropdown background
        tui.fillRect(
            row: dropdownY,
            column: dropdownX,
            width: maxWidth,
            height: dropdownHeight,
            character: " ",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        // Draw border (single line for dropdown)
        // Top
        tui.drawString(
            row: dropdownY,
            column: dropdownX,
            text: "┌" + String(repeating: "─", count: maxWidth - 2) + "┐",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        // Bottom
        tui.drawString(
            row: dropdownY + dropdownHeight - 1,
            column: dropdownX,
            text: "└" + String(repeating: "─", count: maxWidth - 2) + "┘",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        // Draw items
        for (index, item) in menu.items.enumerated() {
            let itemY = dropdownY + 1 + index
            
            if item.isSeparator {
                // Draw separator
                tui.drawString(
                    row: itemY,
                    column: dropdownX,
                    text: "├" + String(repeating: "─", count: maxWidth - 2) + "┤",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
            } else {
                // Draw left border
                tui.drawChar(
                    row: itemY,
                    column: dropdownX,
                    character: "│",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
                
                // Draw right border
                tui.drawChar(
                    row: itemY,
                    column: dropdownX + maxWidth - 1,
                    character: "│",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
                
                let isSelected = index == selectedItemIndex
                let itemFg: Color = isSelected ? .white : .black
                let itemBg: Color = isSelected ? .green : .white
                
                // Draw item text
                var itemText = " " + item.title
                if let shortcut = item.shortcut {
                    let padding = maxWidth - itemText.count - shortcut.count - 3
                    itemText += String(repeating: " ", count: padding) + shortcut + " "
                } else {
                    let padding = maxWidth - itemText.count - 2
                    itemText += String(repeating: " ", count: padding) + " "
                }
                
                tui.drawString(
                    row: itemY,
                    column: dropdownX + 1,
                    text: itemText,
                    attributes: [],
                    foregroundColor: itemFg,
                    backgroundColor: itemBg
                )
            }
        }
    }
    
    public override func handleEvent(_ event: TEvent) {
        switch event {
        case .key(let key):
            handleKeyEvent(key)
        default:
            break
        }
    }
    
    private func handleKeyEvent(_ key: Key) {
        // F10 to activate menu bar
        if key == .f10 && !isMenuOpen {
            isMenuOpen = true
            selectedMenuIndex = 0
            selectedItemIndex = 0
            return
        }
        
        if !isMenuOpen {
            return
        }
        
        switch key {
        case .escape:
            isMenuOpen = false
            
        case .left:
            selectedMenuIndex = (selectedMenuIndex - 1 + menus.count) % menus.count
            selectedItemIndex = 0
            
        case .right:
            selectedMenuIndex = (selectedMenuIndex + 1) % menus.count
            selectedItemIndex = 0
            
        case .up:
            let menu = menus[selectedMenuIndex]
            repeat {
                selectedItemIndex = (selectedItemIndex - 1 + menu.items.count) % menu.items.count
            } while menu.items[selectedItemIndex].isSeparator
            
        case .down:
            let menu = menus[selectedMenuIndex]
            repeat {
                selectedItemIndex = (selectedItemIndex + 1) % menu.items.count
            } while menu.items[selectedItemIndex].isSeparator
            
        case .enter:
            let menu = menus[selectedMenuIndex]
            let item = menu.items[selectedItemIndex]
            if !item.isSeparator {
                item.action?()
                isMenuOpen = false
            }
            
        default:
            break
        }
    }
}

