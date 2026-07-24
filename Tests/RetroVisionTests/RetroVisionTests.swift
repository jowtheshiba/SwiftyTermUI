import XCTest
@testable import RetroVision
import SwiftyTermUI

@MainActor
final class RetroVisionTests: XCTestCase {

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

    func testFocusableDescendantsSkipsNonFocusable() {
        let (dialog, _, _, _) = makeDialog()
        XCTAssertEqual(dialog.focusableDescendants().count, 3)
    }

    func testTabCyclesFocusWithWraparound() {
        let desktop = makeDesktop()
        let (dialog, input, checkbox, ok) = makeDialog()
        desktop.addSubview(dialog)

        desktop.handleEvent(.key(.tab))
        XCTAssertTrue(input.isFocused, "Tab with no focus enters first child of topmost window")

        dialog.handleEvent(.key(.tab))
        XCTAssertTrue(checkbox.isFocused)
        dialog.handleEvent(.key(.tab))
        XCTAssertTrue(ok.isFocused)
        dialog.handleEvent(.key(.tab))
        XCTAssertTrue(input.isFocused, "Tab wraps around")
        dialog.handleEvent(.key(.shiftTab))
        XCTAssertTrue(ok.isFocused, "Shift+Tab wraps backwards")
    }

    // MARK: - Key routing

    func testKeysRoutedOnlyToFocusedWindow() {
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
        XCTAssertTrue(checkbox.isChecked, "space toggles the focused checkbox")
        XCTAssertFalse(cb2.isChecked, "unfocused window's checkbox untouched")
    }

    // MARK: - Modality

    func testModalOwnsKeyboardAndSwallowsOutsideClicks() {
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

        XCTAssertTrue(desktop.activeModal === modal)

        checkbox.isChecked = false
        desktop.handleEvent(.key(.character("a")))
        XCTAssertEqual(mInput.text, "a", "typing goes to the modal")
        XCTAssertFalse(checkbox.isChecked, "background widgets get nothing")

        let bgClick = TEvent.MouseEvent(position: Point(x: 46, y: 3), button: .left, action: .down)
        _ = desktop.handleMouseEvent(bgClick)
        XCTAssertFalse(win2.isFocused, "click on a background window is swallowed")
        XCTAssertTrue(mInput.isFocused)
    }

    func testPresentModalFocusesChildAndRestoresOnClose() {
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

        XCTAssertTrue(mInput.isFocused, "present(modal:) focuses the first focusable child")

        modal.handleEvent(.key(.escape))
        XCTAssertNil(desktop.subviews.first { $0 === modal }, "Esc closes the modal")
        XCTAssertTrue(checkbox.isFocused, "focus restored to the previous owner")

        for view in desktop.subviews { view.removeFromSuperview() }
    }

    // MARK: - Dialog conventions

    func testEnterPressesDefaultButtonUnlessFocusedViewUsesEnter() {
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
        XCTAssertTrue(okPressed, "Enter in an input presses the default button")

        okPressed = false
        RetroTextUtils.focus(view: other)
        dialog.handleEvent(.key(.enter))
        XCTAssertTrue(otherPressed, "Enter on a focused button presses that button")
        XCTAssertFalse(okPressed)
    }

    func testEscClosesDialogViaCancel() {
        let desktop = makeDesktop()
        let (dialog, _, _, _) = makeDialog()
        var closed = false
        dialog.onClose = { closed = true }
        desktop.addSubview(dialog)

        dialog.handleEvent(.key(.escape))
        XCTAssertTrue(closed)
        XCTAssertNil(desktop.subviews.first { $0 === dialog })
    }

    // MARK: - Commands

    func testCloseCommandClosesWindow() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 0, y: 0, width: 20, height: 8), title: "W")
        desktop.addSubview(window)
        desktop.handleEvent(.command(.close))
        XCTAssertTrue(desktop.subviews.isEmpty, "broadcast .close reaches the topmost window")
    }

    // MARK: - Popup overlay

    func testOpenPopupOwnsInput() {
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
        XCTAssertFalse(checkbox.isChecked, "popup consumes keys")

        desktop.handleEvent(.key(.enter))
        XCTAssertTrue(fired, "Enter activates the popup item")
        XCTAssertNil(desktop.subviews.first { $0 === menu }, "popup dismissed")
    }

    // MARK: - Close button

    func testCloseButtonClick() {
        let desktop = makeDesktop()
        var closed = false
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 20, height: 8), title: "Closable")
        window.onClose = { closed = true }
        desktop.addSubview(window)

        // [■] occupies columns x+2...x+4 of the title row
        let click = TEvent.MouseEvent(position: Point(x: 13, y: 5), button: .left, action: .down)
        _ = desktop.handleMouseEvent(click)
        XCTAssertTrue(closed)
        XCTAssertNil(desktop.subviews.first { $0 === window })
    }

    func testCloseButtonRespectsAllowClosing() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 20, height: 8), title: "NoClose")
        window.allowClosing = false
        desktop.addSubview(window)

        let click = TEvent.MouseEvent(position: Point(x: 13, y: 5), button: .left, action: .down)
        _ = desktop.handleMouseEvent(click)
        XCTAssertNotNil(desktop.subviews.first { $0 === window })
    }

    // MARK: - Menu shortcuts

    func testMenuShortcutsFireBoundItems() {
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

        XCTAssertTrue(bar.handleShortcut(.f2))
        XCTAssertTrue(saved)
        XCTAssertTrue(bar.handleShortcut(.ctrl("n")), "shortcuts are found in submenus")
        XCTAssertTrue(nested)
        XCTAssertFalse(bar.handleShortcut(.f9), "unbound keys are not consumed")

        bar.handleEvent(.key(.alt("e")))
        XCTAssertTrue(bar.isMenuOpen, "Alt+E opens the Edit menu")
        XCTAssertFalse(bar.handleShortcut(.f2), "shortcuts are inactive while a menu is open")
        bar.handleEvent(.key(.escape))
        XCTAssertFalse(bar.isMenuOpen)
        bar.handleEvent(.key(.alt("z")))
        XCTAssertFalse(bar.isMenuOpen, "Alt with no matching menu does nothing")
    }

    // MARK: - Window management commands

    func testZoomTogglesBetweenFrameAndArrangeArea() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 30, height: 10), title: "W")
        desktop.addSubview(window)
        let original = window.frame

        XCTAssertTrue(window.handleCommand(.zoom))
        XCTAssertTrue(window.isZoomed)
        XCTAssertEqual(window.frame, desktop.arrangeArea())

        XCTAssertTrue(window.handleCommand(.zoom))
        XCTAssertFalse(window.isZoomed)
        XCTAssertEqual(window.frame, original, "unzoom restores the original frame")
    }

    func testZoomRespectsMenuBarAndStatusLine() {
        let desktop = makeDesktop()
        desktop.menuBarHeight = 1
        desktop.addSubview(TStatusLine(frame: Rect(x: 0, y: 23, width: 80, height: 1), items: []))
        let area = desktop.arrangeArea()
        XCTAssertEqual(area, Rect(x: 0, y: 1, width: 80, height: 22))
    }

    func testNextAndPreviousCycleWindows() {
        let desktop = makeDesktop()
        let winA = TWindow(frame: Rect(x: 0, y: 0, width: 20, height: 8), title: "A")
        let winB = TWindow(frame: Rect(x: 25, y: 0, width: 20, height: 8), title: "B")
        desktop.addSubview(winA)
        desktop.addSubview(winB)

        XCTAssertTrue(desktop.handleCommand(.next))
        XCTAssertTrue(winA.isFocused, "front window B yields to A")
        XCTAssertTrue(desktop.subviews.last { $0 is TWindow } === winA, "A brought to front")

        XCTAssertTrue(desktop.handleCommand(.previous))
        XCTAssertTrue(winB.isFocused, "previous cycles back")
    }

    func testTileArrangesWindowsInsideArea() {
        let desktop = makeDesktop()
        desktop.menuBarHeight = 1
        let windows = (0..<3).map { i in
            TWindow(frame: Rect(x: i * 5, y: i * 3, width: 30, height: 10), title: "W\(i)")
        }
        windows.forEach { desktop.addSubview($0) }

        desktop.tileWindows()

        let area = desktop.arrangeArea()
        for window in windows {
            XCTAssertGreaterThanOrEqual(window.frame.x, area.x)
            XCTAssertGreaterThanOrEqual(window.frame.y, area.y)
            XCTAssertLessThanOrEqual(window.frame.maxX, area.maxX)
            XCTAssertLessThanOrEqual(window.frame.maxY, area.maxY)
        }
        // No two windows share an origin
        let origins = Set(windows.map { "\($0.frame.x),\($0.frame.y)" })
        XCTAssertEqual(origins.count, windows.count)
    }

    func testCascadeStaggersWindows() {
        let desktop = makeDesktop()
        let winA = TWindow(frame: Rect(x: 0, y: 0, width: 30, height: 10), title: "A")
        let winB = TWindow(frame: Rect(x: 40, y: 12, width: 30, height: 10), title: "B")
        desktop.addSubview(winA)
        desktop.addSubview(winB)

        desktop.cascadeWindows()

        XCTAssertEqual(winA.frame.width, winB.frame.width, "cascaded windows share a size")
        XCTAssertEqual(winB.frame.x - winA.frame.x, 2)
        XCTAssertEqual(winB.frame.y - winA.frame.y, 1)
    }

    func testDialogsAreNotTiled() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 0, y: 0, width: 30, height: 10), title: "W")
        let dialog = TDialog(frame: Rect(x: 40, y: 12, width: 30, height: 10), title: "D")
        desktop.addSubview(window)
        desktop.addSubview(dialog)
        let dialogFrame = dialog.frame

        desktop.tileWindows()
        XCTAssertEqual(dialog.frame, dialogFrame, "dialogs keep their frame")
    }

    // MARK: - Keyboard Size/Move mode

    func testKeyboardMoveResizeMode() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 20, height: 8), title: "W")
        desktop.addSubview(window)

        XCTAssertTrue(window.handleCommand(.resize))
        XCTAssertTrue(desktop.keyboardArrangeWindow === window)
        XCTAssertTrue(window.isDragging, "border highlighted while in mode")

        desktop.handleEvent(.key(.right))
        desktop.handleEvent(.key(.down))
        XCTAssertEqual(window.frame.x, 11)
        XCTAssertEqual(window.frame.y, 6)

        desktop.handleEvent(.key(.shiftRight))
        desktop.handleEvent(.key(.shiftDown))
        XCTAssertEqual(window.frame.width, 21)
        XCTAssertEqual(window.frame.height, 9)

        desktop.handleEvent(.key(.enter))
        XCTAssertNil(desktop.keyboardArrangeWindow, "Enter commits and exits the mode")
        XCTAssertFalse(window.isDragging)
        XCTAssertEqual(window.frame, Rect(x: 11, y: 6, width: 21, height: 9))
    }

    func testKeyboardMoveResizeEscRestoresFrame() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 20, height: 8), title: "W")
        desktop.addSubview(window)
        let original = window.frame

        desktop.beginKeyboardMoveResize(for: window)
        desktop.handleEvent(.key(.right))
        desktop.handleEvent(.key(.shiftDown))
        XCTAssertNotEqual(window.frame, original)

        desktop.handleEvent(.key(.escape))
        XCTAssertEqual(window.frame, original, "Esc cancels all changes")
        XCTAssertNil(desktop.keyboardArrangeWindow)
    }

    func testKeyboardMoveClampsToDesktop() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 0, y: 0, width: 20, height: 8), title: "W")
        desktop.addSubview(window)

        desktop.beginKeyboardMoveResize(for: window)
        desktop.handleEvent(.key(.left))
        desktop.handleEvent(.key(.up))
        XCTAssertEqual(window.frame.x, 0, "cannot move past the left edge")
        XCTAssertEqual(window.frame.y, 0)
        desktop.handleEvent(.key(.escape))
    }

    // MARK: - Terminal resize clamping

    func testClampWindowsToBounds() {
        let desktop = makeDesktop()
        let offscreen = TWindow(frame: Rect(x: 70, y: 20, width: 30, height: 10), title: "Off")
        let oversized = TWindow(frame: Rect(x: 0, y: 0, width: 200, height: 60), title: "Big")
        desktop.addSubview(offscreen)
        desktop.addSubview(oversized)

        desktop.frame = Rect(x: 0, y: 0, width: 60, height: 20)
        desktop.clampWindowsToBounds()

        XCTAssertLessThanOrEqual(offscreen.frame.maxX, 60)
        XCTAssertLessThanOrEqual(offscreen.frame.maxY, 20)
        XCTAssertEqual(oversized.frame, Rect(x: 0, y: 0, width: 60, height: 20), "oversized window shrunk to fit")
    }

    func testClampRefitsZoomedWindow() {
        let desktop = makeDesktop()
        let window = TWindow(frame: Rect(x: 10, y: 5, width: 30, height: 10), title: "W")
        desktop.addSubview(window)
        window.toggleZoom()
        XCTAssertEqual(window.frame, desktop.arrangeArea())

        desktop.frame = Rect(x: 0, y: 0, width: 50, height: 18)
        desktop.clampWindowsToBounds()
        XCTAssertEqual(window.frame, desktop.arrangeArea(), "zoomed window follows the new size")
    }
}
