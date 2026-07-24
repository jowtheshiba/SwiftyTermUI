import Testing
@testable import RetroVision
import SwiftyTermUI

@MainActor
struct RetroVisionTests {

    // MARK: - Fixtures

    private func makeDesktop() -> TDesktop {
        TDesktop(frame: Rect(x: 0, y: 0, width: 80, height: 24))
    }

    /// Dialog with input, checkbox, label (not focusable) and a button
    private func makeDialog() -> (TDialog, TInputLine, TCheckBox, TButton) {
        let dialog = TDialog(frame: Rect(x: 5, y: 3, width: 40, height: 12), title: "Test")
        let input = TInputLine(frame: Rect(x: 2, y: 2, width: 20, height: 1))
        let checkbox = TCheckBox(frame: Rect(x: 2, y: 4, width: 20, height: 1), title: "Check")
        let label = TLabel(frame: Rect(x: 2, y: 5, width: 10, height: 1), text: "Label")
        let ok = TButton(frame: Rect(x: 2, y: 8, width: 10, height: 1), title: "OK", action: {})
        ok.actionDelayMicroseconds = 0
        dialog.addSubview(input)
        dialog.addSubview(checkbox)
        dialog.addSubview(label)
        dialog.addSubview(ok)
        return (dialog, input, checkbox, ok)
    }

    // MARK: - Focus traversal

    @Test func focusableDescendantsSkipsNonFocusable() {
        let (dialog, _, _, _) = makeDialog()
        #expect(dialog.focusableDescendants().count == 3)
    }

    @Test func tabCyclesFocusWithWraparound() {
        let desktop = makeDesktop()
        let (dialog, input, checkbox, ok) = makeDialog()
        desktop.addSubview(dialog)

        desktop.handleEvent(.key(.tab))
        #expect(input.isFocused, "Tab with no focus enters first child of topmost window")

        dialog.handleEvent(.key(.tab))
        #expect(checkbox.isFocused)
        dialog.handleEvent(.key(.tab))
        #expect(ok.isFocused)
        dialog.handleEvent(.key(.tab))
        #expect(input.isFocused, "Tab wraps around")
        dialog.handleEvent(.key(.shiftTab))
        #expect(ok.isFocused, "Shift+Tab wraps backwards")
    }

    // MARK: - Key routing

    @Test func keysRoutedOnlyToFocusedWindow() {
        let desktop = makeDesktop()
        let (dialog, _, checkbox, _) = makeDialog()
        desktop.addSubview(dialog)

        let win2 = TWindow(frame: Rect(x: 45, y: 3, width: 30, height: 10), title: "Other")
        let cb2 = TCheckBox(frame: Rect(x: 2, y: 2, width: 20, height: 1), title: "Other check")
        win2.addSubview(cb2)
        desktop.addSubview(win2)

        RetroTextUtils.focus(view: checkbox)
        checkbox.isChecked = false
        cb2.isChecked = false

        desktop.handleEvent(.key(.character(" ")))
        #expect(checkbox.isChecked, "space toggles the focused checkbox")
        #expect(!(cb2.isChecked), "unfocused window's checkbox untouched")
    }

    // MARK: - Modality

    @Test func modalOwnsKeyboardAndSwallowsOutsideClicks() {
        let desktop = makeDesktop()
        let (dialog, _, checkbox, _) = makeDialog()
        desktop.addSubview(dialog)
        let win2 = TWindow(frame: Rect(x: 45, y: 3, width: 30, height: 10), title: "Back")
        desktop.addSubview(win2)

        let modal = TDialog(frame: Rect(x: 20, y: 8, width: 36, height: 9), title: "Modal")
        let mInput = TInputLine(frame: Rect(x: 2, y: 2, width: 20, height: 1))
        modal.addSubview(mInput)
        modal.isModal = true
        desktop.addSubview(modal)
        desktop.clearFocus()
        mInput.isFocused = true

        #expect(desktop.activeModal === modal)

        checkbox.isChecked = false
        desktop.handleEvent(.key(.character("a")))
        #expect(mInput.text == "a", "typing goes to the modal")
        #expect(!(checkbox.isChecked), "background widgets get nothing")

        let bgClick = TEvent.MouseEvent(position: Point(x: 46, y: 3), button: .left, action: .down)
        _ = desktop.handleMouseEvent(bgClick)
        #expect(!(win2.isFocused), "click on a background window is swallowed")
        #expect(mInput.isFocused)
    }

    @Test func presentModalFocusesChildAndRestoresOnClose() {
        let app = TApplication.shared
        let desktop = app.desktop
        for view in desktop.subviews { view.removeFromSuperview() }

        let (dialog, _, checkbox, _) = makeDialog()
        desktop.addSubview(dialog)
        RetroTextUtils.focus(view: checkbox)

        let modal = TDialog(frame: Rect(x: 20, y: 8, width: 36, height: 9), title: "Modal")
        let mInput = TInputLine(frame: Rect(x: 2, y: 2, width: 20, height: 1))
        modal.addSubview(mInput)
        app.present(modal: modal)

        #expect(mInput.isFocused, "present(modal:) focuses the first focusable child")

        modal.handleEvent(.key(.escape))
        #expect((desktop.subviews.first { $0 === modal }) == nil, "Esc closes the modal")
        #expect(checkbox.isFocused, "focus restored to the previous owner")

        for view in desktop.subviews { view.removeFromSuperview() }
    }

    // MARK: - Dialog conventions

    @Test func enterPressesDefaultButtonUnlessFocusedViewUsesEnter() {
        let desktop = makeDesktop()
        let dialog = TDialog(frame: Rect(x: 5, y: 3, width: 40, height: 12), title: "D")
        let input = TInputLine(frame: Rect(x: 2, y: 2, width: 20, height: 1))
        var okPressed = false
        let ok = TButton(frame: Rect(x: 2, y: 8, width: 10, height: 1), title: "OK", action: { okPressed = true })
        ok.actionDelayMicroseconds = 0
        ok.isDefault = true
        var otherPressed = false
        let other = TButton(frame: Rect(x: 14, y: 8, width: 10, height: 1), title: "No", action: { otherPressed = true })
        other.actionDelayMicroseconds = 0
        dialog.addSubview(input)
        dialog.addSubview(ok)
        dialog.addSubview(other)
        desktop.addSubview(dialog)

        RetroTextUtils.focus(view: input)
        dialog.handleEvent(.key(.enter))
        #expect(okPressed, "Enter in an input presses the default button")

        okPressed = false
        RetroTextUtils.focus(view: other)
        dialog.handleEvent(.key(.enter))
        #expect(otherPressed, "Enter on a focused button presses that button")
        #expect(!(okPressed))
    }

    @Test func escClosesDialogViaCancel() {
        let desktop = makeDesktop()
        let (dialog, _, _, _) = makeDialog()
        var closed = false
        dialog.onClose = { closed = true }
        desktop.addSubview(dialog)

        dialog.handleEvent(.key(.escape))
        #expect(closed)
        #expect((desktop.subviews.first { $0 === dialog }) == nil)
    }

    // MARK: - Commands

    @Test func closeCommandClosesWindow() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 0, y: 0, width: 20, height: 8), title: "W")
        desktop.addSubview(window)
        desktop.handleEvent(.command(.close))
        #expect(desktop.subviews.isEmpty, "broadcast .close reaches the topmost window")
    }

    // MARK: - Popup overlay

    @Test func openPopupOwnsInput() {
        let desktop = makeDesktop()
        let (dialog, _, checkbox, _) = makeDialog()
        desktop.addSubview(dialog)
        RetroTextUtils.focus(view: checkbox)

        var fired = false
        let menu = TPopupMenu(position: Point(x: 10, y: 5), items: [
            TMenuItem(title: "Do it", action: { fired = true })
        ])
        desktop.addSubview(menu)
        desktop.clearFocus()
        menu.isFocused = true

        checkbox.isChecked = false
        desktop.handleEvent(.key(.character(" ")))
        #expect(!(checkbox.isChecked), "popup consumes keys")

        desktop.handleEvent(.key(.enter))
        #expect(fired, "Enter activates the popup item")
        #expect((desktop.subviews.first { $0 === menu }) == nil, "popup dismissed")
    }

    // MARK: - Close button

    @Test func closeButtonClick() {
        let desktop = makeDesktop()
        var closed = false
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 20, height: 8), title: "Closable")
        window.onClose = { closed = true }
        desktop.addSubview(window)

        // [■] occupies columns x+2...x+4 of the title row
        let click = TEvent.MouseEvent(position: Point(x: 13, y: 5), button: .left, action: .down)
        _ = desktop.handleMouseEvent(click)
        #expect(closed)
        #expect((desktop.subviews.first { $0 === window }) == nil)
    }

    @Test func closeButtonRespectsAllowClosing() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 20, height: 8), title: "NoClose")
        window.allowClosing = false
        desktop.addSubview(window)

        let click = TEvent.MouseEvent(position: Point(x: 13, y: 5), button: .left, action: .down)
        _ = desktop.handleMouseEvent(click)
        #expect((desktop.subviews.first { $0 === window }) != nil)
    }

    // MARK: - Menu shortcuts

    @Test func menuShortcutsFireBoundItems() {
        var saved = false
        var nested = false
        let bar = TMenuBar(frame: Rect(x: 0, y: 0, width: 80, height: 1), menus: [
            TMenu(title: "File", items: [
                TMenuItem(title: "Save", action: { saved = true }, shortcut: "F2", shortcutKey: .f2)
            ]),
            TMenu(title: "Edit", items: [
                TMenuItem(title: "Deep", submenu: [
                    TMenuItem(title: "Nested", action: { nested = true }, shortcutKey: .ctrl("n"))
                ])
            ])
        ])

        #expect(bar.handleShortcut(.f2))
        #expect(saved)
        #expect(bar.handleShortcut(.ctrl("n")), "shortcuts are found in submenus")
        #expect(nested)
        #expect(!(bar.handleShortcut(.f9)), "unbound keys are not consumed")

        bar.handleEvent(.key(.alt("e")))
        #expect(bar.isMenuOpen, "Alt+E opens the Edit menu")
        #expect(!(bar.handleShortcut(.f2)), "shortcuts are inactive while a menu is open")
        bar.handleEvent(.key(.escape))
        #expect(!(bar.isMenuOpen))
        bar.handleEvent(.key(.alt("z")))
        #expect(!(bar.isMenuOpen), "Alt with no matching menu does nothing")
    }

    // MARK: - Window management commands

    @Test func zoomTogglesBetweenFrameAndArrangeArea() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 30, height: 10), title: "W")
        desktop.addSubview(window)
        let original = window.frame

        #expect(window.handleCommand(.zoom))
        #expect(window.isZoomed)
        #expect(window.frame == desktop.arrangeArea())

        #expect(window.handleCommand(.zoom))
        #expect(!(window.isZoomed))
        #expect(window.frame == original, "unzoom restores the original frame")
    }

    @Test func zoomRespectsMenuBarAndStatusLine() {
        let desktop = makeDesktop()
        desktop.menuBarHeight = 1
        desktop.addSubview(TStatusLine(frame: Rect(x: 0, y: 23, width: 80, height: 1), items: []))
        let area = desktop.arrangeArea()
        #expect(area == Rect(x: 0, y: 1, width: 80, height: 22))
    }

    @Test func nextAndPreviousCycleWindows() {
        let desktop = makeDesktop()
        let winA = TWindow(frame: Rect(x: 0, y: 0, width: 20, height: 8), title: "A")
        let winB = TWindow(frame: Rect(x: 25, y: 0, width: 20, height: 8), title: "B")
        desktop.addSubview(winA)
        desktop.addSubview(winB)

        #expect(desktop.handleCommand(.next))
        #expect(winA.isFocused, "front window B yields to A")
        #expect(desktop.subviews.last { $0 is TWindow } === winA, "A brought to front")

        #expect(desktop.handleCommand(.previous))
        #expect(winB.isFocused, "previous cycles back")
    }

    @Test func tileArrangesWindowsInsideArea() {
        let desktop = makeDesktop()
        desktop.menuBarHeight = 1
        let windows = (0..<3).map { i in
            TWindow(frame: Rect(x: i * 5, y: i * 3, width: 30, height: 10), title: "W\(i)")
        }
        windows.forEach { desktop.addSubview($0) }

        desktop.tileWindows()

        let area = desktop.arrangeArea()
        for window in windows {
            #expect(window.frame.x >= area.x)
            #expect(window.frame.y >= area.y)
            #expect(window.frame.maxX <= area.maxX)
            #expect(window.frame.maxY <= area.maxY)
        }
        // No two windows share an origin
        let origins = Set(windows.map { "\($0.frame.x),\($0.frame.y)" })
        #expect(origins.count == windows.count)
    }

    @Test func cascadeStaggersWindows() {
        let desktop = makeDesktop()
        let winA = TWindow(frame: Rect(x: 0, y: 0, width: 30, height: 10), title: "A")
        let winB = TWindow(frame: Rect(x: 40, y: 12, width: 30, height: 10), title: "B")
        desktop.addSubview(winA)
        desktop.addSubview(winB)

        desktop.cascadeWindows()

        #expect(winA.frame.width == winB.frame.width, "cascaded windows share a size")
        #expect(winB.frame.x - winA.frame.x == 2)
        #expect(winB.frame.y - winA.frame.y == 1)
    }

    @Test func dialogsAreNotTiled() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 0, y: 0, width: 30, height: 10), title: "W")
        let dialog = TDialog(frame: Rect(x: 40, y: 12, width: 30, height: 10), title: "D")
        desktop.addSubview(window)
        desktop.addSubview(dialog)
        let dialogFrame = dialog.frame

        desktop.tileWindows()
        #expect(dialog.frame == dialogFrame, "dialogs keep their frame")
    }

    // MARK: - Keyboard Size/Move mode

    @Test func keyboardMoveResizeMode() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 20, height: 8), title: "W")
        desktop.addSubview(window)

        #expect(window.handleCommand(.resize))
        #expect(desktop.keyboardArrangeWindow === window)
        #expect(window.isDragging, "border highlighted while in mode")

        desktop.handleEvent(.key(.right))
        desktop.handleEvent(.key(.down))
        #expect(window.frame.x == 11)
        #expect(window.frame.y == 6)

        desktop.handleEvent(.key(.shiftRight))
        desktop.handleEvent(.key(.shiftDown))
        #expect(window.frame.width == 21)
        #expect(window.frame.height == 9)

        desktop.handleEvent(.key(.enter))
        #expect((desktop.keyboardArrangeWindow) == nil, "Enter commits and exits the mode")
        #expect(!(window.isDragging))
        #expect(window.frame == Rect(x: 11, y: 6, width: 21, height: 9))
    }

    @Test func keyboardMoveResizeEscRestoresFrame() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 20, height: 8), title: "W")
        desktop.addSubview(window)
        let original = window.frame

        desktop.beginKeyboardMoveResize(for: window)
        desktop.handleEvent(.key(.right))
        desktop.handleEvent(.key(.shiftDown))
        #expect(window.frame != original)

        desktop.handleEvent(.key(.escape))
        #expect(window.frame == original, "Esc cancels all changes")
        #expect((desktop.keyboardArrangeWindow) == nil)
    }

    @Test func keyboardMoveClampsToDesktop() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 0, y: 0, width: 20, height: 8), title: "W")
        desktop.addSubview(window)

        desktop.beginKeyboardMoveResize(for: window)
        desktop.handleEvent(.key(.left))
        desktop.handleEvent(.key(.up))
        #expect(window.frame.x == 0, "cannot move past the left edge")
        #expect(window.frame.y == 0)
        desktop.handleEvent(.key(.escape))
    }

    // MARK: - Terminal resize clamping

    @Test func clampWindowsToBounds() {
        let desktop = makeDesktop()
        let offscreen = TWindow(frame: Rect(x: 70, y: 20, width: 30, height: 10), title: "Off")
        let oversized = TWindow(frame: Rect(x: 0, y: 0, width: 200, height: 60), title: "Big")
        desktop.addSubview(offscreen)
        desktop.addSubview(oversized)

        desktop.frame = Rect(x: 0, y: 0, width: 60, height: 20)
        desktop.clampWindowsToBounds()

        #expect(offscreen.frame.maxX <= 60)
        #expect(offscreen.frame.maxY <= 20)
        #expect(oversized.frame == Rect(x: 0, y: 0, width: 60, height: 20), "oversized window shrunk to fit")
    }

    @Test func clampRefitsZoomedWindow() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 30, height: 10), title: "W")
        desktop.addSubview(window)
        window.toggleZoom()
        #expect(window.frame == desktop.arrangeArea())

        desktop.frame = Rect(x: 0, y: 0, width: 50, height: 18)
        desktop.clampWindowsToBounds()
        #expect(window.frame == desktop.arrangeArea(), "zoomed window follows the new size")
    }
}
