import Darwin
import Foundation

/// Types of events that can occur
public enum InputEvent: Equatable {
    case keyPress(Key)
    case terminalResize
}

/// Key types
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
    case insert
    case up
    case down
    case left
    case right

    // MARK: - Function keys

    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    // MARK: - Control combinations

    case ctrl(_ char: Character)
    case alt(_ char: Character)
    
    // MARK: - Regular character

    case character(_ char: Character)

    // MARK: - Unknown

    case unknown
}

/// Terminal input handler
public final class InputHandler {
    private var buffer = ""
    private let lock = NSLock()
    private let eventQueue = EventQueue()
    private let resizeNotification = NSNotification.Name("TerminalDidResize")

    public init() {
        NotificationCenter.default.addObserver(
            forName: resizeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.eventQueue.enqueue(.terminalResize)
        }
    }

    /// Reads the next input event (non-blocking)
    public func readEvent() -> InputEvent? {
        // First check the event queue
        if let event = eventQueue.dequeue() {
            return event
        }
        
        lock.lock()
        defer { lock.unlock() }

        // Try to read a character from stdin
        var byte: UInt8 = 0
        let bytesRead = read(STDIN_FILENO, &byte, 1)

        guard bytesRead > 0 else {
            return nil
        }

        // Add the character to the buffer
        buffer.append(Character(UnicodeScalar(byte)))

        // Try to recognize the combination
        if let key = parseBuffer() {
            let event = InputEvent.keyPress(key)
            eventQueue.enqueue(event)
            return eventQueue.dequeue()
        }

        // If it's a regular character, return immediately
        if buffer.count == 1, byte >= 32 && byte < 127 {
            let char = Character(UnicodeScalar(byte))
            buffer.removeAll()
            return .keyPress(.character(char))
        }

        return nil
    }
    
    /// Gets all events currently in the queue
    public func pollEvents() -> [InputEvent] {
        var events: [InputEvent] = []
        
        while let event = readEvent() {
            events.append(event)
        }
        
        return events
    }
    
    /// Clears the event queue
    public func clearEvents() {
        eventQueue.clear()
    }

    /// Parses ANSI escape sequences
    private func parseBuffer() -> Key? {
        // Enter
        if buffer == "\r" || buffer == "\n" {
            buffer.removeAll()
            return .enter
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
        
        // Control keys (Ctrl+A-Z = 1-26)
        if buffer.count == 1, let first = buffer.first {
            let scalar = first.unicodeScalars.first?.value ?? 0
            if scalar >= 1 && scalar <= 26 {
                buffer.removeAll()
                let char = Character(UnicodeScalar(scalar + 96)!)
                return .ctrl(char)
            }
        }

        // ANSI escape sequences
        if buffer.hasPrefix("\u{1B}[") || buffer.hasPrefix("\u{1B}O") {
            return parseEscapeSequence()
        }
        
        // Alt + character (ESC followed by a character)
        if buffer.count == 2 && buffer.hasPrefix("\u{1B}") {
            let char = buffer.last!
            buffer.removeAll()
            return .alt(char)
        }
        
        // Plain ESC
        if buffer == "\u{1B}" {
            // Wait for more characters for escape sequences
            return nil
        }

        // Regular key
        if buffer.count == 1, let first = buffer.first {
            buffer.removeAll()
            return .character(first)
        }

        return nil
    }

    /// Parses escape sequences
    private func parseEscapeSequence() -> Key? {
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

        // Home: ESC [ H or ESC [ 1 ~ or ESC O H
        if buffer == "\u{1B}[H" || buffer == "\u{1B}[1~" || buffer == "\u{1B}OH" {
            buffer.removeAll()
            return .home
        }

        // End: ESC [ F or ESC [ 4 ~ or ESC O F
        if buffer == "\u{1B}[F" || buffer == "\u{1B}[4~" || buffer == "\u{1B}OF" {
            buffer.removeAll()
            return .end
        }

        // Insert: ESC [ 2 ~
        if buffer == "\u{1B}[2~" {
            buffer.removeAll()
            return .insert
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
        // F1-F4: ESC O P/Q/R/S
        if buffer == "\u{1B}OP" { buffer.removeAll(); return .f1 }
        if buffer == "\u{1B}OQ" { buffer.removeAll(); return .f2 }
        if buffer == "\u{1B}OR" { buffer.removeAll(); return .f3 }
        if buffer == "\u{1B}OS" { buffer.removeAll(); return .f4 }
        
        // F1-F12: ESC [ 1 1 ~ to ESC [ 2 4 ~
        if buffer == "\u{1B}[11~" { buffer.removeAll(); return .f1 }
        if buffer == "\u{1B}[12~" { buffer.removeAll(); return .f2 }
        if buffer == "\u{1B}[13~" { buffer.removeAll(); return .f3 }
        if buffer == "\u{1B}[14~" { buffer.removeAll(); return .f4 }
        if buffer == "\u{1B}[15~" { buffer.removeAll(); return .f5 }
        if buffer == "\u{1B}[17~" { buffer.removeAll(); return .f6 }
        if buffer == "\u{1B}[18~" { buffer.removeAll(); return .f7 }
        if buffer == "\u{1B}[19~" { buffer.removeAll(); return .f8 }
        if buffer == "\u{1B}[20~" { buffer.removeAll(); return .f9 }
        if buffer == "\u{1B}[21~" { buffer.removeAll(); return .f10 }
        if buffer == "\u{1B}[23~" { buffer.removeAll(); return .f11 }
        if buffer == "\u{1B}[24~" { buffer.removeAll(); return .f12 }

        // If it's an incomplete escape sequence, wait for more characters
        if buffer.count < 6 {
            return nil
        }

        // Unknown combination
        buffer.removeAll()
        return .unknown
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
