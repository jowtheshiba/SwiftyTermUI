import SwiftyTermUI

@MainActor
public enum THistoryList {
    public static var maximumEntriesPerID = 32
    private static var storage: [Int: [String]] = [:]

    public static func add(_ value: String, id: Int) {
        guard !value.isEmpty, maximumEntriesPerID > 0 else { return }
        var entries = storage[id] ?? []
        entries.removeAll { $0 == value }
        entries.insert(value, at: 0)
        if entries.count > maximumEntriesPerID {
            entries.removeLast(entries.count - maximumEntriesPerID)
        }
        storage[id] = entries
    }

    public static func entries(for id: Int) -> [String] {
        storage[id] ?? []
    }

    public static func count(for id: Int) -> Int {
        storage[id]?.count ?? 0
    }

    public static func string(for id: Int, at index: Int) -> String? {
        guard let entries = storage[id], entries.indices.contains(index) else { return nil }
        return entries[index]
    }

    public static func clear(_ id: Int? = nil) {
        if let id {
            storage[id] = nil
        } else {
            storage.removeAll()
        }
    }
}

@MainActor
public func historyAdd(_ id: Int, _ value: String) {
    THistoryList.add(value, id: id)
}

@MainActor
public func historyCount(_ id: Int) -> Int {
    THistoryList.count(for: id)
}

@MainActor
public func historyStr(_ id: Int, _ index: Int) -> String? {
    THistoryList.string(for: id, at: index)
}

@MainActor
public func clearHistory(_ id: Int? = nil) {
    THistoryList.clear(id)
}

@MainActor
public final class THistoryViewer: TListBox {
    public let historyID: Int
    public weak var target: TInputLine?
    public var onChoose: ((String) -> Void)?

    public init(frame: Rect, target: TInputLine? = nil, historyID: Int) {
        self.target = target
        self.historyID = historyID
        super.init(frame: frame, items: THistoryList.entries(for: historyID))
        onSelect = { [weak self] _, value in
            self?.apply(value)
        }
    }

    public func refreshHistory() {
        items = THistoryList.entries(for: historyID)
    }

    public func choose(_ index: Int) {
        selectItem(index)
    }

    private func apply(_ value: String) {
        target?.text = value
        target?.cursorPosition = value.count
        target?.clearSelection()
        onChoose?(value)
    }
}

@MainActor
public final class THistoryWindow: TDialog {
    public init(frame: Rect, viewer: THistoryViewer) {
        super.init(frame: frame, title: "History")
        allowClosing = false
        viewer.frame = Rect(x: 1, y: 1, width: max(1, frame.width - 2), height: max(1, frame.height - 2))
        addSubview(viewer)
    }

    public override func handleMouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        if event.action == .down, !contains(globalPoint: event.position) {
            _ = endModal(.cancel, validating: false)
            return true
        }
        return super.handleMouseEvent(event)
    }
}

@MainActor
public final class THistory: TView {
    public override var canFocus: Bool { true }
    public override var consumesEnterKey: Bool { true }

    public weak var target: TInputLine?
    public let historyID: Int

    public init(frame: Rect, target: TInputLine, historyID: Int) {
        self.target = target
        self.historyID = historyID
        super.init(frame: frame)
        target.historyID = historyID
    }

    public override func draw() {
        guard isVisible, frame.width > 0, frame.height > 0 else { return }
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let foreground = isFocused ? TTheme.current.buttonFocusedText : TTheme.current.button.fg
        let background = TTheme.current.button.bg

        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: foreground,
            backgroundColor: background
        )
        tui.drawChar(
            row: origin.y + (frame.height - 1) / 2,
            column: origin.x + (frame.width - 1) / 2,
            character: "▼",
            attributes: [],
            foregroundColor: foreground,
            backgroundColor: background
        )
    }

    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event, isFocused, key == .enter || key == .character(" ") {
            openHistory()
            return
        }
        super.handleEvent(event)
    }

    public override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard event.action == .down, event.button == .left, bounds.contains(event.position) else { return false }
        RetroTextUtils.focus(view: self)
        openHistory()
        return true
    }

    public func openHistory() {
        guard let target, !THistoryList.entries(for: historyID).isEmpty else { return }
        var root: TView = self
        while let parent = root.superview {
            root = parent
        }
        guard let desktop = root as? TDesktop, let application = desktop.application else { return }

        let targetFrame = target.globalFrame
        let width = min(desktop.frame.width, max(12, targetFrame.width + 2))
        let height = min(desktop.frame.height, max(3, min(10, THistoryList.count(for: historyID) + 2)))
        let x = max(0, min(targetFrame.x - 1, desktop.frame.width - width))
        let preferredY = targetFrame.y + targetFrame.height
        let y = preferredY + height <= desktop.frame.height
            ? preferredY
            : max(0, targetFrame.y - height)
        let viewer = THistoryViewer(
            frame: Rect(x: 0, y: 0, width: 1, height: 1),
            target: target,
            historyID: historyID
        )
        let window = THistoryWindow(frame: Rect(x: x, y: y, width: width, height: height), viewer: viewer)
        viewer.onChoose = { [weak window] _ in
            _ = window?.endModal(.ok)
        }
        application.present(modal: window)
        window.previousFocusedView = target
    }
}
