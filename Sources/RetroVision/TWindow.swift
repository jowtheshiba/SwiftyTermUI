import SwiftyTermUI

/// A floating window with a title and border
public class TWindow: TView {
    public enum WindowStyle {
        case window // Blue background (Editor)
        case dialog // Grey background (Dialog)
    }
    
    public var title: String
    public var style: WindowStyle
    
    public init(frame: Rect, title: String, style: WindowStyle = .window) {
        self.title = title
        self.style = style
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        
        let tui = SwiftyTermUI.shared
        let globalPos = localToGlobal(Point(x: 0, y: 0))
        
        // Colors based on style
        let frameFg: Color
        let frameBg: Color
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
        
        // 3. Draw Double Border
        // We use the extension method drawBox but we need to ensure it uses double lines
        // The extension in this file uses "═", "║", etc. which are double lines.
        // We just need to call it with the right colors.
        tui.drawBox(
            row: globalPos.y,
            column: globalPos.x,
            width: frame.width,
            height: frame.height,
            character: " ", // Not used by drawBox implementation below
            attributes: [],
            foregroundColor: frameFg,
            backgroundColor: frameBg
        )
        
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
                foregroundColor: frameFg, // Title usually same as frame or highlighted
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
                foregroundColor: .green,
                backgroundColor: frameBg
            )
        }
        
        // 6. Fill Content Area
        // Content area is usually inside the border (inset by 1)
        tui.fillRect(
            row: globalPos.y + 1,
            column: globalPos.x + 1,
            width: frame.width - 2,
            height: frame.height - 2,
            character: " ",
            attributes: [],
            foregroundColor: contentFg,
            backgroundColor: contentBg
        )
        
        // 7. Draw subviews
        for view in subviews {
            view.draw()
        }
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
