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

    /// The button pressed by Enter when the focused view doesn't use Enter itself
    @MainActor
    public var defaultButton: TButton? {
        focusableDescendants().compactMap { $0 as? TButton }.first { $0.isDefault }
    }

    @MainActor
    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event {
            switch key {
            case .escape:
                handleCommand(.cancel)
                return
            case .enter:
                let focused = findFocusedView()
                if !(focused?.consumesEnterKey ?? false), let button = defaultButton {
                    button.press()
                    return
                }
            default:
                break
            }
        }
        super.handleEvent(event)
    }
}
