import SwiftyTermUI

public struct TMenuItem {
    public var title: String
    public var action: (() -> Void)?
    public var shortcut: String?
    public var submenu: [TMenuItem]?
    public var isSeparator: Bool
    
    public init(title: String, action: (() -> Void)? = nil, shortcut: String? = nil) {
        self.title = title
        self.action = action
        self.shortcut = shortcut
        self.submenu = nil
        self.isSeparator = false
    }
    
    public init(title: String, shortcut: String? = nil, submenu: [TMenuItem]) {
        self.title = title
        self.action = nil
        self.shortcut = shortcut
        self.submenu = submenu
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
    
    // State for submenu
    private var isSubmenuOpen: Bool = false
    private var selectedSubmenuItemIndex: Int = 0
    
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
        
        let dropdownLayout = menuLayout(for: menu.items, originX: dropdownX, originY: dropdownY)
        
        // Draw shadow
        tui.fillRect(
            row: dropdownLayout.y + 1,
            column: dropdownLayout.x + 1,
            width: dropdownLayout.width + 1,
            height: dropdownLayout.height,
            character: " ",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .black
        )
        
        // Draw dropdown background
        tui.fillRect(
            row: dropdownLayout.y,
            column: dropdownLayout.x,
            width: dropdownLayout.width,
            height: dropdownLayout.height,
            character: " ",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        // Draw border (single line for dropdown)
        // Top
        tui.drawString(
            row: dropdownLayout.y,
            column: dropdownLayout.x,
            text: "┌" + String(repeating: "─", count: dropdownLayout.width - 2) + "┐",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        // Bottom
        tui.drawString(
            row: dropdownLayout.y + dropdownLayout.height - 1,
            column: dropdownLayout.x,
            text: "└" + String(repeating: "─", count: dropdownLayout.width - 2) + "┘",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        let selectedBg: Color = .indexed(22)
        
        // Draw items
        for (index, item) in menu.items.enumerated() {
            let itemY = dropdownLayout.y + 1 + index
            
            if item.isSeparator {
                // Draw separator
                tui.drawString(
                    row: itemY,
                    column: dropdownLayout.x,
                    text: "├" + String(repeating: "─", count: dropdownLayout.width - 2) + "┤",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
            } else {
                // Draw left border
                tui.drawChar(
                    row: itemY,
                    column: dropdownLayout.x,
                    character: "│",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
                
                // Draw right border
                tui.drawChar(
                    row: itemY,
                    column: dropdownLayout.x + dropdownLayout.width - 1,
                    character: "│",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
                
                let isSelected = index == selectedItemIndex
                let itemFg: Color = isSelected ? .white : .black
                let itemBg: Color = isSelected ? selectedBg : .white
                
                let itemText = buildItemLine(item, contentWidth: dropdownLayout.width - 2)
                
                tui.drawString(
                    row: itemY,
                    column: dropdownLayout.x + 1,
                    text: itemText,
                    attributes: [],
                    foregroundColor: itemFg,
                    backgroundColor: itemBg
                )
            }
        }
        
        if isSubmenuOpen, let submenuItems = currentSubmenuItems() {
            let submenuLayout = submenuLayout(for: submenuItems, parentLayout: dropdownLayout, parentIndex: selectedItemIndex)
            drawSubmenu(submenuItems, layout: submenuLayout, selectedIndex: selectedSubmenuItemIndex)
        }
    }
    
    public override func handleEvent(_ event: TEvent) {
        switch event {
        case .key(let key):
            if handleKeyEvent(key) {
                return
            }
        case .mouse(let mouseEvent):
            let handled = handleMouseEvent(mouseEvent)
            // If menu bar handled the event, don't pass it to super
            if handled {
                return
            }
        default:
            break
        }
        
        super.handleEvent(event)
    }
    
    @discardableResult
    public override func handleMouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard isVisible else { return false }
        
        // Menu bar is at (0, 0), so global coordinates should match local coordinates
        // But use globalToLocal to be safe in case menu bar is moved in the future
        let localPoint = globalToLocal(event.position)
        
        // Check if click is within menu bar bounds
        // Menu bar is at global position (0, 0), so local coordinates should match global for y=0
        // But we also need to handle dropdown clicks which are below the menu bar
        let isInMenuBarRow = event.position.y == 0 && event.position.x >= 0 && event.position.x < frame.width
        let isInBounds = bounds.contains(localPoint)
        
        // Also check if click might be in dropdown (if menu is open)
        var mightBeInDropdown = false
        if isMenuOpen && event.position.y > 0, let dropdownLayout = currentDropdownLayout() {
            mightBeInDropdown = event.position.x >= dropdownLayout.x && event.position.x < dropdownLayout.x + dropdownLayout.width &&
                                event.position.y >= dropdownLayout.y && event.position.y < dropdownLayout.y + dropdownLayout.height
        }
        
        // Also check if click might be in submenu
        var mightBeInSubmenu = false
        if isSubmenuOpen, let submenuItems = currentSubmenuItems(), let dropdownLayout = currentDropdownLayout() {
            let submenuLayout = submenuLayout(for: submenuItems, parentLayout: dropdownLayout, parentIndex: selectedItemIndex)
            mightBeInSubmenu = event.position.x >= submenuLayout.x && event.position.x < submenuLayout.x + submenuLayout.width &&
                               event.position.y >= submenuLayout.y && event.position.y < submenuLayout.y + submenuLayout.height
        }
        
        guard isInMenuBarRow || isInBounds || mightBeInDropdown || mightBeInSubmenu else {
            // If menu is open and click is outside, close it
            if isMenuOpen {
                isMenuOpen = false
                isSubmenuOpen = false
                return true // Event handled (menu closed)
            }
            return false // Event not handled by menu bar
        }
        
        // Handle clicks on menu items
        switch event.action {
        case .down where event.button == .left:
            // If click is inside submenu, trigger submenu item
            if isSubmenuOpen, let submenuItems = currentSubmenuItems(), let dropdownLayout = currentDropdownLayout() {
                let submenuLayout = submenuLayout(for: submenuItems, parentLayout: dropdownLayout, parentIndex: selectedItemIndex)
                if event.position.x >= submenuLayout.x && event.position.x < submenuLayout.x + submenuLayout.width &&
                   event.position.y >= submenuLayout.y && event.position.y < submenuLayout.y + submenuLayout.height {
                    let itemIndex = event.position.y - submenuLayout.y - 1
                    if itemIndex >= 0 && itemIndex < submenuItems.count {
                        let item = submenuItems[itemIndex]
                        if !item.isSeparator {
                            item.action?()
                            isSubmenuOpen = false
                            isMenuOpen = false
                        }
                    }
                    return true
                }
            }
            
            // First check if click is in dropdown (if menu is open)
            if isMenuOpen, let dropdownLayout = currentDropdownLayout() {
                if event.position.x >= dropdownLayout.x && event.position.x < dropdownLayout.x + dropdownLayout.width &&
                   event.position.y >= dropdownLayout.y && event.position.y < dropdownLayout.y + dropdownLayout.height {
                    
                    // Calculate which item was clicked
                    let itemIndex = event.position.y - dropdownLayout.y - 1
                    let menu = menus[selectedMenuIndex]
                    if itemIndex >= 0 && itemIndex < menu.items.count {
                        let item = menu.items[itemIndex]
                        if !item.isSeparator {
                            selectedItemIndex = itemIndex
                            if let submenu = item.submenu, !submenu.isEmpty {
                                openSubmenuIfAvailable()
                            } else {
                                item.action?()
                                isSubmenuOpen = false
                                isMenuOpen = false
                            }
                        }
                    }
                    return true // Event handled
                }
            }
            
            // If not in dropdown, check if click is on menu bar items
            var currentX = 1 // Start after left edge
            for (index, menu) in menus.enumerated() {
                let text = " \(menu.title) "
                let menuStartX = currentX
                let menuEndX = currentX + text.count
                
                if localPoint.x >= menuStartX && localPoint.x < menuEndX {
                    // Menu clicked
                    if isMenuOpen && selectedMenuIndex == index {
                        // Same menu clicked again - close it
                        isMenuOpen = false
                        isSubmenuOpen = false
                    } else {
                        // Open this menu
                        isMenuOpen = true
                        selectedMenuIndex = index
                        selectedItemIndex = firstSelectableIndex(in: menu.items)
                        isSubmenuOpen = false
                    }
                    return true // Event handled
                }
                
                currentX = menuEndX
            }
            return true // Click was in menu bar area, even if not on a menu item
            
        default:
            break
        }
        
        return false // Event not handled
    }
    
    @MainActor
    private func handleKeyEvent(_ key: Key) -> Bool {
        // F10 to activate menu bar
        if key == .f10 && !isMenuOpen {
            isMenuOpen = true
            selectedMenuIndex = 0
            selectedItemIndex = firstSelectableIndex(in: menus[0].items)
            isSubmenuOpen = false
            return true
        }
        
        if !isMenuOpen {
            return false
        }
        
        switch key {
        case .escape:
            if isSubmenuOpen {
                isSubmenuOpen = false
            } else {
                isMenuOpen = false
            }
            return true
        case .left:
            if isSubmenuOpen {
                isSubmenuOpen = false
            } else {
                selectedMenuIndex = (selectedMenuIndex - 1 + menus.count) % menus.count
                selectedItemIndex = firstSelectableIndex(in: menus[selectedMenuIndex].items)
            }
            return true
        case .right:
            if openSubmenuIfAvailable() {
                return true
            }
            selectedMenuIndex = (selectedMenuIndex + 1) % menus.count
            selectedItemIndex = firstSelectableIndex(in: menus[selectedMenuIndex].items)
            isSubmenuOpen = false
            return true
        case .up:
            if isSubmenuOpen, let submenuItems = currentSubmenuItems() {
                selectedSubmenuItemIndex = moveSelection(in: submenuItems, from: selectedSubmenuItemIndex, direction: -1)
            } else {
                let menu = menus[selectedMenuIndex]
                selectedItemIndex = moveSelection(in: menu.items, from: selectedItemIndex, direction: -1)
                isSubmenuOpen = false
            }
            return true
        case .down:
            if isSubmenuOpen, let submenuItems = currentSubmenuItems() {
                selectedSubmenuItemIndex = moveSelection(in: submenuItems, from: selectedSubmenuItemIndex, direction: 1)
            } else {
                let menu = menus[selectedMenuIndex]
                selectedItemIndex = moveSelection(in: menu.items, from: selectedItemIndex, direction: 1)
                isSubmenuOpen = false
            }
            return true
        case .enter:
            if isSubmenuOpen, let submenuItems = currentSubmenuItems() {
                let item = submenuItems[selectedSubmenuItemIndex]
                if !item.isSeparator {
                    item.action?()
                    isSubmenuOpen = false
                    isMenuOpen = false
                }
            } else {
                let menu = menus[selectedMenuIndex]
                let item = menu.items[selectedItemIndex]
                if !item.isSeparator {
                    if !openSubmenuIfAvailable() {
                        item.action?()
                        isMenuOpen = false
                    }
                }
            }
            return true
        default:
            return true
        }
    }
    
    private struct MenuLayout {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }
    
    @MainActor
    private func buildItemLine(_ item: TMenuItem, contentWidth: Int) -> String {
        guard contentWidth > 0 else { return "" }
        
        var chars = Array(repeating: Character(" "), count: contentWidth)
        let indicatorWidth = (item.submenu?.isEmpty == false) ? 1 : 0
        let shortcut = item.shortcut ?? ""
        let shortcutWidth = shortcut.count
        let rightReserved = indicatorWidth + (shortcutWidth > 0 ? shortcutWidth + 1 : 0)
        let titleAvailable = max(0, contentWidth - rightReserved - 1)
        let titleText = String(item.title.prefix(titleAvailable))
        
        for (i, ch) in titleText.enumerated() {
            let idx = 1 + i
            if idx >= 0 && idx < contentWidth {
                chars[idx] = ch
            }
        }
        
        if shortcutWidth > 0 {
            let shortcutStart = max(0, contentWidth - indicatorWidth - shortcutWidth)
            let spaceIndex = shortcutStart - 1
            if spaceIndex >= 0 && spaceIndex < contentWidth {
                chars[spaceIndex] = " "
            }
            for (i, ch) in shortcut.enumerated() {
                let idx = shortcutStart + i
                if idx >= 0 && idx < contentWidth {
                    chars[idx] = ch
                }
            }
        }
        
        if indicatorWidth > 0, contentWidth > 0 {
            chars[contentWidth - 1] = ">"
        }
        
        return String(chars)
    }
    
    @MainActor
    private func menuLayout(for items: [TMenuItem], originX: Int, originY: Int) -> MenuLayout {
        let (columns, rows) = SwiftyTermUI.shared.getTerminalSize()
        var maxWidth = 20
        for item in items {
            let submenuExtra = (item.submenu?.isEmpty == false) ? 2 : 0
            let itemWidth = item.title.count + (item.shortcut?.count ?? 0) + 4 + submenuExtra
            maxWidth = max(maxWidth, itemWidth)
        }
        let availableWidth = max(4, columns - originX)
        let width = max(4, min(maxWidth, availableWidth))
        let height = items.count + 2
        let maxY = max(0, rows - height)
        let y = max(0, min(originY, maxY))
        return MenuLayout(x: originX, y: y, width: width, height: height)
    }
    
    @MainActor
    private func submenuLayout(for items: [TMenuItem], parentLayout: MenuLayout, parentIndex: Int) -> MenuLayout {
        var originX = parentLayout.x + parentLayout.width
        let originY = parentLayout.y + 1 + parentIndex
        let (columns, _) = SwiftyTermUI.shared.getTerminalSize()
        var layout = menuLayout(for: items, originX: originX, originY: originY)
        if originX + layout.width > columns {
            originX = max(0, parentLayout.x - layout.width)
            layout = menuLayout(for: items, originX: originX, originY: originY)
        }
        return layout
    }
    
    @MainActor
    private func drawSubmenu(_ items: [TMenuItem], layout: MenuLayout, selectedIndex: Int) {
        let tui = SwiftyTermUI.shared
        let selectedBg: Color = .indexed(22)
        
        tui.fillRect(
            row: layout.y + 1,
            column: layout.x + 1,
            width: layout.width + 1,
            height: layout.height,
            character: " ",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .black
        )
        
        tui.fillRect(
            row: layout.y,
            column: layout.x,
            width: layout.width,
            height: layout.height,
            character: " ",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        tui.drawString(
            row: layout.y,
            column: layout.x,
            text: "┌" + String(repeating: "─", count: layout.width - 2) + "┐",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        tui.drawString(
            row: layout.y + layout.height - 1,
            column: layout.x,
            text: "└" + String(repeating: "─", count: layout.width - 2) + "┘",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .white
        )
        
        for (index, item) in items.enumerated() {
            let itemY = layout.y + 1 + index
            if item.isSeparator {
                tui.drawString(
                    row: itemY,
                    column: layout.x,
                    text: "├" + String(repeating: "─", count: layout.width - 2) + "┤",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
            } else {
                tui.drawChar(
                    row: itemY,
                    column: layout.x,
                    character: "│",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
                tui.drawChar(
                    row: itemY,
                    column: layout.x + layout.width - 1,
                    character: "│",
                    attributes: [],
                    foregroundColor: .black,
                    backgroundColor: .white
                )
                
                let isSelected = index == selectedIndex
                let itemFg: Color = isSelected ? .white : .black
                let itemBg: Color = isSelected ? selectedBg : .white
                let itemText = buildItemLine(item, contentWidth: layout.width - 2)
                
                tui.drawString(
                    row: itemY,
                    column: layout.x + 1,
                    text: itemText,
                    attributes: [],
                    foregroundColor: itemFg,
                    backgroundColor: itemBg
                )
            }
        }
    }
    
    @MainActor
    private func currentDropdownLayout() -> MenuLayout? {
        guard isMenuOpen, selectedMenuIndex < menus.count else { return nil }
        let globalPos = localToGlobal(Point(x: 0, y: 0))
        var dropdownX = globalPos.x + 1
        for i in 0..<selectedMenuIndex {
            dropdownX += menus[i].title.count + 2
        }
        let dropdownY = globalPos.y + 1
        return menuLayout(for: menus[selectedMenuIndex].items, originX: dropdownX, originY: dropdownY)
    }
    
    @MainActor
    private func currentSubmenuItems() -> [TMenuItem]? {
        guard selectedMenuIndex < menus.count else { return nil }
        let menu = menus[selectedMenuIndex]
        guard selectedItemIndex >= 0 && selectedItemIndex < menu.items.count else { return nil }
        return menu.items[selectedItemIndex].submenu
    }
    
    @discardableResult
    @MainActor
    private func openSubmenuIfAvailable() -> Bool {
        guard let submenuItems = currentSubmenuItems(), !submenuItems.isEmpty else {
            isSubmenuOpen = false
            return false
        }
        isSubmenuOpen = true
        selectedSubmenuItemIndex = firstSelectableIndex(in: submenuItems)
        return true
    }
    
    @MainActor
    private func firstSelectableIndex(in items: [TMenuItem]) -> Int {
        for (index, item) in items.enumerated() {
            if !item.isSeparator {
                return index
            }
        }
        return 0
    }
    
    @MainActor
    private func moveSelection(in items: [TMenuItem], from index: Int, direction: Int) -> Int {
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
}

