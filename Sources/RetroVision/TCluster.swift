import SwiftyTermUI

public struct TClusterItem: Equatable, Sendable {
    public var title: String
    public var isEnabled: Bool

    public init(_ title: String, isEnabled: Bool = true) {
        self.title = title
        self.isEnabled = isEnabled
    }
}

public typealias TSItem = TClusterItem

open class TCluster: TView {
    public override var canFocus: Bool { true }
    public override var consumesEnterKey: Bool { true }

    public var items: [TClusterItem] {
        didSet {
            selectedIndex = clampedIndex(selectedIndex)
            value = value
        }
    }
    public var columnCount: Int
    public var selectedIndex: Int {
        get { selection }
        set { selection = clampedIndex(newValue) }
    }
    public var value: Int {
        get { storedValue }
        set {
            let normalized = normalizedValue(newValue)
            if normalized != storedValue {
                storedValue = normalized
                onChange?(normalized)
            }
        }
    }
    public var onChange: ((Int) -> Void)?

    private var selection: Int
    private var storedValue: Int

    public init(frame: Rect, items: [TClusterItem], value: Int = 0, columnCount: Int = 1) {
        self.items = items
        self.columnCount = max(1, columnCount)
        self.selection = 0
        self.storedValue = value
        super.init(frame: frame)
        options.insert(.preProcess)
        selection = clampedIndex(selection)
        storedValue = normalizedValue(storedValue)
    }

    open func normalizedValue(_ value: Int) -> Int {
        value
    }

    open func marker(for index: Int) -> String {
        "[ ]"
    }

    open func activateItem(at index: Int) {
        selectedIndex = index
    }

    @MainActor
    open override func draw() {
        guard isVisible, frame.width > 0, frame.height > 0 else { return }

        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let normal = RetroTextUtils.resolvedContentColors(for: self)
        let selected = TTheme.current.listSelection

        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: normal.fg,
            backgroundColor: normal.bg
        )

        for index in items.indices {
            let position = itemPosition(index)
            guard position.y < frame.height else { continue }
            let parsed = RetroTextUtils.parseHotKey(items[index].title)
            let available = max(0, columnWidth - 4)
            let title = RetroTextUtils.clampText(parsed.displayText, maxWidth: available)
            let text = marker(for: index) + " " + title
            let focused = isFocused && index == selectedIndex
            let foreground = focused ? selected.fg : normal.fg
            let background = focused ? selected.bg : normal.bg

            tui.drawString(
                row: origin.y + position.y,
                column: origin.x + position.x,
                text: RetroTextUtils.clampText(text, maxWidth: columnWidth),
                attributes: [],
                foregroundColor: foreground,
                backgroundColor: background
            )

            if let underlineIndex = parsed.underlineIndex {
                let offset = 4 + underlineIndex
                if offset < columnWidth, offset < text.count {
                    let characterIndex = text.index(text.startIndex, offsetBy: offset)
                    tui.drawChar(
                        row: origin.y + position.y,
                        column: origin.x + position.x + offset,
                        character: text[characterIndex],
                        attributes: [.underline],
                        foregroundColor: foreground,
                        backgroundColor: background
                    )
                }
            }
        }
    }

    @MainActor
    open override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event, handleKey(key) {
            return
        }
        super.handleEvent(event)
    }

    @MainActor
    open override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard event.action == .down, event.button == .left, bounds.contains(event.position) else { return false }
        guard let index = itemIndex(at: event.position), items[index].isEnabled else { return true }
        RetroTextUtils.focus(view: self)
        activateItem(at: index)
        return true
    }

    @MainActor
    open override var dataSize: Int { 1 }

    @MainActor
    open override func getData() -> TViewData? {
        .integer(value)
    }

    @MainActor
    @discardableResult
    open override func setData(_ data: TViewData) -> Bool {
        guard case .integer(let value) = data else { return false }
        self.value = value
        return true
    }

    private var rowsPerColumn: Int {
        max(1, (items.count + max(1, columnCount) - 1) / max(1, columnCount))
    }

    private var columnWidth: Int {
        max(1, frame.width / max(1, columnCount))
    }

    private func itemPosition(_ index: Int) -> Point {
        Point(x: index / rowsPerColumn * columnWidth, y: index % rowsPerColumn)
    }

    private func itemIndex(at point: Point) -> Int? {
        let column = min(max(0, point.x / columnWidth), max(0, columnCount - 1))
        let index = column * rowsPerColumn + point.y
        return items.indices.contains(index) ? index : nil
    }

    @MainActor
    private func handleKey(_ key: Key) -> Bool {
        if case .alt(let character) = key, let index = hotKeyIndex(for: character) {
            RetroTextUtils.focus(view: self)
            activateItem(at: index)
            return true
        }

        guard isFocused else { return false }
        switch key {
        case .up:
            moveSelection(by: -1)
        case .down:
            moveSelection(by: 1)
        case .left:
            moveSelection(by: -rowsPerColumn)
        case .right:
            moveSelection(by: rowsPerColumn)
        case .home:
            selectFirstEnabled()
        case .end:
            selectLastEnabled()
        case .enter, .character(" "):
            if items.indices.contains(selectedIndex), items[selectedIndex].isEnabled {
                activateItem(at: selectedIndex)
            }
        default:
            return false
        }
        return true
    }

    private func hotKeyIndex(for character: Character) -> Int? {
        let key = String(character).lowercased().first
        return items.indices.first { index in
            items[index].isEnabled && RetroTextUtils.parseHotKey(items[index].title).hotKey == key
        }
    }

    private func moveSelection(by offset: Int) {
        guard !items.isEmpty else { return }
        var index = selectedIndex
        for _ in items.indices {
            index = (index + offset % items.count + items.count) % items.count
            if items[index].isEnabled {
                selectedIndex = index
                return
            }
        }
    }

    private func selectFirstEnabled() {
        if let index = items.firstIndex(where: \.isEnabled) {
            selectedIndex = index
        }
    }

    private func selectLastEnabled() {
        if let index = items.lastIndex(where: \.isEnabled) {
            selectedIndex = index
        }
    }

    private func clampedIndex(_ index: Int) -> Int {
        guard !items.isEmpty else { return 0 }
        return max(0, min(index, items.count - 1))
    }
}

public final class TCheckBoxes: TCluster {
    public override func normalizedValue(_ value: Int) -> Int {
        let bitCount = min(items.count, Int.bitWidth - 1)
        guard bitCount > 0 else { return 0 }
        return value & ((1 << bitCount) - 1)
    }

    public override func marker(for index: Int) -> String {
        guard index < Int.bitWidth - 1 else { return "[ ]" }
        return value & (1 << index) == 0 ? "[ ]" : "[X]"
    }

    public override func activateItem(at index: Int) {
        guard items.indices.contains(index), items[index].isEnabled, index < Int.bitWidth - 1 else { return }
        selectedIndex = index
        value ^= 1 << index
    }

    public func isChecked(_ index: Int) -> Bool {
        guard items.indices.contains(index), index < Int.bitWidth - 1 else { return false }
        return value & (1 << index) != 0
    }
}

public final class TRadioButtons: TCluster {
    public override func normalizedValue(_ value: Int) -> Int {
        guard !items.isEmpty else { return 0 }
        return max(0, min(value, items.count - 1))
    }

    public override func marker(for index: Int) -> String {
        value == index ? "(●)" : "( )"
    }

    public override func activateItem(at index: Int) {
        guard items.indices.contains(index), items[index].isEnabled else { return }
        selectedIndex = index
        value = index
    }
}
