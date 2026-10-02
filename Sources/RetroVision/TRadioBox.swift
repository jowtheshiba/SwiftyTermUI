import SwiftyTermUI

public class TRadioBox: TView {
    public override var canFocus: Bool { true }
    public let groupID: String
    public var title: String
    public var attributes: TextAttributes
    public var onSelect: (() -> Void)?
    public var isSelected: Bool {
        didSet {
            if isSelected != oldValue {
                if isSelected {
                    deselectSiblings()
                    onSelect?()
                }
            }
        }
    }
    
    private var isMouseDownInside = false
    
    public init(frame: Rect, title: String, groupID: String = "default", isSelected: Bool = false, attributes: TextAttributes = [], onSelect: (() -> Void)? = nil) {
        self.groupID = groupID
        self.title = title
        self.isSelected = isSelected
        self.attributes = attributes
        self.onSelect = onSelect
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 0, frame.height > 0 else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let controlFg: Color = TTheme.current.control.fg
        let controlBg: Color = TTheme.current.control.bg
        
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: controlFg,
            backgroundColor: controlBg
        )
        
        let row = origin.y + (frame.height - 1) / 2
        let mark = isSelected ? "●" : " "
        let text = "(\(mark)) \(title)"
        let display = RetroTextUtils.clampText(text, maxWidth: frame.width)
        
        let drawAttributes = attributes
        
        tui.drawString(
            row: row,
            column: origin.x,
            text: display,
            attributes: drawAttributes,
            foregroundColor: controlFg,
            backgroundColor: controlBg
        )
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        switch event {
        case .key(let key):
            if isFocused, key == .enter || key == .character(" ") {
                select()
                return
            }
        default:
            break
        }
        super.handleEvent(event)
    }
    
    @MainActor
    public override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        switch event.action {
        case .down where event.button == .left:
            if bounds.contains(event.position) {
                isMouseDownInside = true
                RetroTextUtils.focus(view: self)
                return true
            }
        case .up where event.button == .left:
            let shouldSelect = isMouseDownInside && bounds.contains(event.position)
            isMouseDownInside = false
            if shouldSelect {
                select()
                return true
            }
        default:
            break
        }
        return false
    }

    @MainActor
    public override var dataSize: Int { 1 }

    @MainActor
    public override func getData() -> TViewData? {
        .boolean(isSelected)
    }

    @MainActor
    @discardableResult
    public override func setData(_ data: TViewData) -> Bool {
        guard case .boolean(let value) = data else { return false }
        isSelected = value
        return true
    }
    
    private func select() {
        if !isSelected {
            isSelected = true
        }
    }
    
    private func deselectSiblings() {
        guard let container = superview else { return }
        for view in container.subviews {
            guard let radio = view as? TRadioBox else { continue }
            guard radio !== self, radio.groupID == groupID else { continue }
            radio.isSelected = false
        }
    }
}
