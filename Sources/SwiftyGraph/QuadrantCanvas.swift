import SwiftyTermUI

/// A single-color fill surface that packs a 2x2 grid of sub-cells into every
/// terminal cell using Unicode quadrant block characters. Used to soften
/// diagonal edges of filled shapes (like a sheared parallelogram) that would
/// otherwise show a hard one-cell staircase.
struct QuadrantCanvas {
    let cellWidth: Int
    let cellHeight: Int
    let pixelWidth: Int
    let pixelHeight: Int

    private var pixels: [Bool]

    init(cellWidth: Int, cellHeight: Int) {
        self.cellWidth = max(cellWidth, 1)
        self.cellHeight = max(cellHeight, 1)
        pixelWidth = self.cellWidth * 2
        pixelHeight = self.cellHeight * 2
        pixels = Array(repeating: false, count: pixelWidth * pixelHeight)
    }

    mutating func setPixel(x: Int, y: Int) {
        guard x >= 0, x < pixelWidth, y >= 0, y < pixelHeight else { return }
        pixels[y * pixelWidth + x] = true
    }

    func isSet(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, x < pixelWidth, y >= 0, y < pixelHeight else { return false }
        return pixels[y * pixelWidth + x]
    }

    @MainActor
    func render(in tui: SwiftyTermUI, row: Int, column: Int, color: Color) {
        for cellY in 0..<cellHeight {
            for cellX in 0..<cellWidth {
                let ul = isSet(cellX * 2, cellY * 2)
                let ur = isSet(cellX * 2 + 1, cellY * 2)
                let ll = isSet(cellX * 2, cellY * 2 + 1)
                let lr = isSet(cellX * 2 + 1, cellY * 2 + 1)
                guard let char = Self.quadrantChar(ul, ur, ll, lr) else { continue }
                tui.addChar(row: row + cellY, column: column + cellX, character: char, foregroundColor: color)
            }
        }
    }

    static func quadrantChar(_ ul: Bool, _ ur: Bool, _ ll: Bool, _ lr: Bool) -> Character? {
        switch (ul, ur, ll, lr) {
        case (false, false, false, false): return nil
        case (true, false, false, false): return "▘"
        case (false, true, false, false): return "▝"
        case (false, false, true, false): return "▖"
        case (false, false, false, true): return "▗"
        case (true, true, false, false): return "▀"
        case (false, false, true, true): return "▄"
        case (true, false, true, false): return "▌"
        case (false, true, false, true): return "▐"
        case (true, false, false, true): return "▚"
        case (false, true, true, false): return "▞"
        case (true, true, true, false): return "▛"
        case (true, true, false, true): return "▜"
        case (true, false, true, true): return "▙"
        case (false, true, true, true): return "▟"
        case (true, true, true, true): return "█"
        }
    }
}
