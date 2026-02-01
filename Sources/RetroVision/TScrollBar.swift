import SwiftyTermUI

public class TScrollBar: TView {
    public enum Orientation {
        case vertical
    }
    
    public var orientation: Orientation
    public var totalItems: Int = 0 {
        didSet { clampValue() }
    }
    public var pageSize: Int = 0 {
        didSet { clampValue() }
    }
    public var value: Int = 0 {
        didSet {
            let clamped = clamp(value)
            if clamped != value {
                value = clamped
            } else if value != oldValue {
                onChange?(value)
            }
        }
    }
    
    public var onChange: ((Int) -> Void)?
    
    public init(frame: Rect, orientation: Orientation = .vertical) {
        self.orientation = orientation
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 0, frame.height > 0 else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        
        let arrowFg: Color = .indexed(30)
        let arrowBg: Color = .blue
        let trackFg: Color = .blue
        let trackBg: Color = .brightBlue
        let thumbFg: Color = .indexed(30)
        let thumbBg: Color = .blue
        
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: "░",
            attributes: [],
            foregroundColor: trackFg,
            backgroundColor: trackBg
        )
        
        switch orientation {
        case .vertical:
            drawVertical(
                tui: tui,
                origin: origin,
                arrowFg: arrowFg,
                arrowBg: arrowBg,
                trackFg: trackFg,
                trackBg: trackBg,
                thumbFg: thumbFg,
                thumbBg: thumbBg
            )
        }
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event, isFocused, handleKey(key) {
            return
        }
        super.handleEvent(event)
    }
    
    @MainActor
    public override func mouseEvent(_ event: TEvent.MouseEvent) {
        guard event.action == .down, event.button == .left else { return }
        guard bounds.contains(event.position) else { return }
        RetroTextUtils.focus(view: self)
        
        switch orientation {
        case .vertical:
            handleVerticalClick(event.position.y)
        }
    }
    
    // MARK: - Private
    
    private func handleKey(_ key: Key) -> Bool {
        switch key {
        case .up:
            value -= 1
            return true
        case .down:
            value += 1
            return true
        case .pageUp:
            value -= max(1, pageSize)
            return true
        case .pageDown:
            value += max(1, pageSize)
            return true
        case .home:
            value = 0
            return true
        case .end:
            value = maxValue()
            return true
        default:
            return false
        }
    }
    
    private func handleVerticalClick(_ localY: Int) {
        let height = frame.height
        if height <= 0 { return }
        if localY == 0 {
            value -= 1
            return
        }
        if localY == height - 1 {
            value += 1
            return
        }
        
        let trackHeight = max(1, height - 2)
        let thumbInfo = verticalThumb(trackHeight: trackHeight)
        let thumbStart = 1 + thumbInfo.position
        let thumbEnd = thumbStart + thumbInfo.size - 1
        
        if localY < thumbStart {
            value -= max(1, pageSize)
        } else if localY > thumbEnd {
            value += max(1, pageSize)
        } else {
            let relative = max(0, min(trackHeight - 1, localY - 1))
            let target = Int((Double(relative) / Double(max(1, trackHeight - 1))) * Double(maxValue()))
            value = target
        }
    }
    
    @MainActor
    private func drawVertical(
        tui: SwiftyTermUI,
        origin: Point,
        arrowFg: Color,
        arrowBg: Color,
        trackFg: Color,
        trackBg: Color,
        thumbFg: Color,
        thumbBg: Color
    ) {
        let height = frame.height
        if height <= 0 { return }
        
        tui.drawChar(
            row: origin.y,
            column: origin.x,
            character: "▲",
            attributes: [],
            foregroundColor: arrowFg,
            backgroundColor: arrowBg
        )
        if height > 1 {
            tui.drawChar(
                row: origin.y + height - 1,
                column: origin.x,
                character: "▼",
                attributes: [],
                foregroundColor: arrowFg,
                backgroundColor: arrowBg
            )
        }
        
        if height <= 2 { return }
        let trackHeight = height - 2
        let thumbInfo = verticalThumb(trackHeight: trackHeight)
        
        for i in 0..<trackHeight {
            let row = origin.y + 1 + i
            let isThumb = i >= thumbInfo.position && i < thumbInfo.position + thumbInfo.size
            tui.drawChar(
                row: row,
                column: origin.x,
                character: isThumb ? "▪" : "░",
                attributes: [],
                foregroundColor: isThumb ? thumbFg : trackFg,
                backgroundColor: isThumb ? thumbBg : trackBg
            )
        }
    }
    
    private func verticalThumb(trackHeight: Int) -> (position: Int, size: Int) {
        let total = max(1, totalItems)
        let page = max(1, pageSize)
        let thumbSize = max(1, Int(Double(page) / Double(total) * Double(trackHeight)))
        let maxPos = max(0, trackHeight - thumbSize)
        if maxValue() == 0 {
            return (0, min(trackHeight, thumbSize))
        }
        let pos = Int((Double(value) / Double(maxValue())) * Double(maxPos))
        return (max(0, min(pos, maxPos)), min(trackHeight, thumbSize))
    }
    
    private func maxValue() -> Int {
        max(0, totalItems - pageSize)
    }
    
    private func clamp(_ value: Int) -> Int {
        max(0, min(value, maxValue()))
    }
    
    private func clampValue() {
        value = clamp(value)
    }
}
