import SwiftyTermUI

public class TListBox: TView {
    public var items: [String] {
        didSet {
            if selectedIndex >= items.count {
                selectedIndex = max(0, items.count - 1)
            }
            ensureSelectionVisible()
            syncScrollBar()
        }
    }
    public private(set) var selectedIndex: Int
    public var onSelect: ((Int, String) -> Void)?
    
    public weak var scrollBar: TScrollBar? {
        didSet {
            configureScrollBar()
            syncScrollBar()
        }
    }
    
    private var topIndex: Int = 0
    
    public init(frame: Rect, items: [String] = [], selectedIndex: Int = 0) {
        self.items = items
        self.selectedIndex = selectedIndex
        super.init(frame: frame)
        clampSelection()
        ensureSelectionVisible()
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 0, frame.height > 0 else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        
        let fg: Color = .black
        let bg: Color = .indexed(30)
        let selFg: Color = .brightWhite
        let selBg: Color = .green
        
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: fg,
            backgroundColor: bg
        )
        
        let visibleCount = frame.height
        for row in 0..<visibleCount {
            let itemIndex = topIndex + row
            let lineText = itemIndex < items.count ? items[itemIndex] : ""
            let display = padRight(RetroTextUtils.clampText(lineText, maxWidth: frame.width), to: frame.width)
            let isSelected = itemIndex == selectedIndex
            
            tui.drawString(
                row: origin.y + row,
                column: origin.x,
                text: display,
                attributes: [],
                foregroundColor: isSelected ? selFg : fg,
                backgroundColor: isSelected ? selBg : bg
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
        guard bounds.contains(event.position) else { return }
        RetroTextUtils.focus(view: self)
        
        let row = max(0, min(frame.height - 1, event.position.y))
        let index = topIndex + row
        if index >= 0 && index < items.count {
            selectedIndex = index
            ensureSelectionVisible()
            syncScrollBar()
        }
    }
    
    // MARK: - Private
    
    private func handleKey(_ key: Key) -> Bool {
        switch key {
        case .up:
            moveSelection(delta: -1)
            return true
        case .down:
            moveSelection(delta: 1)
            return true
        case .pageUp:
            moveSelection(delta: -frame.height)
            return true
        case .pageDown:
            moveSelection(delta: frame.height)
            return true
        case .home:
            selectedIndex = 0
            ensureSelectionVisible()
            syncScrollBar()
            return true
        case .end:
            selectedIndex = max(0, items.count - 1)
            ensureSelectionVisible()
            syncScrollBar()
            return true
        case .enter:
            if selectedIndex >= 0 && selectedIndex < items.count {
                onSelect?(selectedIndex, items[selectedIndex])
            }
            return true
        default:
            return false
        }
    }
    
    private func moveSelection(delta: Int) {
        guard !items.isEmpty else { return }
        selectedIndex = max(0, min(items.count - 1, selectedIndex + delta))
        ensureSelectionVisible()
        syncScrollBar()
    }
    
    private func clampSelection() {
        if items.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = max(0, min(selectedIndex, items.count - 1))
        }
    }
    
    private func ensureSelectionVisible() {
        let visibleCount = max(1, frame.height)
        if selectedIndex < topIndex {
            topIndex = selectedIndex
        } else if selectedIndex >= topIndex + visibleCount {
            topIndex = max(0, selectedIndex - visibleCount + 1)
        }
    }
    
    private func configureScrollBar() {
        scrollBar?.onChange = { [weak self] value in
            self?.scrollTo(value)
        }
    }
    
    private func syncScrollBar() {
        scrollBar?.totalItems = items.count
        scrollBar?.pageSize = frame.height
        scrollBar?.value = topIndex
    }
    
    private func scrollTo(_ value: Int) {
        let maxTop = max(0, items.count - frame.height)
        topIndex = max(0, min(value, maxTop))
    }
    
    private func padRight(_ text: String, to width: Int) -> String {
        if text.count >= width {
            return text
        }
        return text + String(repeating: " ", count: width - text.count)
    }
}
