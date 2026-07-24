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
    private weak var resizingWindow: TWindow?
    private var resizeStartPoint: Point = Point(x: 0, y: 0)
    private var resizeStartFrame: Rect = Rect(x: 0, y: 0, width: 0, height: 0)
    public var menuBarHeight: Int = 0 // Height of menu bar to avoid cursor going under it
    /// Window being moved/resized with the keyboard (Size/Move mode), if any
    public private(set) weak var keyboardArrangeWindow: TWindow?
    private var arrangeStartFrame: Rect = Rect(x: 0, y: 0, width: 0, height: 0)
    
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
        tui.pushClip(row: frame.y, column: frame.x, width: frame.width, height: frame.height)
        defer { tui.popClip() }

        // Фон одним fillRect вместо цикла по каждой ячейке — быстрее перерисовка
        tui.fillRect(
            row: frame.y,
            column: frame.x,
            width: frame.width,
            height: frame.height,
            character: backgroundChar,
            attributes: backgroundAttr,
            foregroundColor: TTheme.current.desktopFill.fg,
            backgroundColor: TTheme.current.desktopFill.bg
        )
        
        // Draw subviews (windows + overlays) with dialog priority
        normalizeSubviewOrder()
        let windows = subviews.compactMap { $0 as? TWindow }
        let overlays = subviews.filter { !($0 is TWindow) }
        
        for window in windows {
            window.draw()
        }
        for view in overlays {
            view.draw()
        }
        
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
            foregroundColor: TTheme.current.mouseCursor.fg,
            backgroundColor: TTheme.current.mouseCursor.bg
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
            foregroundColor: TTheme.current.mouseCursor.fg,
            backgroundColor: TTheme.current.mouseCursor.bg
        )
    }
    
    @MainActor
    public func updateCursorPosition(globalPosition: Point) {
        cursorPosition = clampToDesktop(globalPosition)
    }
    
    /// The topmost visible modal window, if any. While present it owns all input.
    public var activeModal: TWindow? {
        for view in subviews.reversed() {
            if let window = view as? TWindow, window.isVisible, window.isModal {
                return window
            }
        }
        return nil
    }

    @MainActor
    public override func handleEvent(_ event: TEvent) {
        switch event {
        case .key(let key):
            // Size/Move mode owns the keyboard until Enter/Esc
            if let window = keyboardArrangeWindow {
                handleArrangeKey(key, for: window)
                return
            }
            routeFocusedEvent(event)
        case .paste:
            routeFocusedEvent(event)
        default:
            super.handleEvent(event)
        }
    }

    @MainActor
    private func routeFocusedEvent(_ event: TEvent) {
        // 1. An open overlay (popup menu) owns keyboard input
        if let overlay = subviews.reversed().first(where: { !($0 is TWindow) && $0.isVisible && $0.findFocusedView() != nil }) {
            overlay.handleEvent(event)
            return
        }
        // 2. A modal window blocks input to everything else
        if let modal = activeModal {
            modal.handleEvent(event)
            return
        }
        // 3. Status line hotkeys are global
        for view in subviews where view is TStatusLine {
            view.handleEvent(event)
        }
        // 4. Route to the window owning focus, else the topmost window
        let target = subviews.reversed().first { $0 is TWindow && $0.isVisible && $0.findFocusedView() != nil }
            ?? subviews.reversed().first { $0 is TWindow && $0.isVisible }
        target?.handleEvent(event)
    }

    @MainActor
    public override func handleCommand(_ command: TEvent.Command) -> Bool {
        switch command {
        case .next:
            focusNextWindow()
            return true
        case .previous:
            focusNextWindow(backward: true)
            return true
        case .tile:
            tileWindows()
            return true
        case .cascade:
            cascadeWindows()
            return true
        default:
            return super.handleCommand(command)
        }
    }

    // MARK: - Window management

    /// The desktop area windows are arranged in: everything except the
    /// menu bar row(s) and a visible status line
    public func arrangeArea() -> Rect {
        let top = menuBarHeight
        let hasStatusLine = subviews.contains { $0 is TStatusLine && $0.isVisible }
        let bottom = hasStatusLine ? 1 : 0
        return Rect(x: 0, y: top, width: frame.width, height: max(0, frame.height - top - bottom))
    }

    /// Activates the next (or previous) window in z-order
    @MainActor
    public func focusNextWindow(backward: Bool = false) {
        guard activeModal == nil else { return }
        let windows = subviews.compactMap { $0 as? TWindow }.filter { $0.isVisible }
        guard windows.count > 1 else { return }

        let active = windows.last { $0.findFocusedView() != nil } ?? windows.last!
        guard let index = windows.firstIndex(where: { $0 === active }) else { return }
        let offset = backward ? windows.count - 1 : 1
        let target = windows[(index + offset) % windows.count]

        bringWindowToFront(target)
        focus(window: target)
    }

    /// Arranges tileable windows (style .window) in a grid
    @MainActor
    public func tileWindows() {
        guard activeModal == nil else { return }
        let windows = subviews.compactMap { $0 as? TWindow }.filter { $0.isVisible && $0.style == .window }
        guard !windows.isEmpty else { return }

        let area = arrangeArea()
        guard area.width > 0, area.height > 0 else { return }

        let count = windows.count
        let columns = Int(Double(count).squareRoot().rounded(.up))
        let rows = (count + columns - 1) / columns

        for (index, window) in windows.enumerated() {
            let column = index % columns
            let row = index / columns
            let cellWidth = area.width / columns
            let cellHeight = area.height / rows
            // Last column/row absorbs the remainder
            let width = column == columns - 1 ? area.width - cellWidth * (columns - 1) : cellWidth
            let height = row == rows - 1 ? area.height - cellHeight * (rows - 1) : cellHeight
            window.unzoomedFrame = nil
            window.frame = Rect(
                x: area.x + column * cellWidth,
                y: area.y + row * cellHeight,
                width: max(window.minWidth, width),
                height: max(window.minHeight, height)
            )
        }
    }

    /// Arranges tileable windows (style .window) in a staggered cascade
    @MainActor
    public func cascadeWindows() {
        guard activeModal == nil else { return }
        let windows = subviews.compactMap { $0 as? TWindow }.filter { $0.isVisible && $0.style == .window }
        guard !windows.isEmpty else { return }

        let area = arrangeArea()
        guard area.width > 0, area.height > 0 else { return }

        let steps = windows.count - 1
        let width = max(1, area.width - steps * 2)
        let height = max(1, area.height - steps)

        for (index, window) in windows.enumerated() {
            window.unzoomedFrame = nil
            window.frame = Rect(
                x: area.x + index * 2,
                y: area.y + index,
                width: max(window.minWidth, width),
                height: max(window.minHeight, height)
            )
        }
    }

    /// Brings every window back into the desktop bounds (e.g. after a
    /// terminal resize); zoomed windows are re-fitted to the new area
    @MainActor
    public func clampWindowsToBounds() {
        for view in subviews {
            guard let window = view as? TWindow else { continue }
            if window.isZoomed {
                window.frame = arrangeArea()
                continue
            }
            var f = window.frame
            f.width = min(f.width, frame.width)
            f.height = min(f.height, frame.height)
            f.x = max(0, min(f.x, frame.width - f.width))
            f.y = max(0, min(f.y, frame.height - f.height))
            window.frame = f
        }
    }

    // MARK: - Keyboard Size/Move mode

    /// Enters Size/Move mode: arrows move the window, Shift+arrows resize it,
    /// Enter commits, Esc restores the original frame
    @MainActor
    public func beginKeyboardMoveResize(for window: TWindow) {
        guard keyboardArrangeWindow == nil else { return }
        keyboardArrangeWindow = window
        arrangeStartFrame = window.frame
        window.isDragging = true // border highlight
    }

    @MainActor
    private func endKeyboardMoveResize(cancelled: Bool) {
        guard let window = keyboardArrangeWindow else { return }
        if cancelled {
            window.frame = arrangeStartFrame
        }
        window.isDragging = false
        keyboardArrangeWindow = nil
    }

    @MainActor
    private func handleArrangeKey(_ key: Key, for window: TWindow) {
        switch key {
        case .up: nudge(window, dx: 0, dy: -1)
        case .down: nudge(window, dx: 0, dy: 1)
        case .left: nudge(window, dx: -1, dy: 0)
        case .right: nudge(window, dx: 1, dy: 0)
        case .shiftUp: stretch(window, dw: 0, dh: -1)
        case .shiftDown: stretch(window, dw: 0, dh: 1)
        case .shiftLeft: stretch(window, dw: -1, dh: 0)
        case .shiftRight: stretch(window, dw: 1, dh: 0)
        case .enter: endKeyboardMoveResize(cancelled: false)
        case .escape: endKeyboardMoveResize(cancelled: true)
        default: break
        }
    }

    @MainActor
    private func nudge(_ window: TWindow, dx: Int, dy: Int) {
        let maxX = max(0, frame.width - window.frame.width)
        let maxY = max(0, frame.height - window.frame.height)
        window.frame.x = max(0, min(window.frame.x + dx, maxX))
        window.frame.y = max(0, min(window.frame.y + dy, maxY))
    }

    @MainActor
    private func stretch(_ window: TWindow, dw: Int, dh: Int) {
        guard window.allowResizing else { return }
        window.unzoomedFrame = nil
        let maxWidth = max(window.minWidth, frame.width - window.frame.x)
        let maxHeight = max(window.minHeight, frame.height - window.frame.y)
        window.frame.width = max(window.minWidth, min(window.frame.width + dw, maxWidth))
        window.frame.height = max(window.minHeight, min(window.frame.height + dh, maxHeight))
    }

    @MainActor
    public override func handleMouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        cursorPosition = clampToDesktop(event.position)

        // Overlays (popup menus) get events first, including clicks outside
        // their bounds — an open popup consumes everything until dismissed
        for view in subviews.reversed() where !(view is TWindow) && view.isVisible {
            if view.handleMouseEvent(event) {
                return true
            }
        }

        if let modal = activeModal {
            var consumed = false
            switch event.action {
            case .down:
                consumed = handleMouseDown(event)
            case .drag:
                consumed = handleMouseDrag(event)
            case .up:
                consumed = handleMouseUp(event)
            default:
                break
            }
            if !consumed, modal.contains(globalPoint: event.position) {
                _ = modal.handleMouseEvent(event)
            }
            return true // Modal swallows everything outside itself
        }

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
            resizingWindow = nil
            return false
        }

        // Clicks on background windows are swallowed while a modal is up
        if let modal = activeModal, window !== modal {
            return true
        }

        focus(window: window)
        bringWindowToFront(window)

        if isCloseButtonHit(window: window, at: event.position) {
            window.close()
            return true
        }

        if isResizeHandleHit(window: window, at: event.position) {
            startResizing(window: window, at: event.position)
            return true
        }
        
        if isTitleBarHit(window: window, at: event.position) {
            startDragging(window: window, at: event.position)
            return true
        }
        
        return false
    }
    
    @MainActor
    private func handleMouseDrag(_ event: TEvent.MouseEvent) -> Bool {
        guard event.button == .left else { return false }
        if let window = resizingWindow {
            resize(window: window, to: event.position)
            return true
        }
        if let window = draggingWindow {
            move(window: window, to: event.position)
            return true
        }
        return false
    }
    
    @MainActor
    private func handleMouseUp(_ event: TEvent.MouseEvent) -> Bool {
        guard event.button == .left else { return false }
        let wasDragging = draggingWindow != nil
        let wasResizing = resizingWindow != nil
        if let window = draggingWindow {
            window.isDragging = false
        }
        draggingWindow = nil
        if let window = resizingWindow {
            window.isResizing = false
        }
        resizingWindow = nil
        return wasDragging || wasResizing
    }
    
    @MainActor
    private func startDragging(window: TWindow, at position: Point) {
        draggingWindow = window
        window.isDragging = true
        let windowOrigin = window.globalFrame
        dragOffset = Point(x: position.x - windowOrigin.x, y: position.y - windowOrigin.y)
    }
    
    @MainActor
    private func startResizing(window: TWindow, at position: Point) {
        resizingWindow = window
        window.isResizing = true
        resizeStartPoint = position
        resizeStartFrame = window.frame
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
    private func resize(window: TWindow, to globalPoint: Point) {
        guard window.allowResizing else { return }
        window.unzoomedFrame = nil // manual resize discards zoom state

        let deltaX = globalPoint.x - resizeStartPoint.x
        let deltaY = globalPoint.y - resizeStartPoint.y
        
        let windowOrigin = window.globalFrame
        let maxWidth = max(0, frame.x + frame.width - windowOrigin.x)
        let maxHeight = max(0, frame.y + frame.height - windowOrigin.y)
        
        let targetWidth = resizeStartFrame.width + deltaX
        let targetHeight = resizeStartFrame.height + deltaY
        
        let clampedWidth = min(max(targetWidth, window.minWidth), maxWidth)
        let clampedHeight = min(max(targetHeight, window.minHeight), maxHeight)
        
        window.frame.width = clampedWidth
        window.frame.height = clampedHeight
    }
    
    @MainActor
    private func focus(window: TWindow) {
        clearFocus()
        window.isFocused = true
    }
    
    private func topmostWindow(at point: Point) -> TWindow? {
        normalizeSubviewOrder()
        for view in subviews.reversed() {
            guard let window = view as? TWindow else { continue }
            if window.isVisible, window.contains(globalPoint: point) {
                return window
            }
        }
        return nil
    }
    
    /// The [■] close button occupies columns x+2...x+4 of the title row
    private func isCloseButtonHit(window: TWindow, at point: Point) -> Bool {
        guard window.allowClosing, window.frame.width > 5 else { return false }
        let frame = window.globalFrame
        return point.y == frame.y && point.x >= frame.x + 2 && point.x <= frame.x + 4
    }

    private func isTitleBarHit(window: TWindow, at point: Point) -> Bool {
        let frame = window.globalFrame
        return point.y == frame.y && point.x >= frame.x && point.x < frame.x + frame.width
    }
    
    private func isResizeHandleHit(window: TWindow, at point: Point) -> Bool {
        guard window.allowResizing, window.style == .window else { return false }
        let frame = window.globalFrame
        guard frame.width >= 2, frame.height >= 2 else { return false }
        let cornerX = frame.x + frame.width - 1
        let cornerY = frame.y + frame.height - 1
        return point.x == cornerX && point.y == cornerY
    }
    
    private func normalizeSubviewOrder() {
        let windows = subviews.filter { ($0 as? TWindow)?.style == .window }
        let dialogs = subviews.filter { ($0 as? TWindow)?.style == .dialog }
        let overlays = subviews.filter { !($0 is TWindow) }
        subviews = windows + dialogs + overlays
    }
    
    private func bringWindowToFront(_ window: TWindow) {
        normalizeSubviewOrder()
        subviews.removeAll { $0 === window }
        
        let overlayIndex = subviews.firstIndex { !($0 is TWindow) } ?? subviews.count
        let firstDialogIndex = subviews.firstIndex { ($0 as? TWindow)?.style == .dialog } ?? overlayIndex
        
        switch window.style {
        case .window:
            let lastWindowIndex = subviews.lastIndex { ($0 as? TWindow)?.style == .window } ?? -1
            let targetIndex = min(lastWindowIndex + 1, firstDialogIndex)
            subviews.insert(window, at: targetIndex)
        case .dialog:
            let lastDialogIndex = subviews.lastIndex { ($0 as? TWindow)?.style == .dialog }
            let lastWindowIndex = subviews.lastIndex { ($0 as? TWindow)?.style == .window } ?? -1
            let baseIndex = lastDialogIndex ?? lastWindowIndex
            let targetIndex = min(baseIndex + 1, overlayIndex)
            subviews.insert(window, at: targetIndex)
        }
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
