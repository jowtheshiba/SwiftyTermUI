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
    /// True while the alternate screen buffer (DEC 1049) is active.
    public private(set) var isAlternateScreenActive = false

    /// Test hook: when set, all terminal output is routed here instead of
    /// `FileHandle.standardOutput`. Lets tests assert exact byte order
    /// (`?1049h` before first paint, `2J H` before `?1049l`) without a tty.
    internal var outputSink: ((Data) -> Void)?

    private init() {}

    /// Initializes the terminal for TUI operation
    /// - Switches to raw mode (no input buffering)
    /// - Disables echo
    /// - Sets up non-blocking reading
    /// - Parameters:
    ///   - useAlternateScreen: when true (default), enters the alternate screen
    ///     buffer (`ESC[?1049h`) after raw mode is established and before the
    ///     first `refresh()`. `?1049h` already clears the alt buffer, so no
    ///     extra `ESC[2J` is emitted here.
    /// - Note: the fallible `tcgetattr`/`tcsetattr` calls happen before any
    ///   escape sequence is emitted, so a throw leaves no half-entered state.
    public func initialize(useAlternateScreen: Bool = true) throws {
        lock.lock()
        defer { lock.unlock() }

        if isRawMode {
            // Re-entrant init (e.g. RetroVision calling initialize twice):
            // just enter the alt buffer if requested and not yet active.
            if useAlternateScreen && !isAlternateScreenActive {
                enterAlternateScreenUnlocked()
            }
            return
        }

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

        // Enter the alternate buffer BEFORE hiding the cursor etc., so the
        // first frame paints into the alt buffer with no flash of old content.
        if useAlternateScreen {
            enterAlternateScreenUnlocked()
        }

        // Hide cursor and enable bracketed paste
        emit("\u{1B}[?25l\u{1B}[?2004h")
    }

    // MARK: - Alternate screen buffer (DEC 1049)

    /// Enters the alternate screen buffer (`ESC[?1049h`). No-op when already
    /// active. Any buffered output is flushed first so it lands on the main
    /// screen, not the fresh alt buffer.
    public func enterAlternateScreen() {
        lock.lock()
        defer { lock.unlock() }
        enterAlternateScreenUnlocked()
    }

    /// Leaves the alternate screen buffer (`ESC[?1049l`), restoring the main
    /// screen byte-for-byte. No-op when not active.
    public func leaveAlternateScreen() {
        lock.lock()
        defer { lock.unlock() }
        leaveAlternateScreenUnlocked()
    }

    private func enterAlternateScreenUnlocked() {
        guard !isAlternateScreenActive else { return }
        // Flush pending main-screen output before switching buffers.
        flushBufferUnlocked()
        // NOTE: no extra ESC[2J here — ?1049h already clears the alt buffer.
        emit("\u{1B}[?1049h")
        isAlternateScreenActive = true
    }

    private func leaveAlternateScreenUnlocked() {
        guard isAlternateScreenActive else { return }
        flushBufferUnlocked()
        emit("\u{1B}[?1049l")
        isAlternateScreenActive = false
    }

    /// Restores original terminal parameters.
    /// Exit order while the alternate buffer is active: cursor restore and
    /// bracketed-paste off plus the trailing `ESC[2J ESC[H` all run while
    /// *still in* the alternate buffer (so the `2J` clears the alt buffer,
    /// never the user's main screen), and only then is `ESC[?1049l` emitted
    /// to restore the main screen byte-for-byte.
    /// Idempotent: a second call (or a call after a throwing `initialize()`)
    /// is a safe no-op.
    public func cleanup() {
        lock.lock()
        defer { lock.unlock() }

        guard isRawMode else {
            // Never entered raw mode (e.g. initialize() threw), but don't
            // strand the terminal in the alt buffer if it was entered
            // directly via enterAlternateScreen().
            if isAlternateScreenActive {
                leaveAlternateScreenUnlocked()
            }
            return
        }

        // Disable mouse tracking if enabled
        if isMouseTrackingEnabled {
            writeToTerminal("\u{1B}[?1006l\u{1B}[?1003l\u{1B}[?1002l")
            isMouseTrackingEnabled = false
        }

        // Remember whether we must leave the alt buffer AFTER the sequences
        // below have run inside it.
        let wasAlternateScreenActive = isAlternateScreenActive

        // Show cursor and disable bracketed paste
        writeBuffer.append("\u{1B}[?25h\u{1B}[?2004l")

        // Clear screen and return cursor to home position.
        // When the alt buffer is active this clears the alt buffer; the main
        // screen underneath is untouched and restored by ?1049l below.
        writeBuffer.append("\u{1B}[2J\u{1B}[H")

        if wasAlternateScreenActive {
            writeBuffer.append("\u{1B}[?1049l")
            isAlternateScreenActive = false
        }

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
            writeData(data)
        }
    }

    /// Writes raw data directly to terminal (optimized for batched commands)
    func writeRawToTerminal(_ data: Data) {
        writeData(data)
    }

    /// Immediate unbuffered write used for init/cleanup sequences, so their
    /// order relative to flushed buffer content is exact.
    private func emit(_ command: String) {
        if let data = command.data(using: .utf8) {
            writeData(data)
        }
    }

    /// Single choke point for all terminal output. Routes to `outputSink`
    /// when a test has installed one, otherwise to stdout.
    private func writeData(_ data: Data) {
        if let sink = outputSink {
            sink(data)
        } else {
            FileHandle.standardOutput.write(data)
        }
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
            writeData(data)
        }
        writeBuffer.removeAll(keepingCapacity: true)
    }

    /// Test-only: forces the raw-mode flag without touching the real tty, so
    /// `cleanup()` ordering can be exercised without a terminal.
    /// Has no effect on the actual termios state.
    internal func _setRawModeForTesting(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        isRawMode = value
    }

    /// Test-only: resets alternate-screen and raw-mode flags plus buffered
    /// output without emitting anything.
    internal func _resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        isRawMode = false
        isAlternateScreenActive = false
        isMouseTrackingEnabled = false
        writeBuffer.removeAll(keepingCapacity: true)
        outputSink = nil
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
