import Foundation

/// Утиліти для рисування
public struct DrawingUtils {
    
    /// Малює лінію від (fromRow, fromColumn) до (toRow, toColumn)
    public static func drawLine(
        buffer: ScreenBuffer,
        fromRow: Int,
        fromColumn: Int,
        toRow: Int,
        toColumn: Int,
        character: Character = "─",
        attributes: TextAttributes = [],
        foregroundColor: Color = .default,
        backgroundColor: Color = .default
    ) {
        let dx = abs(toColumn - fromColumn)
        let dy = abs(toRow - fromRow)
        let sx = fromColumn < toColumn ? 1 : -1
        let sy = fromRow < toRow ? 1 : -1
        var err = dx - dy
        
        var x = fromColumn
        var y = fromRow
        
        while true {
            buffer.setCell(
                row: y,
                column: x,
                character: character,
                attributes: attributes,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
            
            if x == toColumn && y == toRow { break }
            
            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                x += sx
            }
            if e2 < dx {
                err += dx
                y += sy
            }
        }
    }
    
    /// Малює прямокутник (тільки контур)
    public static func drawRect(
        buffer: ScreenBuffer,
        row: Int,
        column: Int,
        width: Int,
        height: Int,
        character: Character = "█",
        attributes: TextAttributes = [],
        foregroundColor: Color = .default,
        backgroundColor: Color = .default
    ) {
        // Верхня та нижня лінії
        for x in column..<(column + width) {
            buffer.setCell(row: row, column: x, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
            buffer.setCell(row: row + height - 1, column: x, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        }
        
        // Ліва та права лінії
        for y in row..<(row + height) {
            buffer.setCell(row: y, column: column, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
            buffer.setCell(row: y, column: column + width - 1, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        }
    }
    
    /// Малює заповнений прямокутник
    public static func fillRect(
        buffer: ScreenBuffer,
        row: Int,
        column: Int,
        width: Int,
        height: Int,
        character: Character = " ",
        attributes: TextAttributes = [],
        foregroundColor: Color = .default,
        backgroundColor: Color = .default
    ) {
        for y in row..<(row + height) {
            for x in column..<(column + width) {
                buffer.setCell(
                    row: y,
                    column: x,
                    character: character,
                    attributes: attributes,
                    foregroundColor: foregroundColor,
                    backgroundColor: backgroundColor
                )
            }
        }
    }
    
    /// Центрує текст в межах заданої ширини
    public static func centerText(_ text: String, width: Int) -> (text: String, startColumn: Int) {
        let textLength = text.count
        
        if textLength >= width {
            return (String(text.prefix(width)), 0)
        }
        
        let padding = (width - textLength) / 2
        return (text, padding)
    }
    
    /// Вирівнює текст вправо
    public static func alignRight(_ text: String, width: Int) -> (text: String, startColumn: Int) {
        let textLength = text.count
        
        if textLength >= width {
            return (String(text.prefix(width)), 0)
        }
        
        let padding = width - textLength
        return (text, padding)
    }
}
