import SwiftyTermUI

public class TScrollBar: TView {
    public enum Orientation {
        case vertical
        case horizontal
    }
    
    public struct Palette: Sendable {
        public var arrowFg: Color
        public var arrowBg: Color
        public var trackFg: Color
        public var trackBg: Color
        public var thumbFg: Color
        public var thumbBg: Color
        
        public static let listView = Palette(
            arrowFg: .rgb(0, 0, 170),
            arrowBg: .rgb(0, 170, 170),
            trackFg: .rgb(0, 0, 170),
            trackBg: .rgb(0, 170, 170),
            thumbFg: .rgb(0, 0, 170),
            thumbBg: .rgb(0, 170, 170)
        )
        
        public static let retroDefault = Palette(
            arrowFg: .indexed(30),
            arrowBg: .blue,
            trackFg: .blue,
            trackBg: .indexed(30),
            thumbFg: .indexed(30),
            thumbBg: .blue
        )
    }
    
    public struct Glyphs: Sendable {
        public var arrowUp: Character
        public var arrowDown: Character
        public var arrowLeft: Character
        public var arrowRight: Character
        public var track: Character
        public var thumb: Character
        
        public static let listView = Glyphs(
            arrowUp: "▲",
            arrowDown: "▼",
            arrowLeft: "◄",
            arrowRight: "►",
            track: "░",
            thumb: "▪"
        )
        
        public static let retroDefault = Glyphs(
            arrowUp: "▲",
            arrowDown: "▼",
            arrowLeft: "◄",
            arrowRight: "►",
            track: "░",
            thumb: "▪"
        )
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
    public var palette: Palette = .retroDefault
    public var glyphs: Glyphs = .retroDefault
    
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
        
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: glyphs.track,
            attributes: [],
            foregroundColor: palette.trackFg,
            backgroundColor: palette.trackBg
        )
        
        switch orientation {
        case .vertical:
            drawVertical(
                tui: tui,
                origin: origin,
                arrowFg: palette.arrowFg,
                arrowBg: palette.arrowBg,
                trackFg: palette.trackFg,
                trackBg: palette.trackBg,
                thumbFg: palette.thumbFg,
                thumbBg: palette.thumbBg
            )
        case .horizontal:
            drawHorizontal(
                tui: tui,
                origin: origin,
                arrowFg: palette.arrowFg,
                arrowBg: palette.arrowBg,
                trackFg: palette.trackFg,
                trackBg: palette.trackBg,
                thumbFg: palette.thumbFg,
                thumbBg: palette.thumbBg
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
        guard event.button == .left else { return }
        guard bounds.contains(event.position) else { return }
        RetroTextUtils.focus(view: self)
        
        switch orientation {
        case .vertical:
            let height = frame.height
            if height > 0 {
                if event.position.y == 0 {
                    value -= 1
                    return
                }
                if event.position.y == height - 1 {
                    value += 1
                    return
                }
            }
            if event.action == .down || event.action == .drag {
                handleVerticalDrag(event.position.y)
            }
        case .horizontal:
            let width = frame.width
            if width > 0 {
                if event.position.x == 0 {
                    value -= 1
                    return
                }
                if event.position.x == width - 1 {
                    value += 1
                    return
                }
            }
            if event.action == .down || event.action == .drag {
                handleHorizontalDrag(event.position.x)
            }
        }
    }
    
    // MARK: - Private
    
    private func handleKey(_ key: Key) -> Bool {
        switch orientation {
        case .vertical:
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
        case .horizontal:
            switch key {
            case .left:
                value -= 1
                return true
            case .right:
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
        let thumbInfo = verticalThumb(trackHeight: trackHeight, forceSingle: glyphs.thumb == "▪")
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
    
    private func handleVerticalDrag(_ localY: Int) {
        let height = frame.height
        if height <= 2 { return }
        let trackHeight = max(1, height - 2)
        let relative = max(0, min(trackHeight - 1, localY - 1))
        let target = Int((Double(relative) / Double(max(1, trackHeight - 1))) * Double(maxValue()))
        value = target
    }
    
    private func handleHorizontalClick(_ localX: Int) {
        let width = frame.width
        if width <= 0 { return }
        if localX == 0 {
            value -= 1
            return
        }
        if localX == width - 1 {
            value += 1
            return
        }
        
        let trackWidth = max(1, width - 2)
        let thumbInfo = horizontalThumb(trackWidth: trackWidth, forceSingle: glyphs.thumb == "▪")
        let thumbStart = 1 + thumbInfo.position
        let thumbEnd = thumbStart + thumbInfo.size - 1
        
        if localX < thumbStart {
            value -= max(1, pageSize)
        } else if localX > thumbEnd {
            value += max(1, pageSize)
        } else {
            let relative = max(0, min(trackWidth - 1, localX - 1))
            let target = Int((Double(relative) / Double(max(1, trackWidth - 1))) * Double(maxValue()))
            value = target
        }
    }
    
    private func handleHorizontalDrag(_ localX: Int) {
        let width = frame.width
        if width <= 2 { return }
        let trackWidth = max(1, width - 2)
        let relative = max(0, min(trackWidth - 1, localX - 1))
        let target = Int((Double(relative) / Double(max(1, trackWidth - 1))) * Double(maxValue()))
        value = target
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
            character: glyphs.arrowUp,
            attributes: [],
            foregroundColor: arrowFg,
            backgroundColor: arrowBg
        )
        if height > 1 {
            tui.drawChar(
                row: origin.y + height - 1,
                column: origin.x,
                character: glyphs.arrowDown,
                attributes: [],
                foregroundColor: arrowFg,
                backgroundColor: arrowBg
            )
        }
        
        if height <= 2 { return }
        let trackHeight = height - 2
        let thumbInfo = verticalThumb(trackHeight: trackHeight, forceSingle: glyphs.thumb == "▪")
        
        for i in 0..<trackHeight {
            let row = origin.y + 1 + i
            let isThumb = i >= thumbInfo.position && i < thumbInfo.position + thumbInfo.size
            tui.drawChar(
                row: row,
                column: origin.x,
                character: isThumb ? glyphs.thumb : glyphs.track,
                attributes: [],
                foregroundColor: isThumb ? thumbFg : trackFg,
                backgroundColor: isThumb ? thumbBg : trackBg
            )
        }
    }
    
    @MainActor
    private func drawHorizontal(
        tui: SwiftyTermUI,
        origin: Point,
        arrowFg: Color,
        arrowBg: Color,
        trackFg: Color,
        trackBg: Color,
        thumbFg: Color,
        thumbBg: Color
    ) {
        let width = frame.width
        if width <= 0 { return }
        
        tui.drawChar(
            row: origin.y,
            column: origin.x,
            character: glyphs.arrowLeft,
            attributes: [],
            foregroundColor: arrowFg,
            backgroundColor: arrowBg
        )
        if width > 1 {
            tui.drawChar(
                row: origin.y,
                column: origin.x + width - 1,
                character: glyphs.arrowRight,
                attributes: [],
                foregroundColor: arrowFg,
                backgroundColor: arrowBg
            )
        }
        
        if width <= 2 { return }
        let trackWidth = width - 2
        let thumbInfo = horizontalThumb(trackWidth: trackWidth, forceSingle: glyphs.thumb == "▪")
        
        for i in 0..<trackWidth {
            let column = origin.x + 1 + i
            let isThumb = i >= thumbInfo.position && i < thumbInfo.position + thumbInfo.size
            tui.drawChar(
                row: origin.y,
                column: column,
                character: isThumb ? glyphs.thumb : glyphs.track,
                attributes: [],
                foregroundColor: isThumb ? thumbFg : trackFg,
                backgroundColor: isThumb ? thumbBg : trackBg
            )
        }
    }
    
    private func verticalThumb(trackHeight: Int, forceSingle: Bool) -> (position: Int, size: Int) {
        let total = max(1, totalItems)
        let page = max(1, pageSize)
        if maxValue() == 0 {
            return (0, 0)
        }
        let thumbSize = forceSingle ? 1 : max(1, Int(Double(page) / Double(total) * Double(trackHeight)))
        let maxPos = max(0, trackHeight - thumbSize)
        let pos = Int((Double(value) / Double(maxValue())) * Double(maxPos))
        return (max(0, min(pos, maxPos)), min(trackHeight, thumbSize))
    }
    
    private func horizontalThumb(trackWidth: Int, forceSingle: Bool) -> (position: Int, size: Int) {
        let total = max(1, totalItems)
        let page = max(1, pageSize)
        if maxValue() == 0 {
            return (0, 0)
        }
        let thumbSize = forceSingle ? 1 : max(1, Int(Double(page) / Double(total) * Double(trackWidth)))
        let maxPos = max(0, trackWidth - thumbSize)
        let pos = Int((Double(value) / Double(maxValue())) * Double(maxPos))
        return (max(0, min(pos, maxPos)), min(trackWidth, thumbSize))
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
