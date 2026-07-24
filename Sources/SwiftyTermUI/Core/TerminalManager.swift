#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

/// Set from the SIGWINCH handler and polled by InputHandler.
/// A plain sig_atomic_t flag is the only async-signal-safe mechanism —
/// anything allocating (NotificationCenter, queues) is UB inside a handler.
nonisolated(unsafe) var terminalResizePending: sig_atomic_t = 0

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
        newTermios.c_lflag &= ~(tcflag_t(ICANON) | tcflag_t(ECHO) | tcflag_t(ISIG))
        // VMIN/VTIME indices differ across platforms (Darwin: 16/17, Linux: 6/5),
        // so index the c_cc tuple through raw bytes using the system constants
        withUnsafeMutableBytes(of: &newTermios.c_cc) { cc in
            cc[Int(VMIN)] = 0
            cc[Int(VTIME)] = 0
        }

        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &newTermios) == 0 else {
            throw TerminalError.failedToSetTerminalAttributes
        }

        isRawMode = true

        // Set up resize signal handling (async-signal-safe: only sets a flag)
        signal(SIGWINCH, { _ in
            terminalResizePending = 1
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

        #if os(Linux)
        let request: UInt = 0x5413 // TIOCGWINSZ (not always exposed by Glibc)
        #else
        let request = UInt(TIOCGWINSZ)
        #endif
        guard ioctl(STDOUT_FILENO, request, &size) == 0 else {
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
