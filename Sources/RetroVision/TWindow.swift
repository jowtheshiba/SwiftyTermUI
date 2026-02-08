import SwiftyTermUI

/// A floating window with a title and border
public class TWindow: TView {
    public enum WindowStyle {
        case window // Blue background (Editor)
        case dialog // Grey background (Dialog)
    }
    
    public var title: String
    public var style: WindowStyle
    public var isDragging: Bool = false
    public var isResizing: Bool = false
    public var allowResizing: Bool = true
    // Backwards-compat alias
    public var allowsResize: Bool {
        get { allowResizing }
        set { allowResizing = newValue }
    }
    public var minWidth: Int = 10
    public var minHeight: Int = 5
    
    public var showsVerticalScrollBar: Bool = false {
        didSet { updateScrollBars() }
    }
    public var showsHorizontalScrollBar: Bool = false {
        didSet { updateScrollBars() }
    }
    
    public private(set) var verticalScrollBar: TScrollBar?
    public private(set) var horizontalScrollBar: TScrollBar?
    
    public var onDrawContent: ((Rect) -> Void)?
    
    public init(frame: Rect, title: String, style: WindowStyle = .window) {
        self.title = title
        self.style = style
        self.allowResizing = true
        super.init(frame: frame)
    }
    
    public var contentFrame: Rect {
        let innerWidth = max(0, frame.width - 2)
        let innerHeight = max(0, frame.height - 2)
        return Rect(x: 1, y: 1, width: innerWidth, height: innerHeight)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        
        let tui = SwiftyTermUI.shared
        let globalPos = localToGlobal(Point(x: 0, y: 0))
        
        // Colors based on style
        var frameFg: Color
        var frameBg: Color
        let contentFg: Color
        let contentBg: Color
        
        switch style {
        case .window:
            // Editor Style: Blue background, White text
            frameFg = .white
            frameBg = .blue
            contentFg = .white
            contentBg = .blue
        case .dialog:
            // Dialog Style: Grey background, Black text
            frameFg = .brightWhite // Bright white borders on grey
            frameBg = .white // ANSI White is Grey
            contentFg = .black
            contentBg = .white
        }
        
        let borderHighlight = isDragging || isResizing
        let borderFg: Color = borderHighlight ? .brightGreen : frameFg
        let titleFg: Color = borderHighlight ? .brightGreen : frameFg
        
        // 1. Draw Shadow
        // Shadow is offset by (1, 1) and is usually black/dark grey
        // We can simulate shadow by drawing spaces with black background or dark grey foreground
        // For simplicity, let's use black background
        tui.fillRect(
            row: globalPos.y + 1,
            column: globalPos.x + 1,
            width: frame.width + 1,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: .black,
            backgroundColor: .black // Shadow color
        )
        
        // 2. Draw Frame Background
        tui.fillRect(
            row: globalPos.y,
            column: globalPos.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: frameFg,
            backgroundColor: frameBg
        )
        
        // 3. Draw Double Border (skip right/bottom when scrollbars are shown)
        let left = globalPos.x
        let top = globalPos.y
        let right = globalPos.x + frame.width - 1
        let bottom = globalPos.y + frame.height - 1
        
        // Corners
        tui.drawChar(row: top, column: left, character: "╔", attributes: [], foregroundColor: borderFg, backgroundColor: frameBg)
        tui.drawChar(row: top, column: right, character: "╗", attributes: [], foregroundColor: borderFg, backgroundColor: frameBg)
        tui.drawChar(row: bottom, column: left, character: "╚", attributes: [], foregroundColor: borderFg, backgroundColor: frameBg)
        tui.drawChar(row: bottom, column: right, character: "╝", attributes: [], foregroundColor: borderFg, backgroundColor: frameBg)
        
        // Top border (always)
        if frame.width > 2 {
            tui.drawLine(
                fromRow: top,
                fromColumn: left + 1,
                toRow: top,
                toColumn: right - 1,
                character: "═",
                attributes: [],
                foregroundColor: borderFg,
                backgroundColor: frameBg
            )
        }
        
        // Bottom border (full if no scrollbar, otherwise only left segment)
        if frame.width > 2 {
            if !showsHorizontalScrollBar {
                tui.drawLine(
                    fromRow: bottom,
                    fromColumn: left + 1,
                    toRow: bottom,
                    toColumn: right - 1,
                    character: "═",
                    attributes: [],
                    foregroundColor: borderFg,
                    backgroundColor: frameBg
                )
            } else {
                let innerWidth = max(0, frame.width - 2)
                let barWidth = horizontalScrollBarWidth(innerWidth: innerWidth)
                let endX = left + max(1, innerWidth - barWidth)
                if endX > left {
                    tui.drawLine(
                        fromRow: bottom,
                        fromColumn: left + 1,
                        toRow: bottom,
                        toColumn: endX,
                        character: "═",
                        attributes: [],
                        foregroundColor: borderFg,
                        backgroundColor: frameBg
                    )
                }
            }
        }
        
        // Left border (always)
        if frame.height > 2 {
            tui.drawLine(
                fromRow: top + 1,
                fromColumn: left,
                toRow: bottom - 1,
                toColumn: left,
                character: "║",
                attributes: [],
                foregroundColor: borderFg,
                backgroundColor: frameBg
            )
        }
        
        // Right border (only if no vertical scrollbar)
        if !showsVerticalScrollBar, frame.height > 2 {
            tui.drawLine(
                fromRow: top + 1,
                fromColumn: right,
                toRow: bottom - 1,
                toColumn: right,
                character: "║",
                attributes: [],
                foregroundColor: borderFg,
                backgroundColor: frameBg
            )
        }
        
        // 4. Draw Title
        let titleLen = title.count
        // Center title
        let titleX = globalPos.x + (frame.width - titleLen) / 2
        if titleX > globalPos.x && titleX + titleLen < globalPos.x + frame.width {
            tui.drawString(
                row: globalPos.y,
                column: titleX,
                text: " \(title) ",
                attributes: [],
                foregroundColor: titleFg,
                backgroundColor: frameBg
            )
        }
        
        // 5. Draw Close Button [■]
        // Typically at top-left: [ ] or [■]
        if frame.width > 5 {
            tui.drawString(
                row: globalPos.y,
                column: globalPos.x + 2,
                text: "[■]",
                attributes: [],
                foregroundColor: isDragging ? titleFg : .green,
                backgroundColor: frameBg
            )
        }
        
        // 6. Fill Content Area
        let content = contentFrame
        if content.width > 0 && content.height > 0 {
            tui.fillRect(
                row: globalPos.y + content.y,
                column: globalPos.x + content.x,
                width: content.width,
                height: content.height,
                character: " ",
                attributes: [],
                foregroundColor: contentFg,
                backgroundColor: contentBg
            )
        }
        
        // 7. Custom content drawing (inside the content area)
        if content.width > 0 && content.height > 0 {
            let contentGlobal = Rect(
                x: globalPos.x + content.x,
                y: globalPos.y + content.y,
                width: content.width,
                height: content.height
            )
            onDrawContent?(contentGlobal)
        }
        
        // 8. Layout scrollbars before drawing subviews
        layoutScrollBars()
        
        // 9. Draw subviews
        for view in subviews {
            view.draw()
        }
    }
    
    private func updateScrollBars() {
        if showsVerticalScrollBar {
            if verticalScrollBar == nil {
                let bar = TScrollBar(frame: Rect(x: 0, y: 0, width: 1, height: 1), orientation: .vertical)
                bar.palette = .listView
                bar.glyphs = .listView
                verticalScrollBar = bar
                addSubview(bar)
            }
            verticalScrollBar?.isVisible = true
        } else {
            verticalScrollBar?.isVisible = false
        }
        
        if showsHorizontalScrollBar {
            if horizontalScrollBar == nil {
                let bar = TScrollBar(frame: Rect(x: 0, y: 0, width: 1, height: 1), orientation: .horizontal)
                bar.palette = .listView
                bar.glyphs = .listView
                horizontalScrollBar = bar
                addSubview(bar)
            }
            horizontalScrollBar?.isVisible = true
        } else {
            horizontalScrollBar?.isVisible = false
        }
    }
    
    private func layoutScrollBars() {
        let innerWidth = max(0, frame.width - 2)
        let innerHeight = max(0, frame.height - 2)
        
        if let vertical = verticalScrollBar, showsVerticalScrollBar {
            vertical.frame = Rect(
                x: frame.width - 1,
                y: 1,
                width: 1,
                height: innerHeight
            )
        }
        
        if let horizontal = horizontalScrollBar, showsHorizontalScrollBar {
            let barWidth = horizontalScrollBarWidth(innerWidth: innerWidth)
            horizontal.frame = Rect(
                x: 1 + max(0, innerWidth - barWidth),
                y: frame.height - 1,
                width: barWidth,
                height: 1
            )
        }
    }
    
    private func horizontalScrollBarWidth(innerWidth: Int) -> Int {
        max(1, innerWidth / 2)
    }
}

// Extension to SwiftyTermUI to support drawBox if not present
extension SwiftyTermUI {
    public func drawBox(row: Int, column: Int, width: Int, height: Int, character: Character, attributes: TextAttributes, foregroundColor: Color, backgroundColor: Color) {
        // Top
        drawLine(fromRow: row, fromColumn: column, toRow: row, toColumn: column + width - 1, character: "═", attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        // Bottom
        drawLine(fromRow: row + height - 1, fromColumn: column, toRow: row + height - 1, toColumn: column + width - 1, character: "═", attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        // Left
        drawLine(fromRow: row, fromColumn: column, toRow: row + height - 1, toColumn: column, character: "║", attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        // Right
        drawLine(fromRow: row, fromColumn: column + width - 1, toRow: row + height - 1, toColumn: column + width - 1, character: "║", attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        
        // Corners
        drawChar(row: row, column: column, character: "╔", attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        drawChar(row: row, column: column + width - 1, character: "╗", attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        drawChar(row: row + height - 1, column: column, character: "╚", attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        drawChar(row: row + height - 1, column: column + width - 1, character: "╝", attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }
}
