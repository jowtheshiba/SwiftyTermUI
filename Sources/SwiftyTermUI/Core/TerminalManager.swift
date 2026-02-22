import Darwin
import Foundation

/// Terminal state and configuration management
@MainActor
public final class TerminalManager {
    public static let shared = TerminalManager()

    private var originalTermios: termios = termios()
    private var isRawMode = false
    private let lock = NSLock()
    private var writeBuffer = ""
    private let bufferFlushThreshold = 8192 // Flush when buffer reaches 8KB
    private var isMouseTrackingEnabled = false

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

        // Disable canonical mode, echo, and signals (ISIG allows capturing Ctrl+C)
        newTermios.c_lflag &= ~(UInt(ICANON) | UInt(ECHO) | UInt(ISIG))
        newTermios.c_cc.16 = 0 // VMIN  — index 16 on macOS/Darwin
        newTermios.c_cc.17 = 0 // VTIME — index 17 on macOS/Darwin

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

        // Hide cursor and enable bracketed paste
        if let data = "\u{1B}[?25l\u{1B}[?2004h".data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }

    /// Restores original terminal parameters
    public func cleanup() {
        lock.lock()
        defer { lock.unlock() }

        guard isRawMode else { return }

        // Disable mouse tracking if enabled
        if isMouseTrackingEnabled {
            writeToTerminal("\u{1B}[?1006l\u{1B}[?1003l\u{1B}[?1002l")
            isMouseTrackingEnabled = false
        }
        
        // Show cursor and disable bracketed paste
        writeBuffer.append("\u{1B}[?25h\u{1B}[?2004l")

        // Clear screen and return cursor to home position
        writeBuffer.append("\u{1B}[2J\u{1B}[H")

        // Flush all buffered commands before cleanup
        flushBufferUnlocked()

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

    /// Writes raw data directly to terminal (optimized for batched commands)
    func writeRawToTerminal(_ data: Data) {
        FileHandle.standardOutput.write(data)
    }

    /// Buffers a command and flushes when threshold is reached
    func bufferCommand(_ command: String) {
        lock.lock()
        defer { lock.unlock() }

        writeBuffer.append(command)
        if writeBuffer.utf8.count >= bufferFlushThreshold {
            flushBufferUnlocked()
        }
    }

    /// Flushes any buffered commands immediately
    public func flushBuffer() {
        lock.lock()
        defer { lock.unlock() }

        flushBufferUnlocked()
    }

    private func flushBufferUnlocked() {
        guard !writeBuffer.isEmpty else { return }

        if let data = writeBuffer.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
        writeBuffer.removeAll(keepingCapacity: true)
    }
    
    // MARK: - Mouse Tracking
    
    public func enableMouseTracking(allMotion: Bool = true) {
        guard !isMouseTrackingEnabled else { return }
        
        let baseSequence = "\u{1B}[?1000h\u{1B}[?1002h" // Enable basic + drag tracking
        let motionSequence = allMotion ? "\u{1B}[?1003h" : ""
        let sgrSequence = "\u{1B}[?1006h" // Extended coordinates (SGR)
        writeToTerminal(baseSequence + motionSequence + sgrSequence)
        isMouseTrackingEnabled = true
    }
    
    public func disableMouseTracking() {
        guard isMouseTrackingEnabled else { return }
        
        let sequence = "\u{1B}[?1006l\u{1B}[?1003l\u{1B}[?1002l\u{1B}[?1000l"
        writeToTerminal(sequence)
        isMouseTrackingEnabled = false
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
