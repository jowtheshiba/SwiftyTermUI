import SwiftyTermUI

public class TCheckBox: TView {
    public var title: String
    public var attributes: TextAttributes
    public var onToggle: ((Bool) -> Void)?
    public var isChecked: Bool {
        didSet {
            if isChecked != oldValue {
                onToggle?(isChecked)
            }
        }
    }
    
    private var isMouseDownInside = false
    
    public init(frame: Rect, title: String, isChecked: Bool = false, attributes: TextAttributes = [], onToggle: ((Bool) -> Void)? = nil) {
        self.title = title
        self.isChecked = isChecked
        self.attributes = attributes
        self.onToggle = onToggle
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
        let mark = isChecked ? "X" : " "
        let text = "[\(mark)] \(title)"
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
                toggle()
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
            let shouldToggle = isMouseDownInside && bounds.contains(event.position)
            isMouseDownInside = false
            if shouldToggle {
                toggle()
            }
        default:
            break
        }
    }
    
    private func toggle() {
        isChecked.toggle()
    }
}
