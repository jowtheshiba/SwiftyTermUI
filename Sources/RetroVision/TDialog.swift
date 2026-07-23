import SwiftyTermUI

/// Classic Turbo Vision-style dialog window
public class TDialog: TWindow {
    public init(frame: Rect, title: String) {
        super.init(frame: frame, title: title, style: .dialog)
        allowResizing = false
    }

    @MainActor
    public override func handleCommand(_ command: TEvent.Command) -> Bool {
        if command == .cancel {
            close()
            return true
        }
        return super.handleCommand(command)
    }
}
