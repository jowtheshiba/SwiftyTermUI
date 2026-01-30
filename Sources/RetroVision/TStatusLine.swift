import SwiftyTermUI

public struct TStatusItem {
    public let key: Key
    public let keyText: String
    public let title: String
    public let action: (() -> Void)?
    
    public init(key: Key, keyText: String, title: String, action: (() -> Void)? = nil) {
        self.key = key
        self.keyText = keyText
        self.title = title
        self.action = action
    }
}

public class TStatusLine: TView {
    public var items: [TStatusItem]
    
    public init(frame: Rect, items: [TStatusItem]) {
        self.items = items
        super.init(frame: frame)
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        guard frame.width > 0, frame.height > 0 else { return }
        
        let tui = SwiftyTermUI.shared
        let origin = localToGlobal(Point(x: 0, y: 0))
        
        let fg: Color = .white
        let bg: Color = .blue
        
        tui.fillRect(
            row: origin.y,
            column: origin.x,
            width: frame.width,
            height: frame.height,
            character: " ",
            attributes: [],
            foregroundColor: fg,
            backgroundColor: bg
        )
        
        var currentX = origin.x + 1
        let row = origin.y
        
        for item in items {
            let keyText = item.keyText
            let titleText = item.title
            if currentX + keyText.count + 1 >= origin.x + frame.width {
                break
            }
            
            tui.drawString(
                row: row,
                column: currentX,
                text: keyText,
                attributes: [.bold],
                foregroundColor: .brightWhite,
                backgroundColor: bg
            )
            currentX += keyText.count
            
            if currentX < origin.x + frame.width {
                tui.drawString(
                    row: row,
                    column: currentX,
                    text: " " + titleText + " ",
                    attributes: [],
                    foregroundColor: fg,
                    backgroundColor: bg
                )
                currentX += titleText.count + 2
            } else {
                break
            }
        }
    }
    
    @MainActor
    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event {
            for item in items where item.key == key {
                item.action?()
                return
            }
        }
        super.handleEvent(event)
    }
}
