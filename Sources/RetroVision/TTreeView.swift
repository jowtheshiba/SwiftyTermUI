import SwiftyTermUI

public final class TTreeNode {
    public var title: String
    public var representedObject: Any?
    public var isExpanded: Bool
    public private(set) var children: [TTreeNode]
    public private(set) var isLoaded: Bool

    private var childrenProvider: (() -> [TTreeNode])?

    public var hasChildren: Bool {
        !children.isEmpty || (!isLoaded && childrenProvider != nil)
    }

    public init(
        title: String,
        representedObject: Any? = nil,
        children: [TTreeNode] = [],
        isExpanded: Bool = false,
        childrenProvider: (() -> [TTreeNode])? = nil
    ) {
        self.title = title
        self.representedObject = representedObject
        self.children = children
        self.isExpanded = isExpanded
        self.childrenProvider = childrenProvider
        self.isLoaded = childrenProvider == nil || !children.isEmpty
    }

    @discardableResult
    public func loadChildrenIfNeeded() -> [TTreeNode] {
        guard !isLoaded else { return children }
        children = childrenProvider?() ?? []
        childrenProvider = nil
        isLoaded = true
        return children
    }

    public func setChildren(_ children: [TTreeNode]) {
        self.children = children
        childrenProvider = nil
        isLoaded = true
    }

    public func addChild(_ child: TTreeNode) {
        if !isLoaded {
            _ = loadChildrenIfNeeded()
        }
        children.append(child)
    }

    public func removeAllChildren() {
        children.removeAll()
        childrenProvider = nil
        isLoaded = true
        isExpanded = false
    }
}

open class TTreeView: TView {
    public override var canFocus: Bool { true }
    public override var consumesEnterKey: Bool { true }

    public var roots: [TTreeNode] {
        didSet { reload() }
    }
    public var selectedIndex: Int {
        get { selection }
        set { setSelection(newValue) }
    }
    public var selectedNode: TTreeNode? {
        entries.indices.contains(selection) ? entries[selection].node : nil
    }
    public var visibleNodes: [TTreeNode] {
        entries.map(\.node)
    }
    public var onSelectionChange: ((TTreeNode) -> Void)?
    public var onActivate: ((TTreeNode) -> Void)?
    public var onExpand: ((TTreeNode) -> Void)?
    public var onCollapse: ((TTreeNode) -> Void)?
    public weak var scrollBar: TScrollBar? {
        didSet {
            configureScrollBar()
            syncScrollBar()
        }
    }

    private struct Entry {
        let node: TTreeNode
        let parent: TTreeNode?
        let depth: Int
        let isLast: Bool
        let ancestorIsLast: [Bool]
    }

    private var entries: [Entry] = []
    private var selection: Int
    private var topIndex: Int = 0

    public init(frame: Rect, roots: [TTreeNode] = [], selectedIndex: Int = 0) {
        self.roots = roots
        self.selection = selectedIndex
        super.init(frame: frame)
        rebuildEntries()
        selection = clampedSelection(selection)
        ensureSelectionVisible()
    }

    public func reload() {
        let selected = selectedNode
        let oldIndex = selection
        rebuildEntries()
        if let selected, let index = entries.firstIndex(where: { $0.node === selected }) {
            selection = index
        } else {
            selection = clampedSelection(oldIndex)
        }
        ensureSelectionVisible()
        syncScrollBar()
    }

    public func expand(_ node: TTreeNode) {
        guard node.hasChildren else { return }
        _ = node.loadChildrenIfNeeded()
        guard !node.children.isEmpty else {
            reload()
            return
        }
        let changed = !node.isExpanded
        node.isExpanded = true
        reload()
        if changed {
            onExpand?(node)
        }
    }

    public func collapse(_ node: TTreeNode) {
        guard node.isExpanded else { return }
        node.isExpanded = false
        reload()
        onCollapse?(node)
    }

    public func toggle(_ node: TTreeNode) {
        if node.isExpanded {
            collapse(node)
        } else {
            expand(node)
        }
    }

    public func activateSelectedNode() {
        guard let selectedNode else { return }
        onActivate?(selectedNode)
    }

    @MainActor
    open override func draw() {
        guard isVisible, frame.width > 0, frame.height > 0 else { return }

        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let theme = TTheme.current
        let content = RetroTextUtils.resolvedContentColors(for: self)

        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: content.fg,
            backgroundColor: content.bg
        )

        for row in 0..<frame.height {
            let index = topIndex + row
            guard entries.indices.contains(index) else { continue }
            let entry = entries[index]
            let colors = index == selection
                ? theme.listSelection
                : TColorPair(fg: content.fg, bg: content.bg)

            tui.fillRect(
                row: origin.y + row,
                column: origin.x,
                width: frame.width,
                height: 1,
                character: " ",
                attributes: [],
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
            )

            let prefix = prefix(for: entry)
            let disclosure: String
            if entry.node.hasChildren {
                disclosure = entry.node.isExpanded ? "▾ " : "▸ "
            } else {
                disclosure = "  "
            }
            let text = RetroTextUtils.clampText(prefix + disclosure + entry.node.title, maxWidth: frame.width)

            tui.drawString(
                row: origin.y + row,
                column: origin.x,
                text: text,
                attributes: [],
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
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
        let index = topIndex + event.position.y
        guard entries.indices.contains(index) else { return true }
        setSelection(index)

        let entry = entries[index]
        let disclosureColumn = entry.depth * 2
        if event.position.x >= disclosureColumn, event.position.x < disclosureColumn + 2, entry.node.hasChildren {
            toggle(entry.node)
        } else if event.clickCount > 1 {
            activateSelectedNode()
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

    private func rebuildEntries() {
        entries.removeAll(keepingCapacity: true)
        var path: Set<ObjectIdentifier> = []
        append(nodes: roots, parent: nil, depth: 0, ancestorIsLast: [], path: &path)
    }

    private func append(
        nodes: [TTreeNode],
        parent: TTreeNode?,
        depth: Int,
        ancestorIsLast: [Bool],
        path: inout Set<ObjectIdentifier>
    ) {
        for (index, node) in nodes.enumerated() {
            let identity = ObjectIdentifier(node)
            guard !path.contains(identity) else { continue }
            let isLast = index == nodes.count - 1
            entries.append(Entry(
                node: node,
                parent: parent,
                depth: depth,
                isLast: isLast,
                ancestorIsLast: ancestorIsLast
            ))
            guard node.isExpanded else { continue }
            _ = node.loadChildrenIfNeeded()
            path.insert(identity)
            append(
                nodes: node.children,
                parent: node,
                depth: depth + 1,
                ancestorIsLast: ancestorIsLast + [isLast],
                path: &path
            )
            path.remove(identity)
        }
    }

    private func prefix(for entry: Entry) -> String {
        guard entry.depth > 0 else { return "" }
        var result = ""
        for isLast in entry.ancestorIsLast.dropLast() {
            result += isLast ? "  " : "│ "
        }
        result += entry.isLast ? "└─" : "├─"
        return result
    }

    private func setSelection(_ value: Int) {
        let next = clampedSelection(value)
        let changed = next != selection
        selection = next
        ensureSelectionVisible()
        syncScrollBar()
        if changed, let selectedNode {
            onSelectionChange?(selectedNode)
        }
    }

    private func clampedSelection(_ value: Int) -> Int {
        guard !entries.isEmpty else { return 0 }
        return max(0, min(value, entries.count - 1))
    }

    private func ensureSelectionVisible() {
        let visibleCount = max(1, frame.height)
        if selection < topIndex {
            topIndex = selection
        } else if selection >= topIndex + visibleCount {
            topIndex = selection - visibleCount + 1
        }
        topIndex = max(0, min(topIndex, max(0, entries.count - visibleCount)))
    }

    private func handleKey(_ key: Key) -> Bool {
        switch key {
        case .up:
            selectedIndex -= 1
        case .down:
            selectedIndex += 1
        case .pageUp:
            selectedIndex -= max(1, frame.height)
        case .pageDown:
            selectedIndex += max(1, frame.height)
        case .home:
            selectedIndex = 0
        case .end:
            selectedIndex = max(0, entries.count - 1)
        case .left:
            moveLeft()
        case .right:
            moveRight()
        case .character(" "):
            if let selectedNode, selectedNode.hasChildren {
                toggle(selectedNode)
            }
        case .enter:
            activateSelectedNode()
        default:
            return false
        }
        return true
    }

    private func moveLeft() {
        guard entries.indices.contains(selection) else { return }
        let entry = entries[selection]
        if entry.node.isExpanded {
            collapse(entry.node)
        } else if let parent = entry.parent,
                  let index = entries.firstIndex(where: { $0.node === parent }) {
            setSelection(index)
        }
    }

    private func moveRight() {
        guard entries.indices.contains(selection) else { return }
        let node = entries[selection].node
        if node.hasChildren, !node.isExpanded {
            expand(node)
        } else if node.isExpanded,
                  let index = entries.firstIndex(where: { $0.parent === node }) {
            setSelection(index)
        }
    }

    private func configureScrollBar() {
        scrollBar?.onChange = { [weak self] value in
            self?.scrollTo(value)
        }
    }

    private func syncScrollBar() {
        scrollBar?.totalItems = entries.count
        scrollBar?.pageSize = frame.height
        scrollBar?.value = topIndex
    }

    private func scrollTo(_ value: Int) {
        topIndex = max(0, min(value, max(0, entries.count - frame.height)))
    }
}
