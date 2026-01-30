import Foundation

public struct Cell: Equatable {
    public var character: Character
    public var attributes: TextAttributes
    public var foregroundColor: Color
    public var backgroundColor: Color

    public static func empty() -> Cell {
        Cell(
            character: " ",
            attributes: TextAttributes(),
            foregroundColor: .default,
            backgroundColor: .default
        )
    }
}

public final class ScreenBuffer {
    private var current: [[Cell]]
    private var previous: [[Cell]]
    private var width: Int
    private var height: Int
    private let lock = NSLock()

    public var columns: Int { width }
    public var rows: Int { height }

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.current = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
        self.previous = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
    }

    func setCell(row: Int, column: Int, character: Character, attributes: TextAttributes = TextAttributes(), foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }

        guard isValidPosition(row: row, column: column) else {
            return
        }

        current[row][column] = Cell(
            character: character,
            attributes: attributes,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }

    func setString(row: Int, column: Int, text: String, attributes: TextAttributes = TextAttributes(), foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }

        var col = column
        for char in text {
            guard isValidPosition(row: row, column: col) else {
                break
            }

            current[row][col] = Cell(
                character: char,
                attributes: attributes,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
            col += 1
        }
    }

    func clearArea(row: Int, column: Int, width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }

        for y in row ..< min(row + height, self.height) {
            for x in column ..< min(column + width, self.width) {
                current[y][x] = Cell.empty()
            }
        }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }

        current = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
    }

    func generateRenderCommands() -> String {
        lock.lock()
        defer { lock.unlock() }

        var commands = ""
        var currentAttributes = TextAttributes()
        var currentForeground = Color.default
        var currentBackground = Color.default

        // Clear screen and move to (0,0)
        commands += "\u{1B}[2J\u{1B}[H"

        for row in 0 ..< height {
            for column in 0 ..< width {
                let cell = current[row][column]

                // Move to position (y, x) = (row, column)
                commands += "\u{1B}[\(row + 1);\(column + 1)H"

                // Update attributes and colors if changed
                if cell.attributes != currentAttributes || cell.foregroundColor != currentForeground || cell.backgroundColor != currentBackground {
                    commands += "\u{1B}[0m" // Reset all attributes
                    currentAttributes = []
                    currentForeground = .default
                    currentBackground = .default

                    // Set new attributes
                    commands += cell.attributes.toAnsiCodes()

                    // Set colors
                    commands += cell.foregroundColor.ansiCode
                    commands += cell.backgroundColor.backgroundAnsiCode

                    currentAttributes = cell.attributes
                    currentForeground = cell.foregroundColor
                    currentBackground = cell.backgroundColor
                }

                // Output the character
                commands += String(cell.character)
            }
        }

        // Reset attributes at the end
        commands += "\u{1B}[0m"

        // Update previous buffer
        previous = current

        return commands
    }

    private func isValidPosition(row: Int, column: Int) -> Bool {
        row >= 0 && row < height && column >= 0 && column < width
    }

    func resize(width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }

        self.width = width
        self.height = height
        current = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
        previous = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
    }

    public func getCell(row: Int, column: Int) -> Cell {
        lock.lock()
        defer { lock.unlock() }

        guard isValidPosition(row: row, column: column) else {
            return Cell.empty()
        }
        return current[row][column]
    }

    func getPreviousCell(row: Int, column: Int) -> Cell {
        lock.lock()
        defer { lock.unlock() }

        guard isValidPosition(row: row, column: column) else {
            return Cell.empty()
        }
        return previous[row][column]
    }
}
