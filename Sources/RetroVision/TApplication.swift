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
            
            isRunning = true
            
            // Initial draw
            redraw()
            
            while isRunning {
                var hasEvents = false
                var needsRedraw = false
                
                // Process events - redraw immediately after mouse events for responsive cursor
                for _ in 0..<20 {
                    if let event = SwiftyTermUI.shared.readEvent() {
                        hasEvents = true
                        handleLowLevelEvent(event)
                        
                        // Mouse events need immediate redraw for responsive cursor
                        if case .mouse = event {
                            redraw()
                        } else {
                            needsRedraw = true
                        }
                    } else {
                        break // No more events available
                    }
                }
                
                // Redraw for keyboard events
                if needsRedraw {
                    redraw()
                }
                
                // Very small sleep only when idle to prevent CPU spinning
                if !hasEvents {
                    Thread.sleep(forTimeInterval: 0.001) // 1ms when idle
                }
            }
        } catch {
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
            let mouseEvent = convertMouseEvent(mouse)
            desktop.updateCursorPosition(globalPosition: mouseEvent.position)
            
            // Check if mouse is in menu bar area (y == 0) or potentially in dropdown
            // Menu bar is always at y=0, dropdown appears below it
            let isInMenuBarArea = mouseEvent.position.y == 0
            let mightBeInDropdown = mouseEvent.position.y > 0 && mouseEvent.position.y < 20 // Dropdowns are typically < 20 rows
            
            // First, always try menu bar if mouse is in menu bar area or might be in dropdown
            var menuBarHandled = false
            if let menuBar = menuBar, menuBar.isVisible && (isInMenuBarArea || mightBeInDropdown) {
                // Menu bar's handleMouseEvent returns true if it handled the event
                menuBarHandled = menuBar.handleMouseEvent(mouseEvent)
            }
            
            // Only send to desktop if menu bar didn't handle it and mouse is not in menu bar row
            if !menuBarHandled && !isInMenuBarArea {
                desktop.handleEvent(.mouse(mouseEvent))
            }
            
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
