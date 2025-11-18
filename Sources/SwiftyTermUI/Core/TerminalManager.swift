import Darwin
import Foundation

/// Управління станом та налаштуванням терміналу
@MainActor
public final class TerminalManager {
    public static let shared = TerminalManager()

    private var originalTermios: termios = termios()
    private var isRawMode = false
    private let lock = NSLock()

    private init() {}

    /// Ініціалізує термінал для TUI роботи
    /// - Переводить в raw mode (без буферизації вводу)
    /// - Відключає echo
    /// - Устанавлює non-blocking читання
    public func initialize() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isRawMode else { return }

        // Зберігаємо оригінальні параметри
        guard tcgetattr(STDIN_FILENO, &originalTermios) == 0 else {
            throw TerminalError.failedToGetTerminalAttributes
        }

        var newTermios = originalTermios

        // Відключаємо канонічний режим та echo
        newTermios.c_lflag &= ~(UInt(ICANON) | UInt(ECHO))
        newTermios.c_cc.0 = 0 // VMIN
        newTermios.c_cc.1 = 0 // VTIME

        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &newTermios) == 0 else {
            throw TerminalError.failedToSetTerminalAttributes
        }

        isRawMode = true

        // Налаштування обробки resize сигналу
        signal(SIGWINCH, { _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("TerminalDidResize"),
                object: nil
            )
        })

        // Приховуємо курсор
        writeToTerminal("\u{1B}[?25l")
    }

    /// Відновлює оригінальні параметри терміналу
    public func cleanup() {
        lock.lock()
        defer { lock.unlock() }

        guard isRawMode else { return }

        // Показуємо курсор
        writeToTerminal("\u{1B}[?25h")

        // Очищуємо екран та повертаємо курсор в домашню позицію
        writeToTerminal("\u{1B}[2J\u{1B}[H")

        // Відновлюємо оригінальні termios
        _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        isRawMode = false
    }

    /// Отримує поточні розміри терміналу
    public func getTerminalSize() -> (columns: Int, rows: Int) {
        var size = winsize()

        guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0 else {
            return (80, 24) // Значення за замовчуванням
        }

        return (Int(size.ws_col), Int(size.ws_row))
    }

    /// Записує ANSI команду прямо в термінал
    func writeToTerminal(_ command: String) {
        if let data = command.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }
}

// MARK: - Error Handling

public enum TerminalError: Error, LocalizedError {
    case failedToGetTerminalAttributes
    case failedToSetTerminalAttributes
    case failedToReadInput

    public var errorDescription: String? {
        switch self {
        case .failedToGetTerminalAttributes:
            return "Не вдалось отримати параметри терміналу"
        case .failedToSetTerminalAttributes:
            return "Не вдалось встановити параметри терміналу"
        case .failedToReadInput:
            return "Не вдалось прочитати введення"
        }
    }
}
