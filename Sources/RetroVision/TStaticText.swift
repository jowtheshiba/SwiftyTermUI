import SwiftyTermUI

public class TStaticText: TView {
    public var text: String
    public var attributes: TextAttributes
    
    public init(frame: Rect, text: String, attributes: TextAttributes = []) {
        self.text = text
        self.attributes = attributes
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 0, frame.height > 0 else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let colors = RetroTextUtils.resolvedContentColors(for: self)
        
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: colors.fg,
            backgroundColor: colors.bg
        )
        
        let lines = RetroTextUtils.wrapText(text, maxWidth: frame.width, maxLines: frame.height)
        for (index, line) in lines.enumerated() {
            let display = RetroTextUtils.clampText(line, maxWidth: frame.width)
            tui.drawString(
                row: origin.y + index,
                column: origin.x,
                text: display,
                attributes: attributes,
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
            )
        }
    }
}
