import Foundation

/// Progress indicator
public final class ProgressBar {
    public var x: Int
    public var y: Int
    public var width: Int
    
    public var value: Double = 0.0 // 0.0 - 1.0
    public var label: String?
    public var showPercentage: Bool = true
    
    public var fillChar: Character = "█"
    public var emptyChar: Character = "░"
    
    public var fillColor: Color = .green
    public var emptyColor: Color = .brightBlack
    public var textColor: Color = .white
    
    public var style: Style = .standard
    
    public enum Style {
        case standard
        case blocks
        case dots
    }
    
    public init(x: Int, y: Int, width: Int) {
        self.x = x
        self.y = y
        self.width = width
    }
    
    /// Sets progress (0.0 - 1.0)
    public func setProgress(_ value: Double) {
        self.value = max(0.0, min(1.0, value))
    }
    
    /// Sets progress in percentage (0 - 100)
    public func setPercentage(_ percentage: Int) {
        setProgress(Double(percentage) / 100.0)
    }
    
    private func getStyleChars() -> (fill: Character, empty: Character) {
        switch style {
        case .standard:
            return ("█", "░")
        case .blocks:
            return ("▓", "░")
        case .dots:
            return ("●", "○")
        }
    }
    
    /// Renders progress bar on screen
    @MainActor public func render(to tui: SwiftyTermUI) {
        var currentY = y
        
        // Label
        if let label = label {
            tui.drawString(row: currentY, column: x, text: label, foregroundColor: textColor)
            currentY += 1
        }
        
        // Progress bar
        let (fillCh, emptyCh) = getStyleChars()
        let filledWidth = Int(Double(width) * value)
        
        // Filled portion
        if filledWidth > 0 {
            tui.fillRect(
                row: currentY,
                column: x,
                width: filledWidth,
                height: 1,
                character: fillCh,
                foregroundColor: fillColor
            )
        }
        
        // Empty portion
        if filledWidth < width {
            tui.fillRect(
                row: currentY,
                column: x + filledWidth,
                width: width - filledWidth,
                height: 1,
                character: emptyCh,
                foregroundColor: emptyColor
            )
        }
        
        // Percentage
        if showPercentage {
            let percentage = Int(value * 100)
            let percentText = "\(percentage)%"
            let textX = x + (width - percentText.count) / 2
            
            tui.drawString(
                row: currentY,
                column: textX,
                text: percentText,
                attributes: [.bold],
                foregroundColor: textColor
            )
        }
    }
}
