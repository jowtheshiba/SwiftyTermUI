import SwiftyTermUI

public class TProgressBar: TView {

    // MARK: - Palette

    public struct Palette: Sendable {
        public var borderFg: Color
        public var borderBg: Color
        public var filledFg: Color
        public var filledBg: Color
        public var emptyBg: Color
        public var percentFg: Color
        public var percentBg: Color

        public static let retroDefault = Palette(
            borderFg: .cyan,
            borderBg: .blue,
            filledFg: .brightCyan,
            filledBg: .blue,
            emptyBg: .blue,
            percentFg: .brightWhite,
            percentBg: .blue
        )

        public static let dialog = Palette(
            borderFg: .brightWhite,
            borderBg: .white,
            filledFg: .blue,
            filledBg: .white,
            emptyBg: .white,
            percentFg: .black,
            percentBg: .white
        )
    }

    // MARK: - Properties

    public var value: Int = 0 {
        didSet {
            let clamped = max(0, min(value, maxValue))
            if clamped != value { value = clamped }
        }
    }

    public var maxValue: Int = 100 {
        didSet {
            if maxValue < 0 { maxValue = 0 }
            if value > maxValue { value = maxValue }
        }
    }

    /// Convenience accessor: progress as a fraction 0.0 … 1.0
    public var progress: Double {
        get {
            guard maxValue > 0 else { return 0 }
            return Double(value) / Double(maxValue)
        }
        set {
            let clamped = max(0.0, min(1.0, newValue))
            value = Int(clamped * Double(maxValue))
        }
    }

    public var showPercentage: Bool = true
    public var palette: Palette = .retroDefault

    // MARK: - Init

    public init(frame: Rect, value: Int = 0, maxValue: Int = 100) {
        self.maxValue = max(0, maxValue)
        self.value = max(0, min(value, maxValue))
        super.init(frame: frame)
    }

    // MARK: - Drawing

    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 0, frame.height > 0 else { return }

        if frame.height >= 3 {
            drawBordered()
        } else {
            drawCompact()
        }
    }

    // MARK: - Bordered style (height >= 3)
    //
    //  ┌──────────────────── 42% ─┐
    //  │████████████████           │
    //  └──────────────────────────-┘

    @MainActor
    private func drawBordered() {
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let w = frame.width
        let h = frame.height
        let lastCol = w - 1
        let lastRow = h - 1

        // Clear background
        tui.fillRect(
            row: origin.y, column: origin.x,
            width: w, height: h,
            character: " ", attributes: [],
            foregroundColor: palette.borderFg, backgroundColor: palette.borderBg
        )

        // ── Top border ──────────────────────────────────────────
        tui.drawChar(
            row: origin.y, column: origin.x,
            character: "┌", attributes: [],
            foregroundColor: palette.borderFg, backgroundColor: palette.borderBg
        )
        tui.drawChar(
            row: origin.y, column: origin.x + lastCol,
            character: "┐", attributes: [],
            foregroundColor: palette.borderFg, backgroundColor: palette.borderBg
        )
        if w > 2 {
            for col in 1 ..< lastCol {
                tui.drawChar(
                    row: origin.y, column: origin.x + col,
                    character: "─", attributes: [],
                    foregroundColor: palette.borderFg, backgroundColor: palette.borderBg
                )
            }
        }

        // Percentage embedded right-aligned in the top border: ── 42% ─┐
        if showPercentage, w > 6 {
            let pct = maxValue > 0
                ? Int(Double(value) / Double(maxValue) * 100.0)
                : 0
            let text = " \(pct)% "
            let textStart = origin.x + lastCol - text.count - 1
            for (i, ch) in text.enumerated() {
                tui.drawChar(
                    row: origin.y, column: textStart + i,
                    character: ch, attributes: [],
                    foregroundColor: palette.percentFg, backgroundColor: palette.percentBg
                )
            }
        }

        // ── Bottom border ───────────────────────────────────────
        tui.drawChar(
            row: origin.y + lastRow, column: origin.x,
            character: "└", attributes: [],
            foregroundColor: palette.borderFg, backgroundColor: palette.borderBg
        )
        tui.drawChar(
            row: origin.y + lastRow, column: origin.x + lastCol,
            character: "┘", attributes: [],
            foregroundColor: palette.borderFg, backgroundColor: palette.borderBg
        )
        if w > 2 {
            for col in 1 ..< lastCol {
                tui.drawChar(
                    row: origin.y + lastRow, column: origin.x + col,
                    character: "─", attributes: [],
                    foregroundColor: palette.borderFg, backgroundColor: palette.borderBg
                )
            }
        }

        // ── Left & right borders ────────────────────────────────
        for row in 1 ..< lastRow {
            tui.drawChar(
                row: origin.y + row, column: origin.x,
                character: "│", attributes: [],
                foregroundColor: palette.borderFg, backgroundColor: palette.borderBg
            )
            tui.drawChar(
                row: origin.y + row, column: origin.x + lastCol,
                character: "│", attributes: [],
                foregroundColor: palette.borderFg, backgroundColor: palette.borderBg
            )
        }

        // ── Bar content inside the border ───────────────────────
        let innerWidth = max(0, w - 2)
        let filledWidth: Int
        if maxValue > 0 && innerWidth > 0 {
            filledWidth = min(innerWidth, Int(Double(value) / Double(maxValue) * Double(innerWidth)))
        } else {
            filledWidth = 0
        }
        let emptyWidth = innerWidth - filledWidth

        for row in 1 ..< lastRow {
            if filledWidth > 0 {
                tui.fillRect(
                    row: origin.y + row, column: origin.x + 1,
                    width: filledWidth, height: 1,
                    character: "█", attributes: [],
                    foregroundColor: palette.filledFg, backgroundColor: palette.filledBg
                )
            }
            if emptyWidth > 0 {
                tui.fillRect(
                    row: origin.y + row, column: origin.x + 1 + filledWidth,
                    width: emptyWidth, height: 1,
                    character: " ", attributes: [],
                    foregroundColor: palette.borderFg, backgroundColor: palette.emptyBg
                )
            }
        }
    }

    // MARK: - Compact style (height 1–2, no border)
    //
    //  ████████████████ 42% ░░░░░░

    @MainActor
    private func drawCompact() {
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        let barWidth = frame.width

        let filledWidth: Int
        if maxValue > 0 {
            filledWidth = min(barWidth, Int(Double(value) / Double(maxValue) * Double(barWidth)))
        } else {
            filledWidth = 0
        }
        let emptyWidth = barWidth - filledWidth

        for row in origin.y ..< (origin.y + frame.height) {
            if filledWidth > 0 {
                tui.fillRect(
                    row: row, column: origin.x,
                    width: filledWidth, height: 1,
                    character: "█", attributes: [],
                    foregroundColor: palette.filledFg, backgroundColor: palette.filledBg
                )
            }
            if emptyWidth > 0 {
                tui.fillRect(
                    row: row, column: origin.x + filledWidth,
                    width: emptyWidth, height: 1,
                    character: " ", attributes: [],
                    foregroundColor: palette.borderFg, backgroundColor: palette.emptyBg
                )
            }
        }

        // Percentage overlay (centered)
        if showPercentage, barWidth >= 4 {
            let pct = maxValue > 0
                ? Int(Double(value) / Double(maxValue) * 100.0)
                : 0
            let text = "\(pct)%"
            let textX = origin.x + (barWidth - text.count) / 2
            let midRow = origin.y + (frame.height - 1) / 2

            for (i, ch) in text.enumerated() {
                let col = textX + i
                let inFilled = (col - origin.x) < filledWidth
                tui.drawChar(
                    row: midRow, column: col,
                    character: ch, attributes: [],
                    foregroundColor: palette.percentFg,
                    backgroundColor: inFilled ? palette.filledBg : palette.emptyBg
                )
            }
        }
    }
}
