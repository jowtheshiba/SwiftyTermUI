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
    
    /// Height of the tab header area (tab top border + tab body/labels + frame top border).
    public let headerHeight: Int = 3
    
    /// Indent before the first tab label.
    private let tabIndent: Int = 3
    
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
        var x = tabIndent
        for tab in tabs {
            let label = " \(tab.title) "
            positions.append(TabPos(x: x, width: label.count))
            x += label.count + tabGap
        }
        return positions
    }
    
    // MARK: - Drawing
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 3, frame.height > 4 else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let (contentFg, contentBg) = RetroTextUtils.resolvedContentColors(for: self)
        let borderFg: Color = (contentFg == .black) ? .brightWhite : .white
        
        let activeFg: Color = .black
        let activeBg: Color = contentBg
        
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
        
        // ── Row 0: Active tab top border ╔═══╗ ─────────────────
        
        if _activeTabIndex >= 0 && _activeTabIndex < positions.count {
            let pos = positions[_activeTabIndex]
            let cornerL = pos.x - 1
            let cornerR = pos.x + pos.width
            
            // ╔
            if cornerL >= 0 && cornerL <= lastCol {
                tui.drawChar(
                    row: origin.y, column: origin.x + cornerL,
                    character: "╔", attributes: [],
                    foregroundColor: borderFg, backgroundColor: activeBg
                )
            }
            // ═══ fill between corners
            let fillStart = max(pos.x, 0)
            let fillEnd = min(pos.x + pos.width, lastCol + 1)
            for col in fillStart..<fillEnd {
                tui.drawChar(
                    row: origin.y, column: origin.x + col,
                    character: "═", attributes: [],
                    foregroundColor: borderFg, backgroundColor: activeBg
                )
            }
            // ╗
            if cornerR >= 0 && cornerR <= lastCol {
                tui.drawChar(
                    row: origin.y, column: origin.x + cornerR,
                    character: "╗", attributes: [],
                    foregroundColor: borderFg, backgroundColor: activeBg
                )
            }
        }
        
        // ── Row 1: Active tab body ║ Label ║ + inactive labels ──
        
        if _activeTabIndex >= 0 && _activeTabIndex < positions.count {
            let pos = positions[_activeTabIndex]
            let label = " \(tabs[_activeTabIndex].title) "
            let cornerL = pos.x - 1
            let cornerR = pos.x + pos.width
            
            // ║ left wall
            if cornerL >= 0 && cornerL <= lastCol {
                tui.drawChar(
                    row: origin.y + 1, column: origin.x + cornerL,
                    character: "║", attributes: [],
                    foregroundColor: borderFg, backgroundColor: activeBg
                )
            }
            // Label inside the tab body
            let clipped = String(label.prefix(max(0, lastCol - pos.x + 1)))
            tui.drawString(
                row: origin.y + 1, column: origin.x + pos.x,
                text: clipped, attributes: [],
                foregroundColor: activeFg, backgroundColor: activeBg
            )
            // ║ right wall
            if cornerR >= 0 && cornerR <= lastCol {
                tui.drawChar(
                    row: origin.y + 1, column: origin.x + cornerR,
                    character: "║", attributes: [],
                    foregroundColor: borderFg, backgroundColor: activeBg
                )
            }
        }
        
        // Inactive tab labels on row 1 (same height as active label)
        for (index, tab) in tabs.enumerated() {
            guard index != _activeTabIndex, index < positions.count else { continue }
            let pos = positions[index]
            let label = " \(tab.title) "
            let clipped = String(label.prefix(max(0, lastCol - pos.x + 1)))
            tui.drawString(
                row: origin.y + 1, column: origin.x + pos.x,
                text: clipped, attributes: [],
                foregroundColor: contentFg, backgroundColor: contentBg
            )
        }
        
        // ── Row 2: Frame top border ╔═╝ … ╚═══╗ ────────────────
        
        // Full ═ line
        tui.drawLine(
            fromRow: origin.y + 2, fromColumn: origin.x,
            toRow: origin.y + 2, toColumn: origin.x + lastCol,
            character: "═", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        // Frame corners
        tui.drawChar(
            row: origin.y + 2, column: origin.x,
            character: "╔", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        tui.drawChar(
            row: origin.y + 2, column: origin.x + lastCol,
            character: "╗", attributes: [],
            foregroundColor: borderFg, backgroundColor: contentBg
        )
        
        // Active tab break — tab opens into the content frame
        if _activeTabIndex >= 0 && _activeTabIndex < positions.count {
            let pos = positions[_activeTabIndex]
            let cornerL = pos.x - 1
            let cornerR = pos.x + pos.width
            
            // ╝ — left junction (or ║ when tab meets the frame edge)
            if cornerL > 0 && cornerL < lastCol {
                tui.drawChar(
                    row: origin.y + 2, column: origin.x + cornerL,
                    character: "╝", attributes: [],
                    foregroundColor: borderFg, backgroundColor: contentBg
                )
            } else if cornerL == 0 {
                // Tab's left wall merges with the frame's left border
                tui.drawChar(
                    row: origin.y + 2, column: origin.x,
                    character: "║", attributes: [],
                    foregroundColor: borderFg, backgroundColor: contentBg
                )
            }
            // Gap (tab merges into content)
            let gapStart = max(pos.x, 1)
            let gapEnd = min(pos.x + pos.width, lastCol)
            for col in gapStart..<gapEnd {
                tui.drawChar(
                    row: origin.y + 2, column: origin.x + col,
                    character: " ", attributes: [],
                    foregroundColor: contentFg, backgroundColor: contentBg
                )
            }
            // ╚ — right junction (or ║ when tab meets the frame edge)
            if cornerR > 0 && cornerR < lastCol {
                tui.drawChar(
                    row: origin.y + 2, column: origin.x + cornerR,
                    character: "╚", attributes: [],
                    foregroundColor: borderFg, backgroundColor: contentBg
                )
            } else if cornerR == lastCol {
                // Tab's right wall merges with the frame's right border
                tui.drawChar(
                    row: origin.y + 2, column: origin.x + cornerR,
                    character: "║", attributes: [],
                    foregroundColor: borderFg, backgroundColor: contentBg
                )
            }
        }
        
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
    public override func mouseEvent(_ event: TEvent.MouseEvent) {
        // Clicks on the header rows (0, 1, or 2) switch tabs
        if event.action == .down, event.button == .left,
           event.position.y >= 0, event.position.y <= 2 {
            selectTabAtX(event.position.x)
        }
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
    
    private func selectTabAtX(_ localX: Int) {
        let positions = computeTabPositions()
        for (index, pos) in positions.enumerated() {
            // Hit area includes ║ walls on each side
            let hitStart = pos.x - 1
            let hitEnd = pos.x + pos.width
            if localX >= hitStart && localX <= hitEnd {
                activeTabIndex = index
                return
            }
        }
    }
}
