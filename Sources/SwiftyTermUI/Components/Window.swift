import Foundation

/// Вікно з незалежним буфером та координатами
public final class Window {
    public let id: UUID
    public private(set) var x: Int
    public private(set) var y: Int
    public private(set) var width: Int
    public private(set) var height: Int
    
    private var buffer: [[Cell]]
    private let lock = NSLock()
    
    public var hasBorder: Bool
    public var borderStyle: BorderStyle
    public var title: String?
    public var hasFocus: Bool = false
    public var isVisible: Bool = true
    
    public enum BorderStyle {
        case single
        case double
        case rounded
        case custom(top: Character, bottom: Character, left: Character, right: Character, 
                   topLeft: Character, topRight: Character, bottomLeft: Character, bottomRight: Character)
        
        var chars: (top: Character, bottom: Character, left: Character, right: Character,
                   topLeft: Character, topRight: Character, bottomLeft: Character, bottomRight: Character) {
            switch self {
            case .single:
                return ("─", "─", "│", "│", "┌", "┐", "└", "┘")
            case .double:
                return ("═", "═", "║", "║", "╔", "╗", "╚", "╝")
            case .rounded:
                return ("─", "─", "│", "│", "╭", "╮", "╰", "╯")
            case let .custom(t, b, l, r, tl, tr, bl, br):
                return (t, b, l, r, tl, tr, bl, br)
            }
        }
    }
    
    public init(x: Int, y: Int, width: Int, height: Int, hasBorder: Bool = false, borderStyle: BorderStyle = .single) {
        self.id = UUID()
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.hasBorder = hasBorder
        self.borderStyle = borderStyle
        self.buffer = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
    }
    
    public func move(to x: Int, y: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        self.x = x
        self.y = y
    }
    
    public func resize(width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        self.width = width
        self.height = height
        buffer = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
    }
    
    public func addChar(row: Int, column: Int, character: Character, attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }
        
        guard isValidPosition(row: row, column: column) else { return }
        
        buffer[row][column] = Cell(
            character: character,
            attributes: attributes,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }
    
    public func addString(row: Int, column: Int, text: String, attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }
        
        var col = column
        for char in text {
            guard isValidPosition(row: row, column: col) else { break }
            
            buffer[row][col] = Cell(
                character: char,
                attributes: attributes,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
            col += 1
        }
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        buffer = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
    }
    
    public func clearArea(row: Int, column: Int, width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        for y in row..<min(row + height, self.height) {
            for x in column..<min(column + width, self.width) {
                buffer[y][x] = Cell.empty()
            }
        }
    }
    
    internal func getBuffer() -> [[Cell]] {
        lock.lock()
        defer { lock.unlock() }
        
        return buffer
    }
    
    internal func toGlobalCoordinates(row: Int, column: Int) -> (row: Int, column: Int) {
        (y + row, x + column)
    }
    
    private func isValidPosition(row: Int, column: Int) -> Bool {
        row >= 0 && row < height && column >= 0 && column < width
    }
    
    internal func getContentBounds() -> (x: Int, y: Int, width: Int, height: Int) {
        if hasBorder {
            return (x: 1, y: 1, width: max(0, width - 2), height: max(0, height - 2))
        }
        return (x: 0, y: 0, width: width, height: height)
    }
}
