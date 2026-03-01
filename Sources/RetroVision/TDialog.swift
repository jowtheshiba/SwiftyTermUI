import SwiftyTermUI

/// Classic Turbo Vision-style dialog window
public class TDialog: TWindow {
    public init(frame: Rect, title: String) {
        super.init(frame: frame, title: title, style: .dialog)
        allowResizing = false
    }
}
