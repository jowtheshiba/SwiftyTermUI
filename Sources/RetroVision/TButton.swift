import SwiftyTermUI

public class TButton: TView {
    public var title: String
    public var action: () -> Void
    
    public var isPressed: Bool = false
    private var isMouseDownInside = false
    
    public init(frame: Rect, title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        
        let buttonWidth = max(frame.width, 1)
        let buttonHeight = max(frame.height, 1)
        
        // Colors
        // Normal: Black on Green
        // Focused: White on Green (Bright)
        // Pressed: Black on Cyan
        
        let fg: Color = isPressed ? .black : (isFocused ? .brightWhite : .black)
        let bg: Color = isPressed ? .cyan : .green
        
        // Draw Button Body
        // Format: [ Title ]
        // We center the title
        let rawText = "[ \(title) ]"
        let displayText: String
        if rawText.count > buttonWidth {
            displayText = String(rawText.prefix(buttonWidth))
        } else {
            displayText = rawText
        }
        
        // Fill button background to ensure consistent body size
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: buttonWidth,
            height: buttonHeight,
            character: " ",
            attributes: [],
            foregroundColor: fg,
            backgroundColor: bg
        )
        
        // Center the title inside available width/height
        let horizontalPadding = max(0, buttonWidth - displayText.count)
        let textColumn = origin.x + horizontalPadding / 2
        let textRow = origin.y + (buttonHeight - 1) / 2
        
        tui.drawString(
            row: textRow,
            column: textColumn,
            text: displayText,
            attributes: [],
            foregroundColor: fg,
            backgroundColor: bg
        )
        
        
        // Draw Shadow (TurboVision style)
        // Shadow is cast to the right and bottom
        // Only if not pressed (simulates depression)
        if !isPressed {
            let shadowForeground: Color = .black
            let shadowMidtone: Color = .brightBlack
            let shadowBackground = resolvedShadowBackgroundColor()
            
            // Right shadow column
            let rightColumnX = origin.x + buttonWidth
            tui.drawChar(
                row: origin.y,
                column: rightColumnX,
                character: "▄",
                attributes: [],
                foregroundColor: shadowForeground,
                backgroundColor: shadowBackground
            )
            
            if buttonHeight > 1 {
                tui.fillRect(
                    row: origin.y + 1,
                    column: rightColumnX,
                    width: 1,
                    height: buttonHeight - 1,
                    character: "█",
                    attributes: [],
                    foregroundColor: shadowForeground,
                    backgroundColor: shadowBackground
                )
            }
            
            // Bottom shadow row (two-cell inset, extends past button edge)
            let bottomRowY = origin.y + buttonHeight
            let leftInset = min(2, buttonWidth)
            if leftInset > 0 {
                tui.fillRect(
                    row: bottomRowY,
                    column: origin.x,
                    width: leftInset,
                    height: 1,
                    character: " ",
                    attributes: [],
                    foregroundColor: shadowForeground,
                    backgroundColor: shadowBackground
                )
            }
            
            let bottomStartX = origin.x + leftInset
            let bottomWidth = max(buttonWidth + 1 - leftInset, 0)
            if bottomWidth > 0 {
                for offset in 0..<bottomWidth {
                    tui.drawChar(
                        row: bottomRowY,
                        column: bottomStartX + offset,
                        character: "▀",
                        attributes: [],
                        foregroundColor: shadowForeground,
                        backgroundColor: shadowBackground
                    )
                }
            }
        }
    }
    public override func handleEvent(_ event: TEvent) {
        switch event {
        case .key(let key):
            if isFocused {
                if key == .enter || key == .character(" ") {
                    isPressed = true
                    action()
                    isPressed = false
                }
            }
            
        default:
            break
        }
        
        super.handleEvent(event)
    }
    
    public override func mouseEvent(_ event: TEvent.MouseEvent) {
        switch event.action {
        case .down where event.button == .left:
            isPressed = true
            isMouseDownInside = true
            
        case .drag where event.button == .left:
            if isMouseDownInside {
                isPressed = bounds.contains(event.position)
            }
            
        case .up where event.button == .left:
            let shouldTrigger = isMouseDownInside && bounds.contains(event.position)
            isMouseDownInside = false
            isPressed = false
            if shouldTrigger {
                action()
            }
            
        default:
            break
        }
    }
    
    private func resolvedShadowBackgroundColor() -> Color {
        var current: TView? = self
        while let view = current {
            if let window = view as? TWindow {
                switch window.style {
                case .window:
                    return .blue
                case .dialog:
                    return .white
                }
            }
            current = view.superview
        }
        return .white
    }
}
