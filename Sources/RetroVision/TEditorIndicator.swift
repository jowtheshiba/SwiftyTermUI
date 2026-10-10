import SwiftyTermUI

@MainActor
public final class TEditorIndicator: TView {
    public weak var editor: TEditor?

    public var displayText: String {
        guard let editor else { return "" }
        let position = "\(editor.cursorRow + 1):\(editor.cursorColumn + 1)"
        let modified = editor.isModified ? " Modified" : ""
        let mode = editor.isReadOnly ? "READ" : (editor.isOverwriteMode ? "OVR" : "INS")
        return " \(position)\(modified) \(mode) "
    }

    public init(frame: Rect, editor: TEditor? = nil) {
        self.editor = editor
        super.init(frame: frame)
    }

    public override func draw() {
        guard isVisible, frame.width > 0, frame.height > 0 else { return }
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let foreground = TTheme.current.windowFrame.fg
        let background = TTheme.current.windowFrame.bg
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: foreground,
            backgroundColor: background
        )
        tui.drawString(
            row: origin.y,
            column: origin.x,
            text: RetroTextUtils.clampText(displayText, maxWidth: frame.width),
            attributes: [],
            foregroundColor: foreground,
            backgroundColor: background
        )
    }
}
