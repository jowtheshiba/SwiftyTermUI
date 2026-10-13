import SwiftyTermUI

public enum TTableColumnWidth: Equatable, Sendable {
    case fixed(Int)
    case flexible
}

public enum TTableAlignment: Equatable, Sendable {
    case left
    case center
    case right
}

public struct TTableColumn: Equatable, Sendable {
    public var title: String
    public var width: TTableColumnWidth
    public var alignment: TTableAlignment

    public init(
        title: String,
        width: TTableColumnWidth = .flexible,
        alignment: TTableAlignment = .left
    ) {
        self.title = title
        self.width = width
        self.alignment = alignment
    }
}

public struct TTableRow: Equatable, Sendable {
    public var cells: [String]

    public init(_ cells: [String]) {
        self.cells = cells
    }
}

open class TTableView: TView {
    public override var canFocus: Bool { true }
    public override var consumesEnterKey: Bool { true }

    public var columns: [TTableColumn] {
        didSet {
            ensureSelectionVisible()
            syncScrollBar()
        }
    }
    public var rows: [TTableRow] {
        didSet {
            selection = clampedSelection(selection)
            ensureSelectionVisible()
            syncScrollBar()
        }
    }
    public var selectedIndex: Int {
        get { selection }
        set { setSelection(newValue) }
    }
    public var selectedRow: TTableRow? {
        rows.indices.contains(selectedIndex) ? rows[selectedIndex] : nil
    }
    public var showsHeader: Bool = true {
        didSet {
            ensureSelectionVisible()
            syncScrollBar()
        }
    }
    public var columnSeparator: Character? = nil
    public var onSelectionChange: ((Int, TTableRow) -> Void)?
    public var onActivate: ((Int, TTableRow) -> Void)?
    public weak var scrollBar: TScrollBar? {
        didSet {
            configureScrollBar()
            syncScrollBar()
        }
    }

    private var selection: Int
    private var topIndex: Int = 0

    public init(
        frame: Rect,
        columns: [TTableColumn],
        rows: [TTableRow] = [],
        selectedIndex: Int = 0
    ) {
        self.columns = columns
        self.rows = rows
        self.selection = selectedIndex
        super.init(frame: frame)
        selection = clampedSelection(selection)
        ensureSelectionVisible()
    }

    public func activateSelectedRow() {
        guard let row = selectedRow else { return }
        onActivate?(selectedIndex, row)
    }

    @MainActor
    open override func draw() {
        guard isVisible, frame.width > 0, frame.height > 0 else { return }

        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let theme = TTheme.current
        let contentColors = RetroTextUtils.resolvedContentColors(for: self)
        let widths = resolvedColumnWidths()

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

        var drawingRow = 0
        if showsHeader, frame.height > 0 {
            tui.fillRect(
                row: origin.y,
                column: origin.x,
                width: frame.width,
                height: 1,
                character: " ",
                attributes: [],
                foregroundColor: theme.tableHeader.fg,
                backgroundColor: theme.tableHeader.bg
            )
            drawCells(
                columns.map(\.title),
                widths: widths,
                row: origin.y,
                originX: origin.x,
                colors: theme.tableHeader,
                alignments: columns.map(\.alignment)
            )
            drawingRow = 1
        }

        let visibleRows = max(0, frame.height - drawingRow)
        for offset in 0..<visibleRows {
            let index = topIndex + offset
            let selected = index == selectedIndex && rows.indices.contains(index)
            let colors = selected ? theme.listSelection : TColorPair(fg: contentColors.fg, bg: contentColors.bg)
            let cells = rows.indices.contains(index) ? rows[index].cells : []
            tui.fillRect(
                row: origin.y + drawingRow + offset,
                column: origin.x,
                width: frame.width,
                height: 1,
                character: " ",
                attributes: [],
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
            )
            drawCells(
                cells,
                widths: widths,
                row: origin.y + drawingRow + offset,
                originX: origin.x,
                colors: colors,
                alignments: columns.map(\.alignment)
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

        let rowOffset = event.position.y - headerHeight
        guard rowOffset >= 0 else { return true }
        let index = topIndex + rowOffset
        guard rows.indices.contains(index) else { return true }
        setSelection(index)
        if event.clickCount > 1 {
            activateSelectedRow()
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
        guard case .integer(let index) = data else { return false }
        selectedIndex = index
        return true
    }

    open override func sizeChanged(from oldSize: Rect) {
        ensureSelectionVisible()
        syncScrollBar()
    }

    private var headerHeight: Int {
        showsHeader && frame.height > 0 ? 1 : 0
    }

    private var visibleRowCount: Int {
        max(0, frame.height - headerHeight)
    }

    @MainActor
    private func drawCells(
        _ cells: [String],
        widths: [Int],
        row: Int,
        originX: Int,
        colors: TColorPair,
        alignments: [TTableAlignment]
    ) {
        let tui = SwiftyTermUI.shared
        var column = originX

        for index in columns.indices {
            let width = widths[index]
            if width > 0 {
                let value = cells.indices.contains(index) ? cells[index] : ""
                let text = formatted(value, width: width, alignment: alignments[index])
                tui.drawString(
                    row: row,
                    column: column,
                    text: text,
                    attributes: [],
                    foregroundColor: colors.fg,
                    backgroundColor: colors.bg
                )
                column += width
            }

            if index < columns.count - 1, column < originX + frame.width {
                let separator = columnSeparator ?? " "
                tui.drawChar(
                    row: row,
                    column: column,
                    character: separator,
                    attributes: [],
                    foregroundColor: colors.fg,
                    backgroundColor: colors.bg
                )
                column += 1
            }
        }
    }

    private func resolvedColumnWidths() -> [Int] {
        guard !columns.isEmpty else { return [] }
        let separatorsWidth = max(0, columns.count - 1)
        let availableWidth = max(0, frame.width - separatorsWidth)
        let fixedWidth = columns.reduce(0) { result, column in
            if case .fixed(let width) = column.width {
                return result + max(0, width)
            }
            return result
        }
        let flexibleCount = columns.reduce(0) { result, column in
            column.width == .flexible ? result + 1 : result
        }
        let flexibleSpace = max(0, availableWidth - fixedWidth)
        let baseFlexibleWidth = flexibleCount > 0 ? flexibleSpace / flexibleCount : 0
        var remainder = flexibleCount > 0 ? flexibleSpace % flexibleCount : 0

        let desiredWidths = columns.map { column in
            switch column.width {
            case .fixed(let width):
                return max(0, width)
            case .flexible:
                let width = baseFlexibleWidth + (remainder > 0 ? 1 : 0)
                remainder = max(0, remainder - 1)
                return width
            }
        }

        var remaining = availableWidth
        return desiredWidths.map { width in
            let resolved = min(width, remaining)
            remaining -= resolved
            return resolved
        }
    }

    private func formatted(_ value: String, width: Int, alignment: TTableAlignment) -> String {
        guard width > 0 else { return "" }
        let text = RetroTextUtils.clampText(value, maxWidth: width)
        let padding = max(0, width - text.count)
        switch alignment {
        case .left:
            return text + String(repeating: " ", count: padding)
        case .center:
            let left = padding / 2
            return String(repeating: " ", count: left) + text + String(repeating: " ", count: padding - left)
        case .right:
            return String(repeating: " ", count: padding) + text
        }
    }

    private func setSelection(_ value: Int) {
        let next = clampedSelection(value)
        let changed = next != selection
        selection = next
        ensureSelectionVisible()
        syncScrollBar()
        if changed, let row = selectedRow {
            onSelectionChange?(selection, row)
        }
    }

    private func clampedSelection(_ value: Int) -> Int {
        guard !rows.isEmpty else { return 0 }
        return max(0, min(value, rows.count - 1))
    }

    private func ensureSelectionVisible() {
        let count = visibleRowCount
        guard count > 0 else {
            topIndex = 0
            return
        }
        if selectedIndex < topIndex {
            topIndex = selectedIndex
        } else if selectedIndex >= topIndex + count {
            topIndex = selectedIndex - count + 1
        }
        topIndex = max(0, min(topIndex, max(0, rows.count - count)))
    }

    private func handleKey(_ key: Key) -> Bool {
        switch key {
        case .up:
            selectedIndex -= 1
        case .down:
            selectedIndex += 1
        case .pageUp:
            selectedIndex -= max(1, visibleRowCount)
        case .pageDown:
            selectedIndex += max(1, visibleRowCount)
        case .home:
            selectedIndex = 0
        case .end:
            selectedIndex = max(0, rows.count - 1)
        case .enter:
            activateSelectedRow()
        default:
            return false
        }
        return true
    }

    private func configureScrollBar() {
        scrollBar?.onChange = { [weak self] value in
            self?.scrollTo(value)
        }
    }

    private func syncScrollBar() {
        scrollBar?.totalItems = rows.count
        scrollBar?.pageSize = visibleRowCount
        scrollBar?.value = topIndex
    }

    private func scrollTo(_ value: Int) {
        topIndex = max(0, min(value, max(0, rows.count - visibleRowCount)))
    }
}
