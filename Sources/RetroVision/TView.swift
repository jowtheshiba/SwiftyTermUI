import SwiftyTermUI

/// Base class for all visible components in RetroVision
open class TView {
    public var frame: Rect
    public var bounds: Rect {
        Rect(x: 0, y: 0, width: frame.width, height: frame.height)
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
        // Pass event to subviews (simple responder chain)
        for view in subviews.reversed() {
            view.handleEvent(event)
        }
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
}

public struct Rect: Equatable {
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

public struct Point: Equatable {
    public var x: Int
    public var y: Int
    
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}
