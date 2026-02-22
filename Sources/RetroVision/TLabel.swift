import SwiftyTermUI

public class TLabel: TView {
    public var text: String {
        didSet {
            updateParsedText()
        }
    }
    public weak var target: TView?
    public var attributes: TextAttributes
    
    private var displayText: String = ""
    private var hotKey: Character?
    private var underlineIndex: Int?
    
    public init(frame: Rect, text: String, target: TView? = nil, attributes: TextAttributes = []) {
        self.text = text
        self.target = target
        self.attributes = attributes
        super.init(frame: frame)
        updateParsedText()
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
        
        let row = origin.y + (frame.height - 1) / 2
        let display = RetroTextUtils.clampText(displayText, maxWidth: frame.width)
        tui.drawString(
            row: row,
            column: origin.x,
            text: display,
            attributes: attributes,
            foregroundColor: colors.fg,
            backgroundColor: colors.bg
        )
        
        if let underlineIndex, underlineIndex < display.count, underlineIndex < frame.width {
            var underlineAttributes = attributes
            underlineAttributes.insert(.underline)
            let charIndex = display.index(display.startIndex, offsetBy: underlineIndex)
            let ch = display[charIndex]
            tui.drawChar(
                row: row,
                column: origin.x + underlineIndex,
                character: ch,
                attributes: underlineAttributes,
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
            )
        }
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event, handleKey(key) {
            return
        }
        super.handleEvent(event)
    }
    
    @MainActor
    public override func mouseEvent(_ event: TEvent.MouseEvent) -> Bool {
        guard event.action == .down, event.button == .left else { return false }
        if bounds.contains(event.position) {
            activateTarget()
            return true
        }
        return false
    }
    
    // MARK: - Private
    
    private func updateParsedText() {
        let parsed = RetroTextUtils.parseHotKey(text)
        displayText = parsed.displayText
        hotKey = parsed.hotKey
        underlineIndex = parsed.underlineIndex
    }
    
    @MainActor
    private func handleKey(_ key: Key) -> Bool {
        if let hotKey, case .alt(let ch) = key {
            if String(ch).lowercased().first == hotKey {
                activateTarget()
                return true
            }
        }
        return false
    }
    
    @MainActor
    private func activateTarget() {
        guard let target else { return }
        RetroTextUtils.focus(view: target)
        TApplication.shared.redraw()
    }
}
