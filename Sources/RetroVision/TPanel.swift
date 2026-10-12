import SwiftyTermUI

public class TPanel: TGroup {
    public enum BorderStyle: Sendable {
        case single
        case double
    }

    public var title: String
    public var footer: String
    public var borderStyle: BorderStyle
    public var isActive: Bool {
        get { state.contains(.active) }
        set { setState(.active, enabled: newValue) }
    }

    public var contentFrame: Rect {
        Rect(
            x: 1,
            y: 1,
            width: max(0, frame.width - 2),
            height: max(0, frame.height - 2)
        )
    }

    public init(
        frame: Rect,
        title: String = "",
        footer: String = "",
        borderStyle: BorderStyle = .single
    ) {
        self.title = title
        self.footer = footer
        self.borderStyle = borderStyle
        super.init(frame: frame)
        options.insert(.framed)
    }

    @MainActor
    public override func draw() {
        guard isVisible, frame.width > 0, frame.height > 0 else { return }

        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let theme = TTheme.current
        let frameColors = isActive ? theme.panelFrameActive : theme.panelFrameInactive
        let contentColors = theme.panelContent

        tui.pushClip(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height
        )

        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: contentColors.fg,
            backgroundColor: contentColors.bg
        )

        drawBorder(at: origin, colors: frameColors)
        drawLabel(title, row: origin.y, origin: origin, colors: frameColors)
        drawLabel(footer, row: origin.y + frame.height - 1, origin: origin, colors: frameColors)

        let content = contentFrame
        if content.width > 0, content.height > 0 {
            tui.pushClip(
                row: origin.y + content.y,
                column: origin.x + content.x,
                width: content.width,
                height: content.height
            )
            for view in subviews {
                view.draw()
            }
            tui.popClip()
        }

        tui.popClip()
    }

    @MainActor
    private func drawBorder(at origin: Point, colors: TColorPair) {
        let tui = SwiftyTermUI.shared
        let glyphs: (topLeft: Character, topRight: Character, bottomLeft: Character, bottomRight: Character, horizontal: Character, vertical: Character)
        switch borderStyle {
        case .single:
            glyphs = ("┌", "┐", "└", "┘", "─", "│")
        case .double:
            glyphs = ("╔", "╗", "╚", "╝", "═", "║")
        }

        let left = origin.x
        let top = origin.y
        let right = origin.x + frame.width - 1
        let bottom = origin.y + frame.height - 1

        if frame.width == 1 {
            tui.drawLine(
                fromRow: top,
                fromColumn: left,
                toRow: bottom,
                toColumn: left,
                character: glyphs.vertical,
                attributes: [],
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
            )
            return
        }

        if frame.width > 2 {
            tui.drawLine(
                fromRow: top,
                fromColumn: left + 1,
                toRow: top,
                toColumn: right - 1,
                character: glyphs.horizontal,
                attributes: [],
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
            )
            tui.drawLine(
                fromRow: bottom,
                fromColumn: left + 1,
                toRow: bottom,
                toColumn: right - 1,
                character: glyphs.horizontal,
                attributes: [],
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
            )
        }

        if frame.height > 2 {
            tui.drawLine(
                fromRow: top + 1,
                fromColumn: left,
                toRow: bottom - 1,
                toColumn: left,
                character: glyphs.vertical,
                attributes: [],
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
            )
            tui.drawLine(
                fromRow: top + 1,
                fromColumn: right,
                toRow: bottom - 1,
                toColumn: right,
                character: glyphs.vertical,
                attributes: [],
                foregroundColor: colors.fg,
                backgroundColor: colors.bg
            )
        }

        tui.drawChar(row: top, column: left, character: glyphs.topLeft, attributes: [], foregroundColor: colors.fg, backgroundColor: colors.bg)
        tui.drawChar(row: top, column: right, character: glyphs.topRight, attributes: [], foregroundColor: colors.fg, backgroundColor: colors.bg)
        tui.drawChar(row: bottom, column: left, character: glyphs.bottomLeft, attributes: [], foregroundColor: colors.fg, backgroundColor: colors.bg)
        tui.drawChar(row: bottom, column: right, character: glyphs.bottomRight, attributes: [], foregroundColor: colors.fg, backgroundColor: colors.bg)
    }

    @MainActor
    private func drawLabel(_ label: String, row: Int, origin: Point, colors: TColorPair) {
        let availableWidth = frame.width - 4
        guard !label.isEmpty, availableWidth > 0 else { return }
        let text = " " + RetroTextUtils.clampText(label, maxWidth: availableWidth) + " "
        let column = origin.x + max(1, (frame.width - text.count) / 2)
        SwiftyTermUI.shared.drawString(
            row: row,
            column: column,
            text: text,
            attributes: [],
            foregroundColor: colors.fg,
            backgroundColor: colors.bg
        )
    }
}
