import SwiftyTermUI

@MainActor
public final class TAlertDialog: TDialog {
    public enum AlertType {
        case information
        case warning
        case error
        
        var title: String {
            switch self {
            case .information: return "Information"
            case .warning: return "Warning"
            case .error: return "Error"
            }
        }
        
        var icon: Character {
            switch self {
            case .information: return "i"
            case .warning: return "!"
            case .error: return "✕"
            }
        }
    }
    
    private let alertType: AlertType
    private let message: String
    
    public init(frame: Rect, type: AlertType, message: String) {
        self.alertType = type
        self.message = message
        super.init(frame: frame, title: type.title)
        allowResizing = false
    }
    
    @MainActor
    public override func draw() {
        let tui = SwiftyTermUI.shared
        
        // Draw icon and message in content area
        let globalPos = localToGlobal(Point(x: 0, y: 0))
        
        // Icon at row 2, column offset by 2
        tui.drawChar(
            row: globalPos.y + 2,
            column: globalPos.x + 2,
            character: alertType.icon,
            attributes: [.bold],
            foregroundColor: style == .dialog ? .brightWhite : .white,
            backgroundColor: style == .dialog ? .white : .blue
        )
        
        // Message text starting after icon (column offset by 5)
        drawMessageText(atX: globalPos.x + 5, row: globalPos.y + 2)
    }
    
    @MainActor
    private func drawMessageText(atX startX: Int, row startY: Int) {
        let tui = SwiftyTermUI.shared
        
        var remainingText = message
        var currentRow = startY
        let maxWidth = Int(frame.width) - 7 // Leave space for icon and margin
        
        while !remainingText.isEmpty && currentRow < startY + 5 {
            let (line, remainder) = splitLine(remainingText, at: maxWidth)
            
            tui.drawString(
                row: currentRow,
                column: startX,
                text: line,
                attributes: [],
                foregroundColor: style == .dialog ? .black : .white,
                backgroundColor: style == .dialog ? .white : .blue
            )
            
            remainingText = remainder
            currentRow += 1
        }
    }
    
    private func splitLine(_ text: String, at maxWidth: Int) -> (line: String, remainder: String) {
        let lineEndIndex = text.index(text.startIndex, offsetBy: min(maxWidth, text.count))
        let line = String(text[..<lineEndIndex])
        
        if lineEndIndex < text.endIndex && !text.isEmpty {
            var nextSpace = text[lineEndIndex...]
            
            if let spaceIndex = firstNonWhitespace(nextSpace) {
                let cutIndex = text.index(lineEndIndex, offsetBy: spaceIndex)
                return (line + " ", String(text[cutIndex...]))
            } else {
                return (line, String(text[lineEndIndex...]))
            }
        }
        
        return (line, "")
    }
    
    private func firstNonWhitespace(_ text: String.SubSequence) -> Int? {
        var index = 0
        for char in text {
            if !char.isWhitespace {
                return nil
            }
            index += 1
        }
        return index > 0 ? index : nil
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        switch event {
        case .key(.escape):
            removeFromSuperview()
        default:
            super.handleEvent(event)
        }
    }
}
