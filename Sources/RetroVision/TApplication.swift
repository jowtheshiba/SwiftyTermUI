import Foundation
import SwiftyTermUI

/// The main application class
@MainActor
open class TApplication {
    public static let shared = TApplication()
    

    private var isRunning = false
    
    public init() {}
    
    private lazy var _desktop: TDesktop = {
        let (cols, rows) = SwiftyTermUI.shared.getTerminalSize()
        return TDesktop(frame: Rect(x: 0, y: 0, width: cols, height: rows))
    }()
    
    public var menuBar: TMenuBar? {
        didSet {
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
            
            redraw()
            
            while isRunning {
                var hasEvents = false
                var needsRedraw = false
                
                for _ in 0..<64 {
                    if let event = SwiftyTermUI.shared.readEvent() {
                        hasEvents = true
                        handleLowLevelEvent(event, needsFullRedraw: &needsRedraw)
                        if needsRedraw {
                            redraw()
                            needsRedraw = false
                            break
                        }
                    } else {
                        break
                    }
                }
                
                if !hasEvents {
                    Thread.sleep(forTimeInterval: 0.001)
                }
            }
        } catch {
        }
    }
    
    private func isMouseMoveEvent(_ event: InputEvent) -> Bool {
        if case .mouse(let mouse) = event {
            return mouse.action == .move || mouse.action == .drag
        }
        return false
    }
    
    private func isMouseClickEvent(_ event: InputEvent) -> Bool {
        if case .mouse(let mouse) = event {
            return mouse.action == .down || mouse.action == .up
        }
        return false
    }
    
    @MainActor
    private func handleLowLevelEvent(_ event: InputEvent, needsFullRedraw: inout Bool) {
        switch event {
        case .keyPress(let key):
            if key == .ctrl("c") {
                isRunning = false
                return
            }
            
            let tEvent = TEvent.key(key)
            if let menuBar = menuBar {
                menuBar.handleEvent(tEvent)
            }
            
            desktop.handleEvent(tEvent)
            
            if let focused = desktop.findFocusedView(), focused is TInputLine {
                needsFullRedraw = false
                focused.draw()
                try? SwiftyTermUI.shared.refresh()
            } else {
                needsFullRedraw = true
            }
            
        case .mouse(let mouse):
            let mouseEvent = convertMouseEvent(mouse)
            let isMoveOnly = mouse.action == .move  // только движение без кнопки — курсор-only
            
            if isMoveOnly {
                desktop.updateCursorOnly(globalPosition: mouseEvent.position)
            } else {
                desktop.updateCursorPosition(globalPosition: mouseEvent.position)
                needsFullRedraw = true
            }
            
            let isInMenuBarArea = mouseEvent.position.y == 0
            
            var menuBarHandled = false
            if let menuBar = menuBar, menuBar.isVisible && isInMenuBarArea {
                menuBarHandled = menuBar.handleMouseEvent(mouseEvent)
            }
            
            if !menuBarHandled {
                desktop.handleEvent(.mouse(mouseEvent))
            }
            
            if isMoveOnly {
                try? SwiftyTermUI.shared.refresh()
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
        desktop.drawCursor()
        try? SwiftyTermUI.shared.refresh()
    }
}
