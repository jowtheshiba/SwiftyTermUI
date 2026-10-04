import SwiftyTermUI

/// Classic Turbo Vision-style dialog window
public class TDialog: TWindow {
    public private(set) var modalResult: TEvent.Command?
    public var onModalEnd: ((TEvent.Command) -> Void)?

    public init(frame: Rect, title: String) {
        super.init(frame: frame, title: title, style: .dialog)
        allowResizing = false
    }

    func beginModal() {
        modalResult = nil
    }

    @MainActor
    public override func handleCommand(_ command: TEvent.Command) -> Bool {
        switch command {
        case .ok, .yes, .retry, .ignore:
            _ = endModal(command)
            return true
        case .cancel, .no, .abort:
            _ = endModal(command, validating: false)
            return true
        case .close:
            _ = endModal(.cancel, validating: false)
            return true
        default:
            return super.handleCommand(command)
        }
    }

    @MainActor
    @discardableResult
    public override func endModal(_ command: TEvent.Command) -> Bool {
        endModal(command, validating: true)
    }

    @MainActor
    @discardableResult
    public func endModal(_ command: TEvent.Command, validating: Bool) -> Bool {
        guard modalResult == nil else { return false }
        if validating && !valid(command) { return false }
        if command == .ok || command == .yes {
            commitHistory(in: self)
        }
        modalResult = command
        let completion = onModalEnd
        onModalEnd = nil
        super.close()
        completion?(command)
        return true
    }

    @MainActor
    private func commitHistory(in view: TView) {
        if let input = view as? TInputLine {
            input.commitHistory()
        }
        for child in view.subviews {
            commitHistory(in: child)
        }
    }

    @MainActor
    public override func close() {
        if isModal && modalResult == nil {
            _ = endModal(.cancel, validating: false)
        } else {
            super.close()
        }
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
                _ = handleCommand(.cancel)
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
