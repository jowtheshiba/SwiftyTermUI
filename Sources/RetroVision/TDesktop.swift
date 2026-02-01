import SwiftyTermUI

/// The background view that contains all windows
public class TDesktop: TView {
    private let backgroundChar: Character
    private let backgroundAttr: TextAttributes
    private var cursorPosition: Point
    private var previousCursorPosition: Point
    private var cellUnderCursor: Cell?
    private var cursorVisible: Bool = true
    private weak var draggingWindow: TWindow?
    private var dragOffset: Point = Point(x: 0, y: 0)
    public var menuBarHeight: Int = 0 // Height of menu bar to avoid cursor going under it
    
    public init(frame: Rect, backgroundChar: Character = "░", backgroundAttr: TextAttributes = TextAttributes()) {
        self.backgroundChar = backgroundChar
        self.backgroundAttr = backgroundAttr
        let initial = Point(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)
        self.cursorPosition = initial
        self.previousCursorPosition = initial
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        
        let tui = SwiftyTermUI.shared
        
        // Фон одним fillRect вместо цикла по каждой ячейке — быстрее перерисовка
        tui.fillRect(
            row: frame.y,
            column: frame.x,
            width: frame.width,
            height: frame.height,
            character: backgroundChar,
            attributes: backgroundAttr,
            foregroundColor: .black,
            backgroundColor: .white
        )
        
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
        // Save cell under cursor before drawing (for cursor-only redraw on move)
        cellUnderCursor = tui.getCell(row: cursorPosition.y, column: cursorPosition.x)
        tui.drawChar(
            row: cursorPosition.y,
            column: cursorPosition.x,
            character: "╳",
            attributes: [.bold],
            foregroundColor: .black,
            backgroundColor: .brightWhite
        )
        previousCursorPosition = cursorPosition
    }
    
    /// Updates only the mouse cursor on screen without full redraw (Turbo Vision style).
    /// Restores the cell at old position, draws cursor at new position; refresh() still needed after.
    @MainActor
    public func updateCursorOnly(globalPosition: Point) {
        guard cursorVisible, frame.width > 0, frame.height > 0 else { return }
        
        let newPos = clampToDesktop(globalPosition)
        if newPos.x == cursorPosition.x && newPos.y == cursorPosition.y { return }
        
        let tui = SwiftyTermUI.shared
        let oldPos = cursorPosition
        
        // Restore cell under previous cursor position
        if let cell = cellUnderCursor {
            tui.drawCell(row: oldPos.y, column: oldPos.x, cell: cell)
        }
        
        cursorPosition = newPos
        previousCursorPosition = newPos
        
        let withinX = newPos.x >= frame.x && newPos.x < frame.x + frame.width
        let withinY = newPos.y >= frame.y && newPos.y < frame.y + frame.height
        guard withinX && withinY else { return }
        
        // Read cell at new position, then draw cursor on top
        cellUnderCursor = tui.getCell(row: newPos.y, column: newPos.x)
        tui.drawChar(
            row: newPos.y,
            column: newPos.x,
            character: "╳",
            attributes: [.bold],
            foregroundColor: .black,
            backgroundColor: .brightWhite
        )
    }
    
    @MainActor
    public func updateCursorPosition(globalPosition: Point) {
        cursorPosition = clampToDesktop(globalPosition)
    }
    
    @MainActor
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
    
    @MainActor
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
    
    @MainActor
    private func handleMouseDrag(_ event: TEvent.MouseEvent) -> Bool {
        guard event.button == .left, let window = draggingWindow else { return false }
        move(window: window, to: event.position)
        return true
    }
    
    @MainActor
    private func handleMouseUp(_ event: TEvent.MouseEvent) -> Bool {
        guard event.button == .left else { return false }
        let wasDragging = draggingWindow != nil
        if let window = draggingWindow {
            window.isDragging = false
        }
        draggingWindow = nil
        return wasDragging
    }
    
    @MainActor
    private func startDragging(window: TWindow, at position: Point) {
        draggingWindow = window
        window.isDragging = true
        let windowOrigin = window.globalFrame
        dragOffset = Point(x: position.x - windowOrigin.x, y: position.y - windowOrigin.y)
    }
    
    @MainActor
    private func move(window: TWindow, to globalPoint: Point) {
        let targetX = globalPoint.x - dragOffset.x
        let targetY = globalPoint.y - dragOffset.y
        
        let minX = frame.x
        let maxX = frame.x + max(frame.width - window.frame.width, 0)
        let minY = frame.y
        let maxY = frame.y + max(frame.height - window.frame.height, 0)
        
        let clampedX = min(max(targetX, minX), maxX)
        let clampedY = min(max(targetY, minY), maxY)
        
        window.frame.x = clampedX - frame.x
        window.frame.y = clampedY - frame.y
        
    }
    
    @MainActor
    private func focus(window: TWindow) {
        clearFocus()
        window.isFocused = true
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
