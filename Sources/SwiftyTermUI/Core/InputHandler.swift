import Darwin
import Foundation

/// Types of events that can occur
public enum InputEvent: Equatable {
    case keyPress(Key)
    case mouse(InputMouseEvent)
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

/// Mouse event payload
public struct InputMouseEvent: Equatable, Sendable {
    public enum Button: Equatable, Sendable {
        case left
        case middle
        case right
        case wheelUp
        case wheelDown
        case none
    }
    
    public enum Action: Equatable, Sendable {
        case down
        case up
        case drag
        case move
        case scroll
    }
    
    public struct Modifiers: OptionSet, Equatable, Sendable {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let shift = Modifiers(rawValue: 1 << 0)
        public static let alt = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
    }
    
    public let row: Int
    public let column: Int
    public let button: Button
    public let action: Action
    public let modifiers: Modifiers
    
    public init(row: Int, column: Int, button: Button, action: Action, modifiers: Modifiers = []) {
        self.row = row
        self.column = column
        self.button = button
        self.action = action
        self.modifiers = modifiers
    }
}

/// Terminal input handler
@MainActor
public final class InputHandler: NSObject {
    private var buffer = ""
    private let lock = NSLock()
    private let eventQueue = EventQueue()
    private let resizeNotification = NSNotification.Name("TerminalDidResize")

    public override init() {
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResizeNotification(_:)),
            name: resizeNotification,
            object: nil
        )
    }

    /// Reads the next input event (non-blocking)
    public func readEvent() -> InputEvent? {
        // First check the event queue
        if let event = eventQueue.dequeue() {
            return event
        }
        
        lock.lock()
        defer { lock.unlock() }

        // Try to read available bytes from stdin (read up to 64 bytes to capture full mouse sequences)
        var readBuffer = [UInt8](repeating: 0, count: 64)
        let bytesRead = read(STDIN_FILENO, &readBuffer, 64)

        if bytesRead > 0 {
            // Add all read characters to the buffer
            for i in 0..<bytesRead {
                buffer.append(Character(UnicodeScalar(readBuffer[i])))
            }
        } else if bytesRead < 0 {
            // Error reading (EAGAIN/EWOULDBLOCK in non-blocking mode is normal)
            let errno = Darwin.errno
            if errno != EAGAIN && errno != EWOULDBLOCK {
            }
        }

        // Try to recognize a mouse event first
        if let mouseEvent = parseMouseSequence() {
            let event = InputEvent.mouse(mouseEvent)
            eventQueue.enqueue(event)
            return eventQueue.dequeue()
        }
        
        // Try to recognize the combination
        if let key = parseBuffer() {
            let event = InputEvent.keyPress(key)
            eventQueue.enqueue(event)
            return eventQueue.dequeue()
        }

        // Special handling for standalone ESC
        // If we have an ESC in the buffer and no more data is coming immediately,
        // treat it as a standalone ESC key. Use 0ms poll to avoid blocking the main loop
        // (blocking caused freeze when typing and cursor lag).
        if buffer == "\u{1B}" {
            var fds = [pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)]
            let result = poll(&fds, 1, 0)
            
            if result == 0 {
                // No more data available, assume standalone ESC
                buffer.removeAll()
                return .keyPress(.escape)
            }
        }

        // If it's a regular character, return immediately
        if buffer.count == 1, let first = buffer.first, let ascii = first.asciiValue, ascii >= 32 && ascii < 127 {
            let char = Character(UnicodeScalar(ascii))
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
    
    /// Reads all available mouse events and coalesces consecutive move events
    /// Returns the coalesced events - multiple moves become a single move with final position
    public func pollMouseEvents() -> [InputEvent] {
        lock.lock()
        defer { lock.unlock() }
        
        // Read all available bytes
        var readBuffer = [UInt8](repeating: 0, count: 256)
        let bytesRead = read(STDIN_FILENO, &readBuffer, 256)
        
        if bytesRead > 0 {
            for i in 0..<bytesRead {
                buffer.append(Character(UnicodeScalar(readBuffer[i])))
            }
        }
        
        // Parse all mouse events from buffer
        let mouseEvents = parseAllMouseSequences()
        
        if mouseEvents.isEmpty {
            return []
        }
        
        // Coalesce consecutive move events - keep only the last position
        var result: [InputEvent] = []
        var lastMoveEvent: InputMouseEvent? = nil
        
        for event in mouseEvents {
            if event.action == .move {
                // Coalesce: just remember the last move position
                lastMoveEvent = event
            } else {
                // Non-move event: flush any pending move first
                if let move = lastMoveEvent {
                    result.append(.mouse(move))
                    lastMoveEvent = nil
                }
                result.append(.mouse(event))
            }
        }
        
        // Don't forget the last move event
        if let move = lastMoveEvent {
            result.append(.mouse(move))
        }
        
        return result
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
    
    /// Attempts to parse an SGR mouse sequence
    private func parseMouseSequence() -> InputMouseEvent? {
        guard buffer.hasPrefix("\u{1B}[<") else {
            return nil
        }
        
        guard let terminatorIndex = buffer.firstIndex(where: { $0 == "M" || $0 == "m" }) else {
            // Wait for the rest of the sequence
            return nil
        }
        
        let nextIndex = buffer.index(after: terminatorIndex)
        let sequence = String(buffer[..<nextIndex])
        buffer.removeSubrange(buffer.startIndex..<nextIndex)
        
        return decodeSGRMouse(sequence: sequence)
    }
    
    /// Parses ALL mouse sequences from the buffer at once
    /// This is critical for coalescing mouse move events and reducing lag
    private func parseAllMouseSequences() -> [InputMouseEvent] {
        var events: [InputMouseEvent] = []
        
        while buffer.contains("\u{1B}[<") {
            guard let startIndex = buffer.range(of: "\u{1B}[<")?.lowerBound else {
                break
            }
            
            // Find terminator after the start
            let searchRange = startIndex..<buffer.endIndex
            guard let terminatorIndex = buffer[searchRange].firstIndex(where: { $0 == "M" || $0 == "m" }) else {
                // Incomplete sequence, wait for more data
                break
            }
            
            let nextIndex = buffer.index(after: terminatorIndex)
            let sequence = String(buffer[startIndex..<nextIndex])
            
            // Remove everything up to and including this sequence
            buffer.removeSubrange(buffer.startIndex..<nextIndex)
            
            if let event = decodeSGRMouse(sequence: sequence) {
                events.append(event)
            }
        }
        
        return events
    }
    
    /// Decodes CSI < ... mouse sequence (SGR mode)
    private func decodeSGRMouse(sequence: String) -> InputMouseEvent? {
        guard sequence.hasPrefix("\u{1B}[<") else {
            return nil
        }
        
        guard let finalCharacter = sequence.last, finalCharacter == "M" || finalCharacter == "m" else {
            return nil
        }
        
        let payload = sequence.dropFirst(3).dropLast()
        let parts = payload.split(separator: ";")
        guard parts.count == 3,
              let buttonCode = Int(parts[0]),
              let column = Int(parts[1]),
              let row = Int(parts[2]) else {
            return nil
        }
        
        let zeroBasedColumn = max(column - 1, 0)
        let zeroBasedRow = max(row - 1, 0)
        
        var modifiers: InputMouseEvent.Modifiers = []
        if (buttonCode & 4) != 0 { modifiers.insert(.shift) }
        if (buttonCode & 8) != 0 { modifiers.insert(.alt) }
        if (buttonCode & 16) != 0 { modifiers.insert(.control) }
        
        let isMotion = (buttonCode & 32) != 0
        let scrollFlag = (buttonCode & 64) != 0
        let baseButton = buttonCode & 0b11
        let isRelease = finalCharacter == "m" || (!scrollFlag && baseButton == 3 && !isMotion)
        
        var button: InputMouseEvent.Button = .none
        var action: InputMouseEvent.Action = .move
        
        if scrollFlag {
            button = (buttonCode & 1) == 0 ? .wheelUp : .wheelDown
            action = .scroll
        } else {
            switch baseButton {
            case 0: button = .left
            case 1: button = .middle
            case 2: button = .right
            default: button = .none
            }
            
            if isRelease {
                action = .up
            } else if isMotion {
                action = button == .none ? .move : .drag
            } else {
                action = .down
            }
        }
        
        return InputMouseEvent(
            row: zeroBasedRow,
            column: zeroBasedColumn,
            button: button,
            action: action,
            modifiers: modifiers
        )
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

    @objc
    private func handleResizeNotification(_ notification: Notification) {
        eventQueue.enqueue(.terminalResize)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: resizeNotification, object: nil)
    }
}
