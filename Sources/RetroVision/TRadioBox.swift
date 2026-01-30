import SwiftyTermUI

public class TRadioBox: TView {
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
        let controlFg: Color = .black
        let controlBg: Color = .indexed(30)
        
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
        let mark = isSelected ? "*" : " "
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
    public override func mouseEvent(_ event: TEvent.MouseEvent) {
        switch event.action {
        case .down where event.button == .left:
            if bounds.contains(event.position) {
                isMouseDownInside = true
                RetroTextUtils.focus(view: self)
            }
        case .up where event.button == .left:
            let shouldSelect = isMouseDownInside && bounds.contains(event.position)
            isMouseDownInside = false
            if shouldSelect {
                select()
            }
        default:
            break
        }
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
