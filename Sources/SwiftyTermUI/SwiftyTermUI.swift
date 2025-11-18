import Foundation

/// Основний фасад для роботи з TUI
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

    /// Ініціалізує TUI сеанс
    public func initialize() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isInitialized else { return }

        try terminal.initialize()
        isInitialized = true

        // Підписуємося на зміну розміру терміналу
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTerminalResize),
            name: NSNotification.Name("TerminalDidResize"),
            object: nil
        )
    }

    /// Завершує TUI сеанс та очищує ресурси
    public func shutdown() {
        lock.lock()
        defer { lock.unlock() }

        guard isInitialized else { return }

        NotificationCenter.default.removeObserver(self)
        terminal.cleanup()
        isInitialized = false
    }

    // MARK: - Drawing

    /// Виводить символ на позицію (y, x)
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

    /// Виводить текст на позицію (y, x)
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

    /// Малює box (прямокутник) з заданого символу
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

    /// Очищує область екрану
    public func clearArea(row: Int, column: Int, width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }

        screenBuffer.clearArea(row: row, column: column, width: width, height: height)
    }

    /// Очищує весь екран
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        screenBuffer.clear()
    }

    // MARK: - Rendering

    /// Оновлює екран - відправляє ANSI команди на вивід
    public func refresh() throws {
        lock.lock()
        defer { lock.unlock() }

        panelManager.renderToBuffer(screenBuffer)
        
        let commands = screenBuffer.generateRenderCommands()
        terminal.writeToTerminal(commands)
    }

    // MARK: - Input

    /// Читає наступну подію введення (non-blocking)
    public func readEvent() -> InputEvent? {
        inputHandler.readEvent()
    }

    // MARK: - Terminal Info

    /// Отримує поточні розміри терміналу
    public func getTerminalSize() -> (columns: Int, rows: Int) {
        terminal.getTerminalSize()
    }

    /// Отримує ширину терміналу в колонках
    public var columns: Int {
        getTerminalSize().columns
    }

    /// Отримує висоту терміналу в рядках
    public var rows: Int {
        getTerminalSize().rows
    }

    // MARK: - Cursor

    /// Встановлює позицію курсора
    public func setCursorPosition(row: Int, column: Int) {
        lock.lock()
        defer { lock.unlock() }

        cursorY = row
        cursorX = column
    }
    
    public func moveCursor(row: Int, column: Int) {
        setCursorPosition(row: row, column: column)
    }

    /// Отримує поточну позицію курсора
    public func getCursorPosition() -> (row: Int, column: Int) {
        lock.lock()
        defer { lock.unlock() }

        return (cursorY, cursorX)
    }
    
    /// Показує курсор
    public func showCursor() {
        lock.lock()
        defer { lock.unlock() }
        
        cursorVisible = true
        terminal.writeToTerminal("\u{1B}[?25h")
    }
    
    /// Ховає курсор
    public func hideCursor() {
        lock.lock()
        defer { lock.unlock() }
        
        cursorVisible = false
        terminal.writeToTerminal("\u{1B}[?25l")
    }
    
    /// Чи курсор видимий
    public var isCursorVisible: Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return cursorVisible
    }

    // MARK: - Window/Panel Management
    
    /// Створює нове вікно
    public func createWindow(x: Int, y: Int, width: Int, height: Int, hasBorder: Bool = false, borderStyle: Window.BorderStyle = .single) -> Window {
        Window(x: x, y: y, width: width, height: height, hasBorder: hasBorder, borderStyle: borderStyle)
    }
    
    /// Додає вікно до панелей
    public func addPanel(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.addPanel(window)
    }
    
    /// Видаляє вікно з панелей
    public func removePanel(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.removePanel(window)
    }
    
    /// Переносить вікно на передній план
    public func bringToFront(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.bringToFront(window)
    }
    
    /// Відправляє вікно на задній план
    public func sendToBack(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.sendToBack(window)
    }
    
    /// Ховає вікно
    public func hideWindow(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.hide(window)
    }
    
    /// Показує вікно
    public func showWindow(_ window: Window) {
        lock.lock()
        defer { lock.unlock() }
        
        panelManager.show(window)
    }
    
    /// Отримує всі вікна
    public var allWindows: [Window] {
        panelManager.allPanels
    }
    
    /// Отримує видимі вікна
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

        // Спробуємо оновити екран
        panelManager.renderToBuffer(screenBuffer)
        let commands = screenBuffer.generateRenderCommands()
        terminal.writeToTerminal(commands)
    }
}
