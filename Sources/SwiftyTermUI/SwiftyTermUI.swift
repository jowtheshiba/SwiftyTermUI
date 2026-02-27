import Foundation

/// Main facade for working with TUI
@MainActor
public final class SwiftyTermUI {
    public static let shared = SwiftyTermUI()

    private let terminal = TerminalManager.shared
    private var screenBuffer: ScreenBuffer
    private let inputHandler: InputHandler
    private let panelManager = PanelManager()
    private let renderOptimizer = RenderOptimizer()
    private let lock = NSRecursiveLock()

    private var isInitialized = false
    private var cursorX = 0
    private var cursorY = 0
    private var cursorVisible = true
    private var mouseCaptureEnabled = false

    private init() {
        let (width, height) = TerminalManager.shared.getTerminalSize()
        screenBuffer = ScreenBuffer(width: width, height: height)
        inputHandler = InputHandler()
    }

    public func initialize() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isInitialized else { return }

        try terminal.initialize()
        isInitialized = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTerminalResize),
            name: NSNotification.Name("TerminalDidResize"),
            object: nil
        )
    }

    public func shutdown() {
        lock.lock()
        defer { lock.unlock() }

        guard isInitialized else { return }

        NotificationCenter.default.removeObserver(self)
        disableMouseCapture()
        terminal.cleanup()
        isInitialized = false
    }

    public func addChar(row: Int, column: Int, character: Character, attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }

        screenBuffer.setCell(
            row: row,
            column: column,
            character: character,
            attributes: attributes,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }
    
    public func drawChar(row: Int, column: Int, character: Character, attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        addChar(row: row, column: column, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }

    public func getCell(row: Int, column: Int) -> Cell {
        screenBuffer.getCell(row: row, column: column)
    }

    public func drawCell(row: Int, column: Int, cell: Cell) {
        addChar(row: row, column: column, character: cell.character, attributes: cell.attributes, foregroundColor: cell.foregroundColor, backgroundColor: cell.backgroundColor)
    }

    public func addString(row: Int, column: Int, text: String, attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }

        screenBuffer.setString(
            row: row,
            column: column,
            text: text,
            attributes: attributes,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }
    
    public func drawString(row: Int, column: Int, text: String, attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        addString(row: row, column: column, text: text, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }

    public func addBox(row: Int, column: Int, width: Int, height: Int, character: Character = " ", attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }

        for y in row..<min(row + height, rows) {
            for x in column..<min(column + width, columns) {
                screenBuffer.setCell(
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
    
    // MARK: - Drawing Utilities
    
    public func drawLine(fromRow: Int, fromColumn: Int, toRow: Int, toColumn: Int, character: Character = "─", attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }
        
        DrawingUtils.drawLine(buffer: screenBuffer, fromRow: fromRow, fromColumn: fromColumn, toRow: toRow, toColumn: toColumn, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }
    
    public func drawRect(row: Int, column: Int, width: Int, height: Int, character: Character = "█", attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }
        
        DrawingUtils.drawRect(buffer: screenBuffer, row: row, column: column, width: width, height: height, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }
    
    public func fillRect(row: Int, column: Int, width: Int, height: Int, character: Character = " ", attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }
        
        DrawingUtils.fillRect(buffer: screenBuffer, row: row, column: column, width: width, height: height, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }
    
    public func drawCenteredString(row: Int, width: Int, text: String, attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        let (centeredText, startCol) = DrawingUtils.centerText(text, width: width)
        drawString(row: row, column: startCol, text: centeredText, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }

    public func clearArea(row: Int, column: Int, width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }

        screenBuffer.clearArea(row: row, column: column, width: width, height: height)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        screenBuffer.clear()
    }

    // MARK: - Rendering

    public func refresh() throws {
        lock.lock()
        defer { lock.unlock() }

        panelManager.renderToBuffer(screenBuffer)
        
        // Use optimized renderer with caching and batching
        let commands = renderOptimizer.generateOptimizedRenderCommands(buffer: screenBuffer)
        terminal.writeToTerminal(commands)
        
        // Position cursor to the stored position after rendering
        terminal.writeToTerminal("\u{1B}[\(cursorY + 1);\(cursorX + 1)H")
    }

    // MARK: - Input

    public func readEvent() -> InputEvent? {
        inputHandler.readEvent()
    }
    
    public func pollEvents() -> [InputEvent] {
        inputHandler.pollEvents()
    }
    
    public func clearEvents() {
        inputHandler.clearEvents()
    }
    
    public func pollMouseEvents() -> [InputEvent] {
        inputHandler.pollMouseEvents()
    }
    
    // MARK: - Mouse
    
    public func enableMouseCapture(allMotion: Bool = true) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !mouseCaptureEnabled else { return }
        
        terminal.enableMouseTracking(allMotion: allMotion)
        mouseCaptureEnabled = true
    }
    
    public func disableMouseCapture() {
        lock.lock()
        defer { lock.unlock() }
        
        guard mouseCaptureEnabled else { return }
        
        terminal.disableMouseTracking()
        mouseCaptureEnabled = false
    }

    // MARK: - Terminal Info

    public func getTerminalSize() -> (columns: Int, rows: Int) {
        terminal.getTerminalSize()
    }

    public var columns: Int {
        getTerminalSize().columns
    }

    public var rows: Int {
        getTerminalSize().rows
    }

    // MARK: - Cursor

    public func setCursorPosition(row: Int, column: Int) {
        lock.lock()
        defer { lock.unlock() }

        cursorY = row
        cursorX = column
    }
    
    public func moveCursor(row: Int, column: Int) {
        setCursorPosition(row: row, column: column)
    }

    public func getCursorPosition() -> (row: Int, column: Int) {
        lock.lock()
        defer { lock.unlock() }

        return (cursorY, cursorX)
    }
    
    public func showCursor() {
        lock.lock()
        defer { lock.unlock() }
        
        cursorVisible = true
        terminal.writeToTerminal("\u{1B}[?25h")
    }
    
    public func hideCursor() {
        lock.lock()
        defer { lock.unlock() }
        
        cursorVisible = false
        terminal.writeToTerminal("\u{1B}[?25l")
    }
    
    public var isCursorVisible: Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return cursorVisible
    }

    // MARK: - Window/Panel Management
    
    public func createWindow(x: Int, y: Int, width: Int, height: Int, hasBorder: Bool = false, borderStyle: Window.BorderStyle = .single) -> Window {
        Window(x: x, y: y, width: width, height: height, hasBorder: hasBorder, borderStyle: borderStyle)
    }
    
    public func addPanel(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.addPanel(window)
    }
    
    public func removePanel(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.removePanel(window)
    }
    
    public func bringToFront(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.bringToFront(window)
    }
    
    public func sendToBack(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.sendToBack(window)
    }
    
    public func hideWindow(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.hide(window)
    }
    
    public func showWindow(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.show(window)
    }
    
    public var allWindows: [Window] {
        panelManager.allPanels
    }
    
    public var visibleWindows: [Window] {
        panelManager.visiblePanels
    }

    public func clearRenderCache() {
        lock.lock()
        defer { lock.unlock() }

        renderOptimizer.clearCache()
    }

    public func getRenderStatistics() -> OptimizerStatistics {
        lock.lock()
        defer { lock.unlock() }

        return renderOptimizer.getStatistics()
    }

    public func flushOutput() {
        lock.lock()
        defer { lock.unlock() }

        terminal.flushBuffer()
    }

    // MARK: - Private

    @objc
    private func handleTerminalResize() {
        lock.lock()
        defer { lock.unlock() }

        let (newWidth, newHeight) = terminal.getTerminalSize()
        screenBuffer.resize(width: newWidth, height: newHeight)

        panelManager.renderToBuffer(screenBuffer)
        let commands = renderOptimizer.generateOptimizedRenderCommands(buffer: screenBuffer)
        terminal.writeToTerminal(commands)
    }
}
