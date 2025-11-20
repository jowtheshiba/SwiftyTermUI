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
            // Adjust desktop frame if needed?
            // For now, just let them overlap or manual adjustment
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
                // Handle events
                if let event = SwiftyTermUI.shared.readEvent() {
                    handleLowLevelEvent(event)
                }
                
                // Redraw if needed (optimized by SwiftyTermUI)
                redraw()
                
                // Sleep a bit to save CPU
                Thread.sleep(forTimeInterval: 0.01)
            }
        } catch {
            print("Error: \(error)")
        }
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
            DebugLogger.log("TApplication received mouse input button=\(mouse.button) action=\(mouse.action) col=\(mouse.column) row=\(mouse.row) modifiers=\(mouse.modifiers.rawValue)")
            let mouseEvent = convertMouseEvent(mouse)
            
            // Adjust mouse coordinates to account for menu bar if present
            // Menu bar occupies the first row (y=0), so we need to adjust coordinates for desktop
            var adjustedMouseEvent = mouseEvent
            if let menuBar = menuBar, menuBar.isVisible {
                let menuBarHeight = menuBar.frame.height
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
                }
            }
            
            DebugLogger.log("TApplication converted to Point(x=\(adjustedMouseEvent.position.x), y=\(adjustedMouseEvent.position.y))")
            if let menuBar = menuBar {
                menuBar.handleEvent(.mouse(mouseEvent)) // Use original coordinates for menu bar
            }
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
        try? SwiftyTermUI.shared.refresh()
    }
}
