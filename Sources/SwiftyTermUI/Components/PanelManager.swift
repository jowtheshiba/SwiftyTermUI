import Foundation

/// Panel manager for managing window stack with z-order
public final class PanelManager {
    private var panels: [Window] = []
    private let lock = NSLock()
    
    public init() {}
    
    public func addPanel(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panels.append(window)
    }
    
    public func removePanel(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panels.removeAll { $0.id == window.id }
    }
    
    public func removePanel(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        panels.removeAll { $0.id == id }
    }
    
    public func bringToFront(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        if let index = panels.firstIndex(where: { $0.id == window.id }) {
            let panel = panels.remove(at: index)
            panels.append(panel)
        }
    }
    
    public func sendToBack(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        if let index = panels.firstIndex(where: { $0.id == window.id }) {
            let panel = panels.remove(at: index)
            panels.insert(panel, at: 0)
        }
    }
    
    public func moveUp(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        if let index = panels.firstIndex(where: { $0.id == window.id }), index < panels.count - 1 {
            panels.swapAt(index, index + 1)
        }
    }
    
    public func moveDown(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        if let index = panels.firstIndex(where: { $0.id == window.id }), index > 0 {
            panels.swapAt(index, index - 1)
        }
    }
    
    public func hide(_ window: Window) {
        window.isVisible = false
    }
    
    public func show(_ window: Window) {
        window.isVisible = true
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        panels.removeAll()
    }
    
    public var allPanels: [Window] {
        lock.lock()
        defer { lock.unlock() }
        
        return panels
    }
    
    public var visiblePanels: [Window] {
        lock.lock()
        defer { lock.unlock() }
        
        return panels.filter { $0.isVisible }
    }
    
    internal func renderToBuffer(_ screenBuffer: ScreenBuffer) {
        lock.lock()
        defer { lock.unlock() }
        
        for window in panels where window.isVisible {
            renderWindow(window, to: screenBuffer)
        }
    }
    
    private func renderWindow(_ window: Window, to screenBuffer: ScreenBuffer) {
        let buffer = window.getBuffer()
        
        if window.hasBorder {
            drawBorder(window, to: screenBuffer)
        }
        
        let bounds = window.getContentBounds()
        
        for row in 0..<bounds.height {
            for col in 0..<bounds.width {
                let localRow = bounds.y + row
                let localCol = bounds.x + col
                
                guard localRow < buffer.count && localCol < buffer[localRow].count else { continue }
                
                let cell = buffer[localRow][localCol]
                let (globalRow, globalCol) = window.toGlobalCoordinates(row: localRow, column: localCol)
                
                screenBuffer.setCell(
                    row: globalRow,
                    column: globalCol,
                    character: cell.character,
                    attributes: cell.attributes,
                    foregroundColor: cell.foregroundColor,
                    backgroundColor: cell.backgroundColor
                )
            }
        }
    }
    
    private func drawBorder(_ window: Window, to screenBuffer: ScreenBuffer) {
        let chars = window.borderStyle.chars
        let attrs: TextAttributes = window.hasFocus ? [.bold] : []
        let color: Color = window.hasFocus ? .brightWhite : .default
        
        for col in 0..<window.width {
            if col == 0 {
                screenBuffer.setCell(row: window.y, column: window.x + col, character: chars.topLeft, attributes: attrs, foregroundColor: color, backgroundColor: .default)
                screenBuffer.setCell(row: window.y + window.height - 1, column: window.x + col, character: chars.bottomLeft, attributes: attrs, foregroundColor: color, backgroundColor: .default)
            } else if col == window.width - 1 {
                screenBuffer.setCell(row: window.y, column: window.x + col, character: chars.topRight, attributes: attrs, foregroundColor: color, backgroundColor: .default)
                screenBuffer.setCell(row: window.y + window.height - 1, column: window.x + col, character: chars.bottomRight, attributes: attrs, foregroundColor: color, backgroundColor: .default)
            } else {
                screenBuffer.setCell(row: window.y, column: window.x + col, character: chars.top, attributes: attrs, foregroundColor: color, backgroundColor: .default)
                screenBuffer.setCell(row: window.y + window.height - 1, column: window.x + col, character: chars.bottom, attributes: attrs, foregroundColor: color, backgroundColor: .default)
            }
        }
        
        for row in 1..<window.height - 1 {
            screenBuffer.setCell(row: window.y + row, column: window.x, character: chars.left, attributes: attrs, foregroundColor: color, backgroundColor: .default)
            screenBuffer.setCell(row: window.y + row, column: window.x + window.width - 1, character: chars.right, attributes: attrs, foregroundColor: color, backgroundColor: .default)
        }
        
        if let title = window.title, !title.isEmpty {
            let titleText = " \(title) "
            let startCol = max(2, (window.width - titleText.count) / 2)
            
            for (index, char) in titleText.enumerated() {
                let col = window.x + startCol + index
                if col < window.x + window.width - 1 {
                    screenBuffer.setCell(row: window.y, column: col, character: char, attributes: attrs, foregroundColor: color, backgroundColor: .default)
                }
            }
        }
    }
}
