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
            defer { SwiftyTermUI.shared.shutdown() }
            
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
            
        case .terminalResize:
            let (cols, rows) = SwiftyTermUI.shared.getTerminalSize()
            desktop.frame = Rect(x: 0, y: 0, width: cols, height: rows)
            if let menuBar = menuBar {
                menuBar.frame = Rect(x: 0, y: 0, width: cols, height: 1)
            }
            redraw()
        }
    }
    
    @MainActor
    public func redraw() {
        desktop.draw()
        menuBar?.draw()
        try? SwiftyTermUI.shared.refresh()
    }
}
