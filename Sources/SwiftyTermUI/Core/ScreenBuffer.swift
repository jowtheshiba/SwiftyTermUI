import Foundation

/// Представляє один символ на екрані з його атрибутами
struct Cell: Equatable {
    var character: Character
    var attributes: TextAttributes
    var foregroundColor: Color
    var backgroundColor: Color

    static func empty() -> Cell {
        Cell(
            character: " ",
            attributes: TextAttributes(),
            foregroundColor: .default,
            backgroundColor: .default
        )
    }
}

/// Буфер екрану з підтримкою оптимізованого рендеру
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

    /// Встановлює символ на позицію (y, x) з атрибутами
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

    /// Встановлює рядок тексту на позицію (y, x) з атрибутами
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

    /// Очищує область
    func clearArea(row: Int, column: Int, width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }

        for y in row ..< min(row + height, self.height) {
            for x in column ..< min(column + width, self.width) {
                current[y][x] = Cell.empty()
            }
        }
    }

    /// Очищує весь буфер
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        current = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
    }

    /// Генерує ANSI команди тільки для змінених ділянок
    func generateRenderCommands() -> String {
        lock.lock()
        defer { lock.unlock() }

        var commands = ""
        var currentAttributes = TextAttributes()
        var currentForeground = Color.default
        var currentBackground = Color.default

        // Очистити екран та перейти в (0,0)
        commands += "\u{1B}[2J\u{1B}[H"

        for row in 0 ..< height {
            for column in 0 ..< width {
                let cell = current[row][column]

                // Переміщуємось на позицію (y, x) = (row, column)
                commands += "\u{1B}[\(row + 1);\(column + 1)H"

                // Оновлюємо атрибути та кольори якщо змінилися
                if cell.attributes != currentAttributes || cell.foregroundColor != currentForeground || cell.backgroundColor != currentBackground {
                    commands += "\u{1B}[0m" // Reset всіх атрибутів
                    currentAttributes = []
                    currentForeground = .default
                    currentBackground = .default

                    // Встановлюємо нові атрибути
                    commands += cell.attributes.toAnsiCodes()

                    // Встановлюємо кольори
                    commands += cell.foregroundColor.ansiCode
                    commands += cell.backgroundColor.backgroundAnsiCode

                    currentAttributes = cell.attributes
                    currentForeground = cell.foregroundColor
                    currentBackground = cell.backgroundColor
                }

                // Виводимо символ
                commands += String(cell.character)
            }
        }

        // Скидаємо атрибути в кінці
        commands += "\u{1B}[0m"

        // Оновлюємо previous buffer
        previous = current

        return commands
    }

    /// Перевіряє, чи позиція в межах буфера
    private func isValidPosition(row: Int, column: Int) -> Bool {
        row >= 0 && row < height && column >= 0 && column < width
    }

    /// Змінює розмір буфера
    func resize(width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }

        self.width = width
        self.height = height
        current = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
        previous = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
    }
}
