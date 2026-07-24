import SwiftyTermUI

public class TTabControl: TView {
    
    public private(set) var tabs: [TTab] = []
    
    private var _activeTabIndex: Int = 0
    
    public var activeTabIndex: Int {
        get { _activeTabIndex }
        set {
            guard !tabs.isEmpty else { return }
            let clamped = max(0, min(tabs.count - 1, newValue))
            guard clamped != _activeTabIndex else { return }
            _activeTabIndex = clamped
            updateTabVisibility()
            onTabChanged?(clamped)
        }
    }
    
    /// Called when the active tab changes.
    public var onTabChanged: ((Int) -> Void)?
    
    /// Height of the tab header area (top border + tabs + middle separator).
    public let headerHeight: Int = 3
    
    /// Indent before the first tab label.
    private let tabIndent: Int = 1
    
    /// Gap between consecutive tab slots.
    private let tabGap: Int = 2
    
    public override init(frame: Rect) {
        super.init(frame: frame)
    }
    
    /// Adds a tab page to the control.
    /// The tab's frame is automatically set to the content area.
    public func addTab(_ tab: TTab) {
        tabs.append(tab)
        tab.frame = contentRect
        addSubview(tab)
        
        if tabs.count == 1 {
            _activeTabIndex = 0
        }
        updateTabVisibility()
    }
    
    /// The content area inside the frame borders, in local coordinates.
    /// Accounts for the 3-row header, left/right ║ borders and bottom ╚═╝.
    public var contentRect: Rect {
        Rect(
            x: 1,
            y: headerHeight,
            width: max(0, frame.width - 2),
            height: max(0, frame.height - headerHeight - 1)
        )
    }
    
    // MARK: - Tab positions
    
    private struct TabPos {
        let x: Int      // label start in local coords
        let width: Int   // label width including padding spaces
    }
    
    private func computeTabPositions() -> [TabPos] {
        var positions: [TabPos] = []
        guard !tabs.isEmpty else { return positions }
        
        let availableWidth = max(0, frame.width - 2)
        let totalTitleWidth = tabs.reduce(0) { $0 + " \($1.title) ".count }
        let gapCount = max(1, tabs.count - 1)
        
        // If they exceed available width or there's only 1 tab, use a fixed gap
        if totalTitleWidth >= availableWidth || tabs.count == 1 {
            var x = tabIndent
            for tab in tabs {
                let label = " \(tab.title) "
                let w = label.count
                positions.append(TabPos(x: x, width: w))
                x += w + tabGap
            }
            return positions
        }
        
        // Distribute extra space evenly between tabs
        let extraSpace = availableWidth - totalTitleWidth
        let baseGap = extraSpace / gapCount
        let remainder = extraSpace % gapCount
        
        var x = 1 // Start at the left edge (cornerL = 0)
        for (index, tab) in tabs.enumerated() {
            let label = " \(tab.title) "
            let w = label.count
            positions.append(TabPos(x: x, width: w))
            // The last tab doesn't have a gap after it
            let currentGap = index < gapCount ? baseGap + (index < remainder ? 1 : 0) : 0
            x += w + currentGap
        }
        
        return positions
    }
    
    // MARK: - Drawing
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 3, frame.height > 3 else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        tui.pushClip(row: origin.y, column: origin.x, width: frame.width, height: frame.height)
        defer { tui.popClip() }
        let (contentFg, contentBg) = RetroTextUtils.resolvedContentColors(for: self)
        let borderFg: Color = (contentFg == .black) ? .brightWhite : .white
        
        let activeFg: Color = TTheme.current.tabActive.fg
        let activeBg: Color = TTheme.current.tabActive.bg
        
        layoutTabs()
        
        let positions = computeTabPositions()
        let lastRow = frame.height - 1
        let lastCol = frame.width - 1
        
        // 1. Fill entire background
        tui.fillRect(
            row: origin.y, column: origin.x,
            width: frame.width, height: frame.height,
            character: " ", attributes: [],
            foregroundColor: contentFg, backgroundColor: contentBg
        )
        
        // ── Row 0: Frame top border ╔════════╗ ────────────────
        tui.drawLine(
            fromRow: origin.y, fromColumn: origin.x,
            toRow: origin.y, toColumn: origin.x + lastCol,
            character: "═", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        tui.drawChar(
            row: origin.y, column: origin.x,
            character: "╔", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        tui.drawChar(
            row: origin.y, column: origin.x + lastCol,
            character: "╗", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        
        // ── Row 1: Tab Labels with side borders ║ ────────────
        tui.drawChar(
            row: origin.y + 1, column: origin.x,
            character: "║", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        
        for (index, tab) in tabs.enumerated() {
            guard index < positions.count else { continue }
            let pos = positions[index]
            let label = " \(tab.title) "
            
            let isSelected = (index == _activeTabIndex)
            let fg = isSelected ? activeFg : contentFg
            let bg = isSelected ? activeBg : contentBg
            
            let availableWidth = max(0, lastCol - pos.x)
            guard availableWidth > 0 else { continue }
            
            let clipped = String(label.prefix(availableWidth))
            tui.drawString(
                row: origin.y + 1, column: origin.x + pos.x,
                text: clipped, attributes: [],
                foregroundColor: fg, backgroundColor: bg
            )
        }
        
        tui.drawChar(
            row: origin.y + 1, column: origin.x + lastCol,
            character: "║", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        
        // ── Row 2: Middle separator ╠════════╣ ────────────────
        tui.drawLine(
            fromRow: origin.y + 2, fromColumn: origin.x,
            toRow: origin.y + 2, toColumn: origin.x + lastCol,
            character: "═", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        tui.drawChar(
            row: origin.y + 2, column: origin.x,
            character: "╠", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        tui.drawChar(
            row: origin.y + 2, column: origin.x + lastCol,
            character: "╣", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        
        // ── Rows 3…lastRow-1: Left & right borders ║ ───────────
        
        for row in headerHeight..<lastRow {
            tui.drawChar(
                row: origin.y + row, column: origin.x,
                character: "║", attributes: [],
                foregroundColor: borderFg, backgroundColor: contentBg
            )
            tui.drawChar(
                row: origin.y + row, column: origin.x + lastCol,
                character: "║", attributes: [],
                foregroundColor: borderFg, backgroundColor: contentBg
            )
        }
        
        // ── Last row: Bottom border ╚═══╝ ──────────────────────
        
        tui.drawChar(
            row: origin.y + lastRow, column: origin.x,
            character: "╚", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        if lastCol > 1 {
            tui.drawLine(
                fromRow: origin.y + lastRow, fromColumn: origin.x + 1,
                toRow: origin.y + lastRow, toColumn: origin.x + lastCol - 1,
                character: "═", attributes: [],
                foregroundColor: borderFg, backgroundColor: contentBg
            )
        }
        tui.drawChar(
            row: origin.y + lastRow, column: origin.x + lastCol,
            character: "╝", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        
        // ── Subviews (only active tab is visible) ──────────────
        
        for view in subviews {
            view.draw()
        }
    }
    
    // MARK: - Event Handling
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        switch event {
        case .mouse(let mouseEvent):
            handleMouseEvent(mouseEvent)
        default:
            // Route keyboard/command events ONLY to the active tab
            guard _activeTabIndex >= 0, _activeTabIndex < tabs.count else { return }
            tabs[_activeTabIndex].handleEvent(event)
        }
    }
    
    @MainActor
    public override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        // Clicks on the tab header row (1) switch tabs
        if event.action == .down, event.button == .left,
           event.position.y == 1 {
            return selectTabAtX(event.position.x)
        }
        return false
    }
    
    // MARK: - Private
    
    private func updateTabVisibility() {
        for (index, tab) in tabs.enumerated() {
            tab.isVisible = (index == _activeTabIndex)
        }
    }
    
    private func layoutTabs() {
        let rect = contentRect
        for tab in tabs {
            tab.frame = rect
        }
    }
    
    private func selectTabAtX(_ localX: Int) -> Bool {
        let positions = computeTabPositions()
        for (index, pos) in positions.enumerated() {
            // Hit area is just the label width
            let hitStart = pos.x
            let hitEnd = pos.x + pos.width - 1
            if localX >= hitStart && localX <= hitEnd {
                activeTabIndex = index
                return true
            }
        }
        return false
    }
}
