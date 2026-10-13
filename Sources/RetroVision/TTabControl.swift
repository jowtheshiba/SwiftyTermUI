import SwiftyTermUI

public class TTabControl: TGroup {
    public private(set) var tabs: [TTab] = []
    public let headerHeight: Int = 3
    public var onTabChanged: ((Int) -> Void)?

    private var _activeTabIndex: Int = 0
    private let tabIndent: Int = 1
    private let tabGap: Int = 0

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

    public var contentRect: Rect {
        Rect(
            x: 1,
            y: headerHeight,
            width: max(0, frame.width - 2),
            height: max(0, frame.height - headerHeight - 1)
        )
    }

    public override init(frame: Rect) {
        super.init(frame: frame)
    }

    public func addTab(_ tab: TTab) {
        tabs.append(tab)
        tab.frame = contentRect
        addSubview(tab)
        if tabs.count == 1 {
            _activeTabIndex = 0
        }
        updateTabVisibility()
    }

    @MainActor
    public override func draw() {
        guard isVisible, frame.width > 3, frame.height > 3 else { return }

        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let contentColors = RetroTextUtils.resolvedContentColors(for: self)
        let borderColor: Color = contentColors.fg == .black ? .brightWhite : .white
        let positions = computeTabPositions()

        tui.pushClip(row: origin.y, column: origin.x, width: frame.width, height: frame.height)
        defer { tui.popClip() }

        layoutTabs()
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: contentColors.fg,
            backgroundColor: contentColors.bg
        )

        drawContentFrame(at: origin, foreground: borderColor, background: contentColors.bg)

        for index in tabs.indices where index != _activeTabIndex && index < positions.count {
            drawInactiveTab(
                tabs[index],
                position: positions[index],
                at: origin,
                foreground: borderColor,
                background: contentColors.bg
            )
        }

        if tabs.indices.contains(_activeTabIndex), positions.indices.contains(_activeTabIndex) {
            drawActiveTab(
                tabs[_activeTabIndex],
                position: positions[_activeTabIndex],
                at: origin,
                foreground: borderColor,
                background: contentColors.bg
            )
        }

        for view in subviews {
            view.draw()
        }
    }

    @MainActor
    public override func handleEvent(_ event: TEvent) {
        switch event {
        case .mouse(let mouseEvent):
            _ = handleMouseEvent(mouseEvent)
        default:
            guard tabs.indices.contains(_activeTabIndex) else { return }
            tabs[_activeTabIndex].handleEvent(event)
        }
    }

    @MainActor
    public override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard event.action == .down,
              event.button == .left,
              event.position.y >= 0,
              event.position.y < 2 else { return false }
        return selectTab(at: event.position)
    }

    private struct TabPosition {
        let x: Int
        let width: Int
    }

    private func computeTabPositions() -> [TabPosition] {
        var positions: [TabPosition] = []
        var x = tabIndent
        for tab in tabs {
            let width = max(4, tab.title.count + 4)
            positions.append(TabPosition(x: x, width: width))
            x += width + tabGap
        }
        return positions
    }

    @MainActor
    private func drawContentFrame(at origin: Point, foreground: Color, background: Color) {
        let tui = SwiftyTermUI.shared
        let top = origin.y + headerHeight - 1
        let bottom = origin.y + frame.height - 1
        let left = origin.x
        let right = origin.x + frame.width - 1

        tui.drawLine(
            fromRow: top,
            fromColumn: left + 1,
            toRow: top,
            toColumn: right - 1,
            character: "─",
            attributes: [],
            foregroundColor: foreground,
            backgroundColor: background
        )
        tui.drawChar(row: top, column: left, character: "┌", attributes: [], foregroundColor: foreground, backgroundColor: background)
        tui.drawChar(row: top, column: right, character: "┐", attributes: [], foregroundColor: foreground, backgroundColor: background)

        if bottom > top + 1 {
            tui.drawLine(
                fromRow: top + 1,
                fromColumn: left,
                toRow: bottom - 1,
                toColumn: left,
                character: "│",
                attributes: [],
                foregroundColor: foreground,
                backgroundColor: background
            )
            tui.drawLine(
                fromRow: top + 1,
                fromColumn: right,
                toRow: bottom - 1,
                toColumn: right,
                character: "│",
                attributes: [],
                foregroundColor: foreground,
                backgroundColor: background
            )
        }

        tui.drawLine(
            fromRow: bottom,
            fromColumn: left + 1,
            toRow: bottom,
            toColumn: right - 1,
            character: "─",
            attributes: [],
            foregroundColor: foreground,
            backgroundColor: background
        )
        tui.drawChar(row: bottom, column: left, character: "└", attributes: [], foregroundColor: foreground, backgroundColor: background)
        tui.drawChar(row: bottom, column: right, character: "┘", attributes: [], foregroundColor: foreground, backgroundColor: background)
    }

    @MainActor
    private func drawActiveTab(
        _ tab: TTab,
        position: TabPosition,
        at origin: Point,
        foreground: Color,
        background: Color
    ) {
        let tui = SwiftyTermUI.shared
        let left = origin.x + position.x
        let right = min(origin.x + frame.width - 2, left + position.width - 1)
        guard right > left else { return }

        if right > left + 1 {
            tui.drawLine(
                fromRow: origin.y,
                fromColumn: left + 1,
                toRow: origin.y,
                toColumn: right - 1,
                character: "─",
                attributes: [],
                foregroundColor: foreground,
                backgroundColor: background
            )
        }
        tui.drawChar(row: origin.y, column: left, character: "┌", attributes: [], foregroundColor: foreground, backgroundColor: background)
        tui.drawChar(row: origin.y, column: right, character: "┐", attributes: [], foregroundColor: foreground, backgroundColor: background)
        tui.drawChar(row: origin.y + 1, column: left, character: "│", attributes: [], foregroundColor: foreground, backgroundColor: background)
        tui.drawChar(row: origin.y + 1, column: right, character: "│", attributes: [], foregroundColor: foreground, backgroundColor: background)

        let innerWidth = max(0, right - left - 1)
        if innerWidth > 0 {
            tui.fillRect(
                row: origin.y + 1,
                column: left + 1,
                width: innerWidth,
                height: 1,
                character: " ",
                attributes: [],
                foregroundColor: foreground,
                backgroundColor: background
            )
            let label = centered(tab.title, width: innerWidth)
            let active = TTheme.current.tabActive
            tui.drawString(
                row: origin.y + 1,
                column: left + 1,
                text: label,
                attributes: [],
                foregroundColor: active.fg,
                backgroundColor: active.bg
            )
        }

        let separatorRow = origin.y + headerHeight - 1
        tui.drawChar(row: separatorRow, column: left, character: "┘", attributes: [], foregroundColor: foreground, backgroundColor: background)
        if right > left + 1 {
            tui.fillRect(
                row: separatorRow,
                column: left + 1,
                width: right - left - 1,
                height: 1,
                character: " ",
                attributes: [],
                foregroundColor: foreground,
                backgroundColor: background
            )
        }
        tui.drawChar(row: separatorRow, column: right, character: "└", attributes: [], foregroundColor: foreground, backgroundColor: background)
    }

    @MainActor
    private func drawInactiveTab(
        _ tab: TTab,
        position: TabPosition,
        at origin: Point,
        foreground: Color,
        background: Color
    ) {
        let tui = SwiftyTermUI.shared
        let inactive = TTheme.current.tabInactive
        let top = origin.y
        let labelRow = origin.y + 1
        let left = origin.x + position.x
        let right = min(origin.x + frame.width - 2, left + position.width - 1)
        guard right > left else { return }

        if right > left + 1 {
            tui.drawLine(
                fromRow: top,
                fromColumn: left + 1,
                toRow: top,
                toColumn: right - 1,
                character: "─",
                attributes: [],
                foregroundColor: foreground,
                backgroundColor: inactive.bg
            )
            tui.fillRect(
                row: labelRow,
                column: left + 1,
                width: right - left - 1,
                height: 1,
                character: " ",
                attributes: [],
                foregroundColor: inactive.fg,
                backgroundColor: inactive.bg
            )
            let label = centered(tab.title, width: right - left - 1)
            tui.drawString(
                row: labelRow,
                column: left + 1,
                text: label,
                attributes: [],
                foregroundColor: inactive.fg,
                backgroundColor: inactive.bg
            )
        }

        tui.drawChar(row: top, column: left, character: "┌", attributes: [], foregroundColor: foreground, backgroundColor: inactive.bg)
        tui.drawChar(row: top, column: right, character: "┐", attributes: [], foregroundColor: foreground, backgroundColor: inactive.bg)
        tui.drawChar(row: labelRow, column: left, character: "│", attributes: [], foregroundColor: foreground, backgroundColor: inactive.bg)
        tui.drawChar(row: labelRow, column: right, character: "│", attributes: [], foregroundColor: foreground, backgroundColor: inactive.bg)
        let separatorRow = origin.y + headerHeight - 1
        tui.drawChar(row: separatorRow, column: left, character: "┴", attributes: [], foregroundColor: foreground, backgroundColor: background)
        tui.drawChar(row: separatorRow, column: right, character: "┴", attributes: [], foregroundColor: foreground, backgroundColor: background)
    }

    private func centered(_ text: String, width: Int) -> String {
        let clipped = RetroTextUtils.clampText(text, maxWidth: width)
        let padding = max(0, width - clipped.count)
        let left = padding / 2
        return String(repeating: " ", count: left) + clipped + String(repeating: " ", count: padding - left)
    }

    private func updateTabVisibility() {
        for (index, tab) in tabs.enumerated() {
            tab.isVisible = index == _activeTabIndex
        }
    }

    private func layoutTabs() {
        let rect = contentRect
        for tab in tabs {
            tab.frame = rect
        }
    }

    private func selectTab(at point: Point) -> Bool {
        let positions = computeTabPositions()
        for (index, position) in positions.enumerated() {
            if point.y < 2, point.x >= position.x, point.x < position.x + position.width {
                activeTabIndex = index
                return true
            }
        }
        return false
    }
}
