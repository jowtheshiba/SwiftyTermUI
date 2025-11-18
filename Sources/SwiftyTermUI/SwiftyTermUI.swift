import Foundation

/// Main facade for working with TUI
@MainActor
public final class SwiftyTermUI {
    public static let shared = SwiftyTermUI()

    private let terminal = TerminalManager.shared
    private var screenBuffer: ScreenBuffer
    private let inputHandler: InputHandler
    private let panelManager = PanelManager()
    private let lock = NSLock()

    private var isInitialized = false
    private var cursorX = 0
    private var cursorY = 0
    private var cursorVisible = true

    private init() {
        let (width, height) = TerminalManager.shared.getTerminalSize()
        screenBuffer = ScreenBuffer(width: width, height: height)
        inputHandler = InputHandler()
    }

    /// Initializes TUI session
    public func initialize() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isInitialized else { return }

        try terminal.initialize()
        isInitialized = true

        // Subscribe to terminal resize events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTerminalResize),
            name: NSNotification.Name("TerminalDidResize"),
            object: nil
        )
    }

    /// Terminates TUI session and cleans up resources
    public func shutdown() {
        lock.lock()
        defer { lock.unlock() }

        guard isInitialized else { return }

        NotificationCenter.default.removeObserver(self)
        terminal.cleanup()
        isInitialized = false
    }

    // MARK: - Drawing

    /// Outputs character at position (y, x)
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

    /// Outputs text at position (y, x)
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

    /// Draws a box (rectangle) from the given character
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
    
    /// Draws a line
    public func drawLine(fromRow: Int, fromColumn: Int, toRow: Int, toColumn: Int, character: Character = "─", attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }
        
        DrawingUtils.drawLine(buffer: screenBuffer, fromRow: fromRow, fromColumn: fromColumn, toRow: toRow, toColumn: toColumn, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }
    
    /// Draws a rectangle (outline only)
    public func drawRect(row: Int, column: Int, width: Int, height: Int, character: Character = "█", attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }
        
        DrawingUtils.drawRect(buffer: screenBuffer, row: row, column: column, width: width, height: height, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }
    
    /// Draws a filled rectangle
    public func fillRect(row: Int, column: Int, width: Int, height: Int, character: Character = " ", attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        lock.lock()
        defer { lock.unlock() }
        
        DrawingUtils.fillRect(buffer: screenBuffer, row: row, column: column, width: width, height: height, character: character, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }
    
    /// Outputs centered text
    public func drawCenteredString(row: Int, width: Int, text: String, attributes: TextAttributes = [], foregroundColor: Color = .default, backgroundColor: Color = .default) {
        let (centeredText, startCol) = DrawingUtils.centerText(text, width: width)
        drawString(row: row, column: startCol, text: centeredText, attributes: attributes, foregroundColor: foregroundColor, backgroundColor: backgroundColor)
    }

    /// Clears screen area
    public func clearArea(row: Int, column: Int, width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }

        screenBuffer.clearArea(row: row, column: column, width: width, height: height)
    }

    /// Clears entire screen
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        screenBuffer.clear()
    }

    // MARK: - Rendering

    /// Refreshes screen - sends ANSI commands for output
    public func refresh() throws {
        lock.lock()
        defer { lock.unlock() }

        panelManager.renderToBuffer(screenBuffer)
        
        let commands = screenBuffer.generateRenderCommands()
        terminal.writeToTerminal(commands)
    }

    // MARK: - Input

    /// Reads next input event (non-blocking)
    public func readEvent() -> InputEvent? {
        inputHandler.readEvent()
    }
    
    /// Gets all events in the queue
    public func pollEvents() -> [InputEvent] {
        inputHandler.pollEvents()
    }
    
    /// Clears event queue
    public func clearEvents() {
        inputHandler.clearEvents()
    }

    // MARK: - Terminal Info

    /// Gets current terminal size
    public func getTerminalSize() -> (columns: Int, rows: Int) {
        terminal.getTerminalSize()
    }

    /// Gets terminal width in columns
    public var columns: Int {
        getTerminalSize().columns
    }

    /// Gets terminal height in rows
    public var rows: Int {
        getTerminalSize().rows
    }

    // MARK: - Cursor

    /// Sets cursor position
    public func setCursorPosition(row: Int, column: Int) {
        lock.lock()
        defer { lock.unlock() }

        cursorY = row
        cursorX = column
    }
    
    public func moveCursor(row: Int, column: Int) {
        setCursorPosition(row: row, column: column)
    }

    /// Gets current cursor position
    public func getCursorPosition() -> (row: Int, column: Int) {
        lock.lock()
        defer { lock.unlock() }

        return (cursorY, cursorX)
    }
    
    /// Shows cursor
    public func showCursor() {
        lock.lock()
        defer { lock.unlock() }
        
        cursorVisible = true
        terminal.writeToTerminal("\u{1B}[?25h")
    }
    
    /// Hides cursor
    public func hideCursor() {
        lock.lock()
        defer { lock.unlock() }
        
        cursorVisible = false
        terminal.writeToTerminal("\u{1B}[?25l")
    }
    
    /// Whether cursor is visible
    public var isCursorVisible: Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return cursorVisible
    }

    // MARK: - Window/Panel Management
    
    /// Creates a new window
    public func createWindow(x: Int, y: Int, width: Int, height: Int, hasBorder: Bool = false, borderStyle: Window.BorderStyle = .single) -> Window {
        Window(x: x, y: y, width: width, height: height, hasBorder: hasBorder, borderStyle: borderStyle)
    }
    
    /// Adds window to panels
    public func addPanel(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.addPanel(window)
    }
    
    /// Removes window from panels
    public func removePanel(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.removePanel(window)
    }
    
    /// Brings window to front
    public func bringToFront(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.bringToFront(window)
    }
    
    /// Sends window to back
    public func sendToBack(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.sendToBack(window)
    }
    
    /// Hides window
    public func hideWindow(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.hide(window)
    }
    
    /// Shows window
    public func showWindow(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.show(window)
    }
    
    /// Gets all windows
    public var allWindows: [Window] {
        panelManager.allPanels
    }
    
    /// Gets visible windows
    public var visibleWindows: [Window] {
        panelManager.visiblePanels
    }

    // MARK: - Private

    @objc
    private func handleTerminalResize() {
        lock.lock()
        defer { lock.unlock() }

        let (newWidth, newHeight) = terminal.getTerminalSize()
        screenBuffer.resize(width: newWidth, height: newHeight)

        // Try to refresh the screen
        panelManager.renderToBuffer(screenBuffer)
        let commands = screenBuffer.generateRenderCommands()
        terminal.writeToTerminal(commands)
    }
}
