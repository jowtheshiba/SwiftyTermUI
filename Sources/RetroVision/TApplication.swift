import Foundation
import SwiftyTermUI

/// The main application class
@MainActor
open class TApplication {
    public static let shared = TApplication()
    

    private var isRunning = false
    private var inputBlinkVisible = true
    private var lastInputBlinkToggle = Date()
    private let inputBlinkInterval: TimeInterval = 0.5
    
    private var lastMouseClickEvent: TEvent.MouseEvent?
    private var lastMouseClickTime: Date?
    private let doubleClickInterval: TimeInterval = 0.5
    
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
                
                handleInputBlinkTick()
                
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
        case .paste(let text):
            let tEvent = TEvent.paste(text)
            if let menuBar = menuBar {
                menuBar.handleEvent(tEvent)
            }
            
            desktop.handleEvent(tEvent)
            
            if let focused = desktop.findFocusedView(), focused is TInputLine || focused is TMemo {
                resetInputBlink()
                needsFullRedraw = false
                focused.draw()
                try? SwiftyTermUI.shared.refresh()
            } else {
                needsFullRedraw = true
            }
            
        case .keyPress(let key):
            if key == .ctrl("c") {
                postCommand(.quit)
                return
            }

            if key == .shiftF10, let focused = desktop.findFocusedView(), focused is TInputLine || focused is TMemo {
                focused.showContextMenuFromKeyboard()
                needsFullRedraw = true
                return
            }
            
            let tEvent = TEvent.key(key)
            // The menu bar is disabled while a modal window is up.
            // When a menu is open it owns the keyboard: don't double-deliver
            // navigation keys to the desktop.
            if let menuBar = menuBar, desktop.activeModal == nil {
                let wasMenuOpen = menuBar.isMenuOpen
                menuBar.handleEvent(tEvent)
                if wasMenuOpen || menuBar.isMenuOpen {
                    needsFullRedraw = true
                    return
                }
                // Global menu shortcuts (item key bindings) fire with the menu closed
                if menuBar.handleShortcut(key) {
                    needsFullRedraw = true
                    return
                }
            }

            desktop.handleEvent(tEvent)

            // Tab moves focus between views, so both the old and new focused
            // views need repainting — partial redraw is not enough
            let isFocusTraversalKey = key == .tab || key == .shiftTab

            if !isFocusTraversalKey, let focused = desktop.findFocusedView(), focused is TInputLine || focused is TMemo {
                resetInputBlink()
                needsFullRedraw = false
                focused.draw()
                try? SwiftyTermUI.shared.refresh()
            } else {
                needsFullRedraw = true
            }
            
        case .mouse(let mouse):
            var mouseEvent = convertMouseEvent(mouse)
            
            if mouseEvent.action == .down {
                let now = Date()
                if let lastTime = lastMouseClickTime, let lastEvent = lastMouseClickEvent,
                   now.timeIntervalSince(lastTime) <= doubleClickInterval,
                   lastEvent.button == mouseEvent.button,
                   lastEvent.position.x == mouseEvent.position.x,
                   lastEvent.position.y == mouseEvent.position.y {
                    mouseEvent.clickCount = 2
                    lastMouseClickTime = nil
                    lastMouseClickEvent = nil
                } else {
                    mouseEvent.clickCount = 1
                    lastMouseClickTime = now
                    lastMouseClickEvent = mouseEvent
                }
            }
            
            let isMoveOnly = mouse.action == .move  // только движение без кнопки — курсор-only
            
            if isMoveOnly {
                desktop.updateCursorOnly(globalPosition: mouseEvent.position)
            } else {
                desktop.updateCursorPosition(globalPosition: mouseEvent.position)
                needsFullRedraw = true
            }
            
            var menuBarHandled = false
            if let menuBar = menuBar, menuBar.isVisible, desktop.activeModal == nil {
                menuBarHandled = menuBar.handleMouseEvent(mouseEvent)
                if isMoveOnly && menuBarHandled {
                    menuBar.draw()
                }
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
            for view in desktop.subviews {
                if let statusLine = view as? TStatusLine {
                    statusLine.frame = Rect(x: 0, y: rows - 1, width: cols, height: 1)
                }
            }
            // Windows outside the new bounds would be unreachable
            desktop.clampWindowsToBounds()
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
    
    /// Presents a window modally: it is placed above other windows and
    /// receives all input exclusively until closed. Focus is moved to its
    /// first focusable child and restored to the previous owner on close.
    @MainActor
    public func present(modal window: TWindow) {
        window.isModal = true
        window.previousFocusedView = desktop.findFocusedView()
        desktop.addSubview(window)
        if let first = window.focusableDescendants().first {
            RetroTextUtils.focus(view: first)
        } else {
            RetroTextUtils.focus(view: window)
        }
        redraw()
    }

    /// Posts a framework command.
    /// `.quit` stops the run loop; other commands are first offered to the
    /// focused view and its superview chain, then broadcast to the desktop.
    @MainActor
    public func postCommand(_ command: TEvent.Command) {
        if command == .quit {
            isRunning = false
            return
        }

        if let focused = desktop.findFocusedView() {
            var current: TView? = focused
            while let view = current {
                if view.handleCommand(command) {
                    redraw()
                    return
                }
                current = view.superview
            }
        }

        desktop.handleEvent(.command(command))
        redraw()
    }

    @MainActor
    public func redraw() {
        desktop.draw()
        menuBar?.draw()
        desktop.drawCursor()
        try? SwiftyTermUI.shared.refresh()
    }

    @MainActor
    public func resetInputBlink() {
        inputBlinkVisible = true
        lastInputBlinkToggle = Date()
        TInputLine.cursorBlinkVisible = true
    }

    @MainActor
    private func handleInputBlinkTick() {
        let focused = desktop.findFocusedView()
        guard focused is TInputLine || focused is TMemo else { return }
        let now = Date()
        if now.timeIntervalSince(lastInputBlinkToggle) >= inputBlinkInterval {
            inputBlinkVisible.toggle()
            lastInputBlinkToggle = now
            TInputLine.cursorBlinkVisible = inputBlinkVisible
            focused?.draw()
            try? SwiftyTermUI.shared.refresh()
        }
    }
}
