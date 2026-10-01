import SwiftyTermUI

/// Base class for all visible components in RetroVision
open class TView {
    public var frame: Rect {
        didSet { sizeChanged(from: oldValue) }
    }
    public var bounds: Rect {
        Rect(x: 0, y: 0, width: frame.width, height: frame.height)
    }
    public var globalFrame: Rect {
        let origin = localToGlobal(Point(x: 0, y: 0))
        return Rect(x: origin.x, y: origin.y, width: frame.width, height: frame.height)
    }
    
    public weak var superview: TView?
    public var subviews: [TView] = []
    public var owner: TGroup? { superview as? TGroup }
    public var state: TViewState = [.visible, .active, .exposed]
    public var options: TViewOptions = []
    public var growMode: TGrowMode = []
    public var eventMask: TEventMask = .all
    public var isVisible: Bool {
        get { state.contains(.visible) }
        set { setState(.visible, enabled: newValue) }
    }
    public var isFocused: Bool {
        get { state.contains(.focused) }
        set { setState(.focused, enabled: newValue) }
    }
    public var isEnabled: Bool {
        get { !state.contains(.disabled) }
        set { setState(.disabled, enabled: !newValue) }
    }
    public var isSelectedInGroup: Bool { state.contains(.selected) }
    /// Whether the view participates in Tab/Shift+Tab focus traversal
    open var canFocus: Bool { false }
    /// Whether the view uses the Enter key itself (blocks a dialog's default button)
    open var consumesEnterKey: Bool { false }
    public var contextMenu: (() -> [TMenuItem])?
    
    public init(frame: Rect) {
        self.frame = frame
    }
    
    open func addSubview(_ view: TView) {
        if view.superview === self { return }
        view.removeFromSuperview()
        subviews.append(view)
        view.superview = self
    }

    open func removeSubview(_ view: TView) {
        guard view.superview === self else { return }
        subviews.removeAll { $0 === view }
        view.superview = nil
    }
    
    open func removeFromSuperview() {
        superview?.removeSubview(self)
    }
    
    @MainActor
    open func draw() {
        guard isVisible else { return }
        
        // Default implementation: clear background
        // In a real implementation, we would clip to bounds
        for view in subviews {
            view.draw()
        }
    }
    
    @MainActor
    open func handleEvent(_ event: TEvent) {
        guard eventMask.contains(event.mask) else { return }
        if !isEnabled, event.mask != .broadcast { return }
        switch event {
        case .mouse(let mouseEvent):
            handleMouseEvent(mouseEvent)
        case .command(let command):
            if handleCommand(command) { return }
            for view in subviews.reversed() {
                view.handleEvent(event)
            }
        case .broadcast(let broadcast):
            _ = handleBroadcast(broadcast)
            for view in subviews {
                view.handleEvent(event)
            }
        case .key, .paste:
            // Focused-chain routing: deliver only to the subview owning focus
            for view in subviews.reversed() where view.isVisible {
                if view.findFocusedView() != nil {
                    view.handleEvent(event)
                    return
                }
            }
        default:
            // Pass event to subviews (simple responder chain)
            for view in subviews.reversed() {
                view.handleEvent(event)
            }
        }
    }

    /// Handles a framework command. Returns true when the command was consumed.
    @MainActor
    @discardableResult
    open func handleCommand(_ command: TEvent.Command) -> Bool {
        return false
    }

    @MainActor
    @discardableResult
    open func handleBroadcast(_ event: TEvent.Broadcast) -> Bool {
        false
    }

    @MainActor
    open func valid(_ command: TEvent.Command) -> Bool {
        true
    }
    
    @MainActor
    @discardableResult
    open func handleMouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard isVisible else { return false }
        
        // Event position is in GLOBAL screen coordinates
        // We convert to local only for hit testing, but pass global coords to children
        for view in subviews.reversed() where view.isVisible {
            let localPoint = view.globalToLocal(event.position)
            if view.bounds.contains(localPoint) {
                // Pass the ORIGINAL event with global coordinates to child
                // The child will do its own globalToLocal conversion
                if view.handleMouseEvent(event) {
                    return true // Event was handled by subview
                }
            }
        }
        
        var localizedEvent = event
        localizedEvent.position = globalToLocal(event.position)
        
        if event.action == .down && event.button == .right {
            if let items = self.contextMenu?(), !items.isEmpty {
                showContextMenu(at: event.position, items: items)
                return true
            }
        }
        
        return mouseEvent(localizedEvent)
    }
    
    @MainActor
    open func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        // Subclasses can override to handle pointer interactions
        return false
    }
    
    /// Converts a point from local coordinates to global screen coordinates
    public func localToGlobal(_ point: Point) -> Point {
        var p = point
        p.x += frame.x
        p.y += frame.y
        
        var current = superview
        while let view = current {
            p.x += view.frame.x
            p.y += view.frame.y
            current = view.superview
        }
        
        return p
    }
    
    /// Converts a point from global coordinates to the local coordinate space of this view
    public func globalToLocal(_ point: Point) -> Point {
        let origin = localToGlobal(Point(x: 0, y: 0))
        return Point(x: point.x - origin.x, y: point.y - origin.y)
    }
    
    /// Whether the view contains a global point
    public func contains(globalPoint: Point) -> Bool {
        let localPoint = globalToLocal(globalPoint)
        return bounds.contains(localPoint)
    }
    
    /// Returns the focused view in this subtree, or nil if none
    @MainActor
    open func findFocusedView() -> TView? {
        guard isVisible, isEnabled else { return nil }
        for view in subviews {
            if let found = view.findFocusedView() { return found }
        }
        if isFocused { return self }
        return nil
    }

    /// Returns visible focusable views in this subtree, in depth-first order
    @MainActor
    public func focusableDescendants() -> [TView] {
        var result: [TView] = []
        collectFocusable(into: &result)
        return result
    }

    @MainActor
    private func collectFocusable(into result: inout [TView]) {
        guard isVisible else { return }
        if canFocus { result.append(self) }
        for view in subviews {
            view.collectFocusable(into: &result)
        }
    }

    /// Clears focus state in this subtree
    @MainActor
    open func clearFocus() {
        isFocused = false
        for view in subviews {
            view.clearFocus()
        }
    }

    open func sizeChanged(from oldSize: Rect) {}

    public func setState(_ member: TViewState, enabled: Bool) {
        if enabled {
            state.insert(member)
        } else {
            state.remove(member)
        }
        if (member.contains(.disabled) && enabled) || (member.contains(.visible) && !enabled) {
            clearFocusState()
        }
    }

    private func clearFocusState() {
        state.remove([.focused, .selected])
        for view in subviews {
            view.clearFocusState()
        }
    }

    func applyGrowth(from parentOldFrame: Rect, deltaWidth: Int, deltaHeight: Int) {
        if growMode.contains(.relative), parentOldFrame.width > 0, parentOldFrame.height > 0 {
            let newParentWidth = parentOldFrame.width + deltaWidth
            let newParentHeight = parentOldFrame.height + deltaHeight
            frame = Rect(
                x: frame.x * newParentWidth / parentOldFrame.width,
                y: frame.y * newParentHeight / parentOldFrame.height,
                width: frame.width * newParentWidth / parentOldFrame.width,
                height: frame.height * newParentHeight / parentOldFrame.height
            )
            return
        }
        var next = frame
        if growMode.contains(.lowX) { next.x += deltaWidth }
        if growMode.contains(.highX) { next.width += deltaWidth }
        if growMode.contains(.lowY) { next.y += deltaHeight }
        if growMode.contains(.highY) { next.height += deltaHeight }
        next.width = max(0, next.width)
        next.height = max(0, next.height)
        frame = next
    }
    
    /// Brings a subview to the front (end of the array == front)
    public func bringSubviewToFront(_ view: TView) {
        guard let index = subviews.firstIndex(where: { $0 === view }) else { return }
        subviews.remove(at: index)
        subviews.append(view)
    }
    
    /// Sends a subview to the back (beginning of the array == back)
    public func sendSubviewToBack(_ view: TView) {
        guard let index = subviews.firstIndex(where: { $0 === view }) else { return }
        subviews.remove(at: index)
        subviews.insert(view, at: 0)
    }
    
    @MainActor
    public func showContextMenu(at position: Point, items: [TMenuItem]) {
        let menu = TPopupMenu(position: position, items: items)
        
        var root: TView = self
        while let parent = root.superview {
            root = parent
        }
        
        root.addSubview(menu)
        root.bringSubviewToFront(menu)
        RetroTextUtils.focus(view: menu)
    }
    
    @MainActor
    open func preferredContextMenuPosition() -> Point {
        localToGlobal(Point(x: 0, y: 0))
    }
    
    @MainActor
    public func showContextMenuFromKeyboard() {
        guard let items = contextMenu?(), !items.isEmpty else { return }
        let position = preferredContextMenuPosition()
        showContextMenu(at: position, items: items)
    }

    @MainActor
    public func sendCommand(_ command: TEvent.Command) {
        var root: TView = self
        while let parent = root.superview {
            root = parent
        }
        if let desktop = root as? TDesktop, let application = desktop.application {
            application.postCommand(command)
        } else {
            root.handleEvent(.command(command))
        }
    }

    @MainActor
    @discardableResult
    open func endModal(_ command: TEvent.Command) -> Bool {
        var view: TView? = self
        while let current = view {
            if let dialog = current as? TDialog, dialog.isModal {
                return dialog.endModal(command)
            }
            view = current.superview
        }
        return false
    }
}

public struct Rect: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
    
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    public var maxX: Int { x + width }
    public var maxY: Int { y + height }
    
    public func contains(_ point: Point) -> Bool {
        point.x >= x && point.x < maxX && point.y >= y && point.y < maxY
    }
}

public struct Point: Equatable, Sendable {
    public var x: Int
    public var y: Int
    
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}
