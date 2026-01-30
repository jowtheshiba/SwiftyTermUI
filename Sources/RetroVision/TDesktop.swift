import SwiftyTermUI

/// The background view that contains all windows
public class TDesktop: TView {
    private let backgroundChar: Character
    private let backgroundAttr: TextAttributes
    private var cursorPosition: Point
    private var cursorVisible: Bool = true
    private weak var draggingWindow: TWindow?
    private var dragOffset: Point = Point(x: 0, y: 0)
    public var menuBarHeight: Int = 0 // Height of menu bar to avoid cursor going under it
    
    public init(frame: Rect, backgroundChar: Character = "░", backgroundAttr: TextAttributes = TextAttributes()) {
        self.backgroundChar = backgroundChar
        self.backgroundAttr = backgroundAttr
        self.cursorPosition = Point(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        
        let tui = SwiftyTermUI.shared
        
        // Draw background pattern
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                tui.drawChar(
                    row: frame.y + y,
                    column: frame.x + x,
                    character: backgroundChar,
                    attributes: backgroundAttr,
                    foregroundColor: .black,
                    backgroundColor: .white
                )
            }
        }
        
        // Draw subviews (windows)
        super.draw()
        
        // Note: cursor is drawn in TApplication.redraw() after menu bar
        // to ensure it appears on top of everything
    }
    
    @MainActor
    public func drawCursor() {
        guard cursorVisible else { return }
        guard frame.width > 0 && frame.height > 0 else { return }
        
        let withinX = cursorPosition.x >= frame.x && cursorPosition.x < frame.x + frame.width
        let withinY = cursorPosition.y >= frame.y && cursorPosition.y < frame.y + frame.height
        guard withinX && withinY else { return }
        
        let tui = SwiftyTermUI.shared
        tui.drawChar(
            row: cursorPosition.y,
            column: cursorPosition.x,
            character: "╳",
            attributes: [.bold],
            foregroundColor: .black,
            backgroundColor: .brightWhite
        )
    }
    
    public override func handleMouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        cursorPosition = clampToDesktop(event.position)
        
        var consumed = false
        switch event.action {
        case .down:
            consumed = handleMouseDown(event)
        case .drag:
            consumed = handleMouseDrag(event)
        case .up:
            consumed = handleMouseUp(event)
        case .move:
            // Mouse movement - just update cursor position, already done above
            break
        default:
            break
        }
        
        if !consumed {
            return super.handleMouseEvent(event)
        }
        
        return consumed
    }
    
    // MARK: - Private
    
    private func handleMouseDown(_ event: TEvent.MouseEvent) -> Bool {
        guard event.button == .left else { return false }
        
        guard let window = topmostWindow(at: event.position) else {
            draggingWindow = nil
            return false
        }
        
        focus(window: window)
        bringSubviewToFront(window)
        
        if isTitleBarHit(window: window, at: event.position) {
            startDragging(window: window, at: event.position)
            return true
        }
        
        return false
    }
    
    private func handleMouseDrag(_ event: TEvent.MouseEvent) -> Bool {
        guard event.button == .left, let window = draggingWindow else { return false }
        move(window: window, to: event.position)
        return true
    }
    
    private func handleMouseUp(_ event: TEvent.MouseEvent) -> Bool {
        guard event.button == .left else { return false }
        let wasDragging = draggingWindow != nil
        draggingWindow = nil
        return wasDragging
    }
    
    private func startDragging(window: TWindow, at position: Point) {
        draggingWindow = window
        let windowOrigin = window.globalFrame
        dragOffset = Point(x: position.x - windowOrigin.x, y: position.y - windowOrigin.y)
    }
    
    private func move(window: TWindow, to globalPoint: Point) {
        let targetX = globalPoint.x - dragOffset.x
        let targetY = globalPoint.y - dragOffset.y
        
        let minX = frame.x
        let maxX = frame.x + max(frame.width - window.frame.width, 0)
        let minY = frame.y
        let maxY = frame.y + max(frame.height - window.frame.height, 0)
        
        let clampedX = min(max(targetX, minX), maxX)
        let clampedY = min(max(targetY, minY), maxY)
        
        let oldX = window.frame.x
        let oldY = window.frame.y
        window.frame.x = clampedX - frame.x
        window.frame.y = clampedY - frame.y
        
    }
    
    private func focus(window: TWindow) {
        for case let candidate as TWindow in subviews {
            candidate.isFocused = (candidate === window)
        }
    }
    
    private func topmostWindow(at point: Point) -> TWindow? {
        for view in subviews.reversed() {
            guard let window = view as? TWindow else { continue }
            if window.contains(globalPoint: point) {
                return window
            }
        }
        return nil
    }
    
    private func isTitleBarHit(window: TWindow, at point: Point) -> Bool {
        let frame = window.globalFrame
        return point.y == frame.y && point.x >= frame.x && point.x < frame.x + frame.width
    }
    
    private func clampToDesktop(_ point: Point) -> Point {
        guard frame.width > 0 && frame.height > 0 else { return point }
        
        let minX = frame.x
        let maxX = frame.x + frame.width - 1
        // Allow cursor to be anywhere in the screen, including menu bar area
        // Menu bar is drawn on top, so cursor can be there
        let minY = frame.y
        let maxY = frame.y + frame.height - 1
        
        let clampedX = min(max(point.x, minX), maxX)
        let clampedY = min(max(point.y, minY), maxY)
        return Point(x: clampedX, y: clampedY)
    }
    
}
