import SwiftyTermUI

open class TListViewer: TView {
    public override var canFocus: Bool { true }
    public override var consumesEnterKey: Bool { true }

    public var collection: TCollection<String> {
        didSet { reloadCollection() }
    }
    public var selectedIndex: Int {
        get { selection }
        set {
            selection = clampedSelection(newValue)
            ensureSelectionVisible()
            syncScrollBar()
        }
    }
    public var focused: Int {
        get { selectedIndex }
        set { selectedIndex = newValue }
    }
    public private(set) var range: Int
    public var onSelect: ((Int, String) -> Void)?
    public weak var scrollBar: TScrollBar? {
        didSet {
            configureScrollBar()
            syncScrollBar()
        }
    }

    private var selection: Int
    private var topIndex: Int = 0

    public init(frame: Rect, collection: TCollection<String> = TCollection(), selectedIndex: Int = 0) {
        self.collection = collection
        self.range = collection.count
        self.selection = selectedIndex
        super.init(frame: frame)
        clampSelection()
        ensureSelectionVisible()
    }

    open func itemText(at index: Int) -> String {
        collection.at(index) ?? ""
    }

    open func getText(at index: Int) -> String {
        itemText(at: index)
    }

    open func setNeedsDisplay() {}

    public func reloadCollection() {
        range = collection.count
        clampSelection()
        ensureSelectionVisible()
        syncScrollBar()
    }

    public func setRange(_ range: Int) {
        self.range = max(0, min(range, collection.count))
        clampSelection()
        ensureSelectionVisible()
        syncScrollBar()
    }

    public func focusItem(_ index: Int) {
        selectedIndex = index
    }

    public func selectItem(_ index: Int) {
        selectedIndex = index
        if selectedIndex < range, let item = collection.at(selectedIndex) {
            onSelect?(selectedIndex, item)
        }
    }

    public func newList(_ collection: TCollection<String>) {
        self.collection = collection
    }

    @MainActor
    open override func draw() {
        guard isVisible, frame.width > 0, frame.height > 0 else { return }

        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let fg: Color = TTheme.current.control.fg
        let bg: Color = TTheme.current.control.bg
        let selectedFg: Color = TTheme.current.listSelection.fg
        let selectedBg: Color = TTheme.current.listSelection.bg

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

        for row in 0..<frame.height {
            let index = topIndex + row
            let text = index < range ? getText(at: index) : ""
            let display = padRight(RetroTextUtils.clampText(text, maxWidth: frame.width), to: frame.width)
            let selected = index == selectedIndex

            tui.drawString(
                row: origin.y + row,
                column: origin.x,
                text: display,
                attributes: [],
                foregroundColor: selected ? selectedFg : fg,
                backgroundColor: selected ? selectedBg : bg
            )
        }
    }

    @MainActor
    open override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event, isFocused, handleKey(key) {
            return
        }
        super.handleEvent(event)
    }

    @MainActor
    open override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard event.action == .down, event.button == .left, bounds.contains(event.position) else { return false }
        RetroTextUtils.focus(view: self)
        let row = max(0, min(frame.height - 1, event.position.y))
        let index = topIndex + row
        if index < range {
            selectedIndex = index
        }
        return true
    }

    @MainActor
    open override var dataSize: Int { 1 }

    @MainActor
    open override func getData() -> TViewData? {
        .integer(selectedIndex)
    }

    @MainActor
    @discardableResult
    open override func setData(_ data: TViewData) -> Bool {
        switch data {
        case .integer(let index):
            selectedIndex = index
            return true
        case .text(let text):
            guard let index = collection.elements.prefix(range).firstIndex(where: { $0 == text }) else { return false }
            selectedIndex = index
            return true
        default:
            return false
        }
    }

    private func handleKey(_ key: Key) -> Bool {
        switch key {
        case .up:
            moveSelection(delta: -1)
        case .down:
            moveSelection(delta: 1)
        case .pageUp:
            moveSelection(delta: -frame.height)
        case .pageDown:
            moveSelection(delta: frame.height)
        case .home:
            selectedIndex = 0
        case .end:
            selectedIndex = max(0, range - 1)
        case .enter:
            selectItem(selectedIndex)
        default:
            return false
        }
        return true
    }

    private func moveSelection(delta: Int) {
        guard range > 0 else { return }
        selectedIndex += delta
    }

    private func clampSelection() {
        selection = clampedSelection(selection)
    }

    private func clampedSelection(_ value: Int) -> Int {
        guard range > 0 else { return 0 }
        return max(0, min(value, range - 1))
    }

    private func ensureSelectionVisible() {
        let visibleCount = max(1, frame.height)
        if selectedIndex < topIndex {
            topIndex = selectedIndex
        } else if selectedIndex >= topIndex + visibleCount {
            topIndex = max(0, selectedIndex - visibleCount + 1)
        }
        topIndex = min(topIndex, max(0, range - visibleCount))
    }

    private func configureScrollBar() {
        scrollBar?.onChange = { [weak self] value in
            self?.scrollTo(value)
        }
    }

    private func syncScrollBar() {
        scrollBar?.totalItems = range
        scrollBar?.pageSize = frame.height
        scrollBar?.value = topIndex
    }

    private func scrollTo(_ value: Int) {
        let maximum = max(0, range - frame.height)
        topIndex = max(0, min(value, maximum))
    }

    private func padRight(_ text: String, to width: Int) -> String {
        guard text.count < width else { return text }
        return text + String(repeating: " ", count: width - text.count)
    }
}
