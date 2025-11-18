import Darwin
import Foundation

/// Terminal state and configuration management
@MainActor
public final class TerminalManager {
    public static let shared = TerminalManager()

    private var originalTermios: termios = termios()
    private var isRawMode = false
    private let lock = NSLock()

    private init() {}

    /// Initializes the terminal for TUI operation
    /// - Switches to raw mode (no input buffering)
    /// - Disables echo
    /// - Sets up non-blocking reading
    public func initialize() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isRawMode else { return }

        // Save original parameters
        guard tcgetattr(STDIN_FILENO, &originalTermios) == 0 else {
            throw TerminalError.failedToGetTerminalAttributes
        }

        var newTermios = originalTermios

        // Disable canonical mode and echo
        newTermios.c_lflag &= ~(UInt(ICANON) | UInt(ECHO))
        newTermios.c_cc.0 = 0 // VMIN
        newTermios.c_cc.1 = 0 // VTIME

        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &newTermios) == 0 else {
            throw TerminalError.failedToSetTerminalAttributes
        }

        isRawMode = true

        // Set up resize signal handling
        signal(SIGWINCH, { _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("TerminalDidResize"),
                object: nil
            )
        })

        // Hide cursor
        writeToTerminal("\u{1B}[?25l")
    }

    /// Restores original terminal parameters
    public func cleanup() {
        lock.lock()
        defer { lock.unlock() }

        guard isRawMode else { return }

        // Show cursor
        writeToTerminal("\u{1B}[?25h")

        // Clear screen and return cursor to home position
        writeToTerminal("\u{1B}[2J\u{1B}[H")

        // Restore original termios
        _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        isRawMode = false
    }

    /// Gets current terminal dimensions
    public func getTerminalSize() -> (columns: Int, rows: Int) {
        var size = winsize()

        guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0 else {
            return (80, 24) // Default values
        }

        return (Int(size.ws_col), Int(size.ws_row))
    }

    /// Writes ANSI command directly to terminal
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
            return "Failed to get terminal parameters"
        case .failedToSetTerminalAttributes:
            return "Failed to set terminal parameters"
        case .failedToReadInput:
            return "Failed to read input"
        }
    }
}
