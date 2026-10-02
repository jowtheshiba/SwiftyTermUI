import SwiftyTermUI

open class TGroup: TView {
    public private(set) weak var current: TView?

    public override init(frame: Rect) {
        super.init(frame: frame)
    }

    open override func addSubview(_ view: TView) {
        if view.superview === self {
            return
        }
        view.removeFromSuperview()
        super.addSubview(view)
        let selectable = view.canFocus || view.options.contains(.selectable)
        if (current == nil && selectable) || view.options.contains(.topSelect) || view.isFocused {
            setCurrent(view)
        }
    }

    open override func removeSubview(_ view: TView) {
        guard view.superview === self else { return }
        let wasCurrent = current === view
        super.removeSubview(view)
        if wasCurrent {
            current = selectableSubviews.last
            current?.setState(.selected, enabled: true)
        }
    }

    @MainActor
    public func select(_ view: TView?) {
        guard let view else {
            current?.setState(.selected, enabled: false)
            current = nil
            return
        }
        guard view.superview === self, view.isVisible, view.isEnabled else { return }
        setCurrent(view)
        handleEvent(.broadcast(.init(name: .selectionChanged, source: view)))
    }

    @MainActor
    public func selectNext(backward: Bool = false) {
        let candidates = selectableSubviews
        guard !candidates.isEmpty else { return }
        let index = current.flatMap { selected in
            candidates.firstIndex { $0 === selected }
        }
        let nextIndex: Int
        if let index {
            nextIndex = backward ? (index + candidates.count - 1) % candidates.count : (index + 1) % candidates.count
        } else {
            nextIndex = backward ? candidates.count - 1 : 0
        }
        select(candidates[nextIndex])
    }

    public func firstSubview(where predicate: (TView) -> Bool) -> TView? {
        subviews.first(where: predicate)
    }

    public func forEachSubview(_ body: (TView) -> Void) {
        subviews.forEach(body)
    }

    @MainActor
    open override func handleEvent(_ event: TEvent) {
        guard eventMask.contains(event.mask) else { return }
        if !isEnabled, event.mask != .broadcast { return }
        switch event {
        case .key, .paste:
            dispatchFocused(event)
        case .command(let command):
            if handleCommand(command) { return }
            dispatchFocused(event)
        case .broadcast(let broadcast):
            _ = handleBroadcast(broadcast)
            for view in subviews {
                view.handleEvent(event)
            }
        case .mouse(let mouse):
            _ = handleMouseEvent(mouse)
        case .nothing:
            break
        }
    }

    @MainActor
    open override func clearFocus() {
        super.clearFocus()
        current?.setState(.selected, enabled: false)
    }

    @MainActor
    open override func valid(_ command: TEvent.Command) -> Bool {
        for view in subviews where view.isVisible && view.isEnabled {
            if !view.valid(command) {
                if view.canFocus {
                    RetroTextUtils.focus(view: view)
                } else if let focusable = view.focusableDescendants().first {
                    RetroTextUtils.focus(view: focusable)
                }
                return false
            }
        }
        return true
    }

    @MainActor
    open override var dataSize: Int {
        subviews.reduce(0) { $0 + $1.dataSize }
    }

    @MainActor
    open override func getData() -> TViewData? {
        guard dataSize > 0 else { return nil }
        return .group(subviews.compactMap { $0.getData() })
    }

    @MainActor
    @discardableResult
    open override func setData(_ data: TViewData) -> Bool {
        guard case .group(let values) = data else { return false }
        let views = subviews.filter { $0.dataSize > 0 }
        guard views.count == values.count else { return false }
        for (view, value) in zip(views, values) {
            if !view.setData(value) { return false }
        }
        return true
    }

    @MainActor
    public func execView(_ dialog: TDialog) -> TEvent.Command {
        var root: TView = self
        while let parent = root.superview {
            root = parent
        }
        guard let desktop = root as? TDesktop, let application = desktop.application else {
            return .cancel
        }
        return application.execView(dialog)
    }

    open override func sizeChanged(from oldSize: Rect) {
        let deltaWidth = frame.width - oldSize.width
        let deltaHeight = frame.height - oldSize.height
        guard deltaWidth != 0 || deltaHeight != 0 else { return }
        for view in subviews {
            view.applyGrowth(from: oldSize, deltaWidth: deltaWidth, deltaHeight: deltaHeight)
        }
    }

    func setCurrent(_ view: TView) {
        guard current !== view else {
            view.setState(.selected, enabled: true)
            return
        }
        current?.setState(.selected, enabled: false)
        current = view
        view.setState(.selected, enabled: true)
    }

    private var selectableSubviews: [TView] {
        subviews.filter {
            $0.isVisible && $0.isEnabled && ($0.canFocus || $0.options.contains(.selectable))
        }
    }

    @MainActor
    private func dispatchFocused(_ event: TEvent) {
        let target = current.flatMap { $0.isVisible && $0.isEnabled ? $0 : nil }
            ?? subviews.reversed().first { $0.isVisible && $0.isEnabled && $0.findFocusedView() != nil }

        for view in subviews where view.isVisible && view.isEnabled && view !== target && view.options.contains(.preProcess) {
            view.handleEvent(event)
        }

        target?.handleEvent(event)

        for view in subviews where view.isVisible && view.isEnabled && view !== target && view.options.contains(.postProcess) {
            view.handleEvent(event)
        }
    }
}
