import SwiftyTermUI

/// Classic Turbo Vision-style dialog window
public final class TDialog: TWindow {
    public init(frame: Rect, title: String) {
        super.init(frame: frame, title: title, style: .dialog)
        allowsResize = false
    }
}
