import Darwin
import Foundation

/// Типи подій що можуть виникнути
public enum InputEvent: Equatable {
    case keyPress(Key)
    case terminalResize
}

/// Типи клавіш
public enum Key: Equatable {
    // MARK: - Special keys

    case enter
    case escape
    case tab
    case backspace
    case delete
    case home
    case end
    case pageUp
    case pageDown
    case up
    case down
    case left
    case right

    // MARK: - Function keys

    case f(_ number: Int) // F1-F12

    // MARK: - Regular character

    case character(_ char: Character)

    // MARK: - Unknown

    case unknown
}

/// Обробник введення з терміналу
public final class InputHandler {
    private var buffer = ""
    private let lock = NSLock()
    private let resizeNotification = NSNotification.Name("TerminalDidResize")

    public init() {
        NotificationCenter.default.addObserver(
            forName: resizeNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Обробка resize сигналу
        }
    }

    /// Читає наступну подію введення (non-blocking)
    public func readEvent() -> InputEvent? {
        lock.lock()
        defer { lock.unlock() }

        // Спробуємо прочитати символ з stdin
        var byte: UInt8 = 0
        let bytesRead = read(STDIN_FILENO, &byte, 1)

        guard bytesRead > 0 else {
            return nil
        }

        // Додаємо символ до буфера
        buffer.append(Character(UnicodeScalar(byte)))

        // Спробуємо розпізнати комбінацію
        if let key = parseBuffer() {
            return .keyPress(key)
        }

        // Якщо це звичайний символ, відразу повертаємо
        if buffer.count == 1, byte >= 32 && byte < 127 {
            let char = Character(UnicodeScalar(byte))
            buffer.removeAll()
            return .keyPress(.character(char))
        }

        return nil
    }

    /// Розпізнає ANSI escape sequences
    private func parseBuffer() -> Key? {
        // Enter
        if buffer == "\r" || buffer == "\n" {
            buffer.removeAll()
            return .enter
        }

        // Escape
        if buffer == "\u{1B}" {
            // Чекаємо більше символів для escape sequences
            return nil
        }

        // Backspace
        if buffer == "\u{7F}" || buffer == "\u{08}" {
            buffer.removeAll()
            return .backspace
        }

        // Tab
        if buffer == "\t" {
            buffer.removeAll()
            return .tab
        }

        // ANSI escape sequences
        if buffer.hasPrefix("\u{1B}[") {
            return parseArrowKeys()
        }

        // Регулярна клавіша
        if buffer.count == 1, let first = buffer.first {
            buffer.removeAll()
            return .character(first)
        }

        return nil
    }

    /// Розпізнає стрілки та спеціальні клавіші
    private func parseArrowKeys() -> Key? {
        // Arrow keys: ESC [ A/B/C/D
        if buffer == "\u{1B}[A" {
            buffer.removeAll()
            return .up
        }
        if buffer == "\u{1B}[B" {
            buffer.removeAll()
            return .down
        }
        if buffer == "\u{1B}[C" {
            buffer.removeAll()
            return .right
        }
        if buffer == "\u{1B}[D" {
            buffer.removeAll()
            return .left
        }

        // Home: ESC [ H або ESC [ 1 ~ або ESC O H
        if buffer == "\u{1B}[H" || buffer == "\u{1B}[1~" || buffer == "\u{1B}OH" {
            buffer.removeAll()
            return .home
        }

        // End: ESC [ F або ESC [ 4 ~ або ESC O F
        if buffer == "\u{1B}[F" || buffer == "\u{1B}[4~" || buffer == "\u{1B}OF" {
            buffer.removeAll()
            return .end
        }

        // Delete: ESC [ 3 ~
        if buffer == "\u{1B}[3~" {
            buffer.removeAll()
            return .delete
        }

        // Page Up: ESC [ 5 ~
        if buffer == "\u{1B}[5~" {
            buffer.removeAll()
            return .pageUp
        }

        // Page Down: ESC [ 6 ~
        if buffer == "\u{1B}[6~" {
            buffer.removeAll()
            return .pageDown
        }

        // Function keys F1-F12
        for i in 1 ... 12 {
            let code = String(format: "\u{1B}[%d~", i)
            if buffer.hasPrefix(code) {
                buffer.removeAll()
                return .f(i)
            }
        }

        // Якщо це неповна escape sequence, чекаємо більше символів
        if buffer.count < 6 {
            return nil
        }

        // Невідома комбінація
        buffer.removeAll()
        return .unknown
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
