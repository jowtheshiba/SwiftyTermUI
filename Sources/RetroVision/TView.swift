import SwiftyTermUI

/// Base class for all visible components in RetroVision
open class TView {
    public var frame: Rect
    public var bounds: Rect {
        Rect(x: 0, y: 0, width: frame.width, height: frame.height)
    }
    public var globalFrame: Rect {
        let origin = localToGlobal(Point(x: 0, y: 0))
        return Rect(x: origin.x, y: origin.y, width: frame.width, height: frame.height)
    }
    
    public weak var superview: TView?
    public var subviews: [TView] = []
    
    public var isVisible: Bool = true
    public var isFocused: Bool = false
    
    public init(frame: Rect) {
        self.frame = frame
    }
    
    open func addSubview(_ view: TView) {
        subviews.append(view)
        view.superview = self
    }
    
    open func removeFromSuperview() {
        superview?.subviews.removeAll { $0 === self }
        superview = nil
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
    
    open func handleEvent(_ event: TEvent) {
        switch event {
        case .mouse(let mouseEvent):
            handleMouseEvent(mouseEvent)
        default:
            // Pass event to subviews (simple responder chain)
            for view in subviews.reversed() {
                view.handleEvent(event)
            }
        }
    }
    
    @discardableResult
    open func handleMouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard isVisible else { return false }
        
        for view in subviews.reversed() where view.isVisible {
            let localPoint = view.globalToLocal(event.position)
            if view.bounds.contains(localPoint) {
                var localizedEvent = event
                localizedEvent.position = localPoint
                if view.handleMouseEvent(localizedEvent) {
                    return true // Event was handled by subview
                }
            }
        }
        
        mouseEvent(event)
        return false // Event not handled
    }
    
    open func mouseEvent(_ event: TEvent.MouseEvent) {
        // Subclasses can override to handle pointer interactions
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
