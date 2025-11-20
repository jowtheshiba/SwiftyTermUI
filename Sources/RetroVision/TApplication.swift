import Foundation
import SwiftyTermUI

/// The main application class
@MainActor
open class TApplication {
    public static let shared = TApplication()
    

    private var isRunning = false
    
    public init() {
        // We can't access actor-isolated state in init easily without being isolated ourselves
        // Defer initialization of desktop to run() or make init async?
        // For simplicity, let's make TApplication @MainActor
    }
    
    // Lazy init to avoid actor issues in init
    private lazy var _desktop: TDesktop = {
        let (cols, rows) = SwiftyTermUI.shared.getTerminalSize()
        return TDesktop(frame: Rect(x: 0, y: 0, width: cols, height: rows))
    }()
    
    public var menuBar: TMenuBar? {
        didSet {
            // Update desktop menu bar height so cursor doesn't go under it
            if let menuBar = menuBar {
                desktop.menuBarHeight = menuBar.frame.height
            } else {
                desktop.menuBarHeight = 0
            }
            redraw()
        }
    }
    
    public var desktop: TDesktop {
        _desktop
    }
    
    @MainActor
    open func run() {
        do {
            try SwiftyTermUI.shared.initialize()
            SwiftyTermUI.shared.enableMouseCapture()
            defer {
                SwiftyTermUI.shared.disableMouseCapture()
                SwiftyTermUI.shared.shutdown()
            }
            
            // Enable mouse reporting if supported
            // SwiftyTermUI.shared.enableMouse() // Assuming this exists or is default
            
            isRunning = true
            
            // Initial draw
            redraw()
            
            while isRunning {
                var hasEvents = false
                var needsRedraw = false
                
                // Process events with immediate redraw for mouse movements
                // This ensures cursor updates smoothly without lag
                for _ in 0..<20 {
                    if let event = SwiftyTermUI.shared.readEvent() {
                        hasEvents = true
                        let isMouseMove = isMouseMoveEvent(event)
                        let isMouseClick = isMouseClickEvent(event)
                        handleLowLevelEvent(event)
                        
                        // Redraw immediately after mouse move events for smooth cursor tracking
                        // Also redraw immediately after mouse clicks (e.g., menu bar, buttons)
                        if isMouseMove || isMouseClick {
                            redraw()
                        } else {
                            // Mark that we need redraw for non-mouse events
                            needsRedraw = true
                        }
                    } else {
                        break // No more events available
                    }
                }
                
                // Redraw for non-mouse events (mouse moves already redrawn above)
                if needsRedraw {
                    redraw()
                }
                
                // Very small sleep only when idle to prevent CPU spinning
                // No sleep when processing events for maximum responsiveness
                if !hasEvents {
                    Thread.sleep(forTimeInterval: 0.001) // 1ms when idle
                }
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    /// Checks if event is a mouse move or drag event (needs immediate redraw)
    private func isMouseMoveEvent(_ event: InputEvent) -> Bool {
        if case .mouse(let mouse) = event {
            return mouse.action == .move || mouse.action == .drag
        }
        return false
    }
    
    /// Checks if event is a mouse click that might need immediate redraw (e.g., menu bar clicks)
    private func isMouseClickEvent(_ event: InputEvent) -> Bool {
        if case .mouse(let mouse) = event {
            return mouse.action == .down || mouse.action == .up
        }
        return false
    }
    
    @MainActor
    private func handleLowLevelEvent(_ event: InputEvent) {
        switch event {
        case .keyPress(let key):
            if key == .ctrl("c") {
                isRunning = false
                return
            }
            
            // Convert to TEvent
            let tEvent = TEvent.key(key)
            
            // Pass event to components
            // 1. Menu Bar (if it handles it)
            if let menuBar = menuBar {
                menuBar.handleEvent(tEvent)
            }
            
            // 2. Desktop (Windows)
            desktop.handleEvent(tEvent)
            
        case .mouse(let mouse):
            DebugLogger.log("TApplication received mouse input button=\(mouse.button) action=\(mouse.action) col=\(mouse.column) row=\(mouse.row)")
            let mouseEvent = convertMouseEvent(mouse)
            DebugLogger.log("TApplication converted mouse to TEvent.MouseEvent position=(\(mouseEvent.position.x), \(mouseEvent.position.y)) action=\(mouseEvent.action) button=\(mouseEvent.button)")
            
            // Adjust mouse coordinates to account for menu bar if present
            // Menu bar occupies the first row (y=0), so we need to adjust coordinates for desktop
            var adjustedMouseEvent = mouseEvent
            if let menuBar = menuBar, menuBar.isVisible {
                let menuBarHeight = menuBar.frame.height
                DebugLogger.log("TApplication: menuBar exists, height=\(menuBarHeight), mouse y=\(mouseEvent.position.y)")
                // If mouse is over menu bar area, don't adjust (menu bar handles it)
                // Otherwise, adjust coordinates for desktop
                if mouseEvent.position.y >= menuBarHeight {
                    let adjustedPosition = Point(x: mouseEvent.position.x, y: mouseEvent.position.y - menuBarHeight)
                    adjustedMouseEvent = TEvent.MouseEvent(
                        position: adjustedPosition,
                        button: mouseEvent.button,
                        action: mouseEvent.action,
                        clickCount: mouseEvent.clickCount,
                        modifiers: mouseEvent.modifiers
                    )
                    DebugLogger.log("TApplication adjusted mouse y coordinate: \(mouseEvent.position.y) -> \(adjustedPosition.y) (menuBarHeight=\(menuBarHeight))")
                } else {
                    DebugLogger.log("TApplication: Mouse is in menu bar area (y=\(mouseEvent.position.y) < menuBarHeight=\(menuBarHeight))")
                }
            } else {
                DebugLogger.log("TApplication: No menu bar or menu bar not visible")
            }
            
            DebugLogger.log("TApplication: Sending mouse event to menuBar with position=(\(mouseEvent.position.x), \(mouseEvent.position.y))")
            if let menuBar = menuBar {
                menuBar.handleEvent(.mouse(mouseEvent)) // Use original coordinates for menu bar
            }
            DebugLogger.log("TApplication: Sending mouse event to desktop with position=(\(adjustedMouseEvent.position.x), \(adjustedMouseEvent.position.y))")
            desktop.handleEvent(.mouse(adjustedMouseEvent)) // Use adjusted coordinates for desktop
            
        case .terminalResize:
            let (cols, rows) = SwiftyTermUI.shared.getTerminalSize()
            desktop.frame = Rect(x: 0, y: 0, width: cols, height: rows)
            if let menuBar = menuBar {
                menuBar.frame = Rect(x: 0, y: 0, width: cols, height: 1)
            }
            redraw()
        }
    }
    
    private func convertMouseEvent(_ event: InputMouseEvent) -> TEvent.MouseEvent {
        // Terminal sends coordinates in SGR format: \u{1B}[<button;column;rowM
        // where column is x (horizontal) and row is y (vertical)
        // InputMouseEvent stores: column (x) and row (y)
        let position = Point(x: event.column, y: event.row)
        return TEvent.MouseEvent(
            position: position,
            button: mapButton(event.button),
            action: mapAction(event.action),
            modifiers: mapModifiers(event.modifiers)
        )
    }
    
    private func mapButton(_ button: InputMouseEvent.Button) -> TEvent.MouseEvent.Button {
        switch button {
        case .left: return .left
        case .middle: return .middle
        case .right: return .right
        case .wheelUp: return .wheelUp
        case .wheelDown: return .wheelDown
        case .none: return .none
        }
    }
    
    private func mapAction(_ action: InputMouseEvent.Action) -> TEvent.MouseEvent.Action {
        switch action {
        case .down: return .down
        case .up: return .up
        case .drag: return .drag
        case .move: return .move
        case .scroll: return .scroll
        }
    }
    
    private func mapModifiers(_ modifiers: InputMouseEvent.Modifiers) -> TEvent.MouseEvent.Modifiers {
        var translated: TEvent.MouseEvent.Modifiers = []
        if modifiers.contains(.shift) { translated.insert(.shift) }
        if modifiers.contains(.alt) { translated.insert(.alt) }
        if modifiers.contains(.control) { translated.insert(.control) }
        return translated
    }
    
    @MainActor
    public func redraw() {
        desktop.draw()
        menuBar?.draw()
        // Draw cursor after menu bar so it appears on top
        desktop.drawCursor()
        try? SwiftyTermUI.shared.refresh()
    }
}
