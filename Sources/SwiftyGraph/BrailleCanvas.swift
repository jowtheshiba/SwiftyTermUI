import SwiftyTermUI

/// A drawing surface that packs a 2x4 grid of dots into every terminal cell
/// using Unicode Braille patterns (U+2800...U+28FF). This gives line plots
/// roughly four times the vertical and twice the horizontal resolution of
/// plain character-cell drawing, which is what makes curves look smooth.
struct BrailleCanvas {
    let cellWidth: Int
    let cellHeight: Int
    let pixelWidth: Int
    let pixelHeight: Int

    private var dots: [UInt8]
    private var colors: [Color?]

    private static let dotBit: [[UInt8]] = [
        [0x01, 0x08],
        [0x02, 0x10],
        [0x04, 0x20],
        [0x40, 0x80],
    ]

    init(cellWidth: Int, cellHeight: Int) {
        self.cellWidth = max(cellWidth, 1)
        self.cellHeight = max(cellHeight, 1)
        pixelWidth = self.cellWidth * 2
        pixelHeight = self.cellHeight * 4
        dots = Array(repeating: 0, count: self.cellWidth * self.cellHeight)
        colors = Array(repeating: nil, count: self.cellWidth * self.cellHeight)
    }

    mutating func setPixel(x: Int, y: Int, color: Color) {
        guard x >= 0, x < pixelWidth, y >= 0, y < pixelHeight else { return }
        let cellX = x / 2
        let cellY = y / 4
        let index = cellY * cellWidth + cellX
        dots[index] |= Self.dotBit[y % 4][x % 2]
        colors[index] = color
    }

    mutating func drawLine(fromX: Int, fromY: Int, toX: Int, toY: Int, color: Color) {
        var x0 = fromX
        var y0 = fromY
        let dx = abs(toX - x0)
        let sx = x0 < toX ? 1 : -1
        let dy = -abs(toY - y0)
        let sy = y0 < toY ? 1 : -1
        var err = dx + dy

        while true {
            setPixel(x: x0, y: y0, color: color)
            if x0 == toX, y0 == toY { break }
            let e2 = 2 * err
            if e2 >= dy {
                err += dy
                x0 += sx
            }
            if e2 <= dx {
                err += dx
                y0 += sy
            }
        }
    }

    @MainActor
    func render(in tui: SwiftyTermUI, row: Int, column: Int) {
        for cellY in 0..<cellHeight {
            for cellX in 0..<cellWidth {
                let index = cellY * cellWidth + cellX
                let mask = dots[index]
                guard mask != 0, let color = colors[index] else { continue }
                let scalar = UnicodeScalar(0x2800 + Int(mask))!
                tui.addChar(row: row + cellY, column: column + cellX, character: Character(scalar), foregroundColor: color)
            }
        }
    }
}
