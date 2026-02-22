import Darwin
import Foundation

/// Types of events that can occur
public enum InputEvent: Equatable {
    case keyPress(Key)
    case mouse(InputMouseEvent)
    case paste(String)
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
    
    // MARK: - Modifiers for Selection and Clipboard
    case shiftUp
    case shiftDown
    case shiftLeft
    case shiftRight
    case shiftDelete
    case shiftInsert
    case ctrlInsert

    // MARK: - Function keys

    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
    case shiftF10

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
    private var isBracketedPaste = false
    private var pasteBuffer = ""
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

        // Try to read available bytes from stdin (read up to 4096 bytes to capture full mouse sequences and pastes)
        var readBuffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(STDIN_FILENO, &readBuffer, 4096)

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
        
        // Handle Bracketed Paste Mode
        if !isBracketedPaste && buffer.hasPrefix("\u{1B}[200~") {
            isBracketedPaste = true
            buffer.removeFirst(6)
        }
        
        if isBracketedPaste {
            if let endRange = buffer.range(of: "\u{1B}[201~") {
                pasteBuffer += String(buffer[..<endRange.lowerBound])
                buffer.removeSubrange(..<endRange.upperBound)
                isBracketedPaste = false
                
                let textBytes = pasteBuffer.unicodeScalars.compactMap { $0.value <= 0xFF ? UInt8($0.value) : nil }
                let text = String(decoding: textBytes, as: UTF8.self)
                
                pasteBuffer = ""
                eventQueue.enqueue(.paste(text))
                return eventQueue.dequeue()
            } else {
                if let lastEsc = buffer.lastIndex(of: "\u{1B}") {
                    pasteBuffer += String(buffer[..<lastEsc])
                    buffer.removeSubrange(..<lastEsc)
                } else {
                    pasteBuffer += buffer
                    buffer.removeAll()
                }
                return nil
            }
        }

        // Try to recognize mouse events first (coalesce move events)
        let mouseEvents = parseAllMouseSequences()
        if !mouseEvents.isEmpty {
            let coalesced = coalesceMouseEvents(mouseEvents)
            for event in coalesced {
                eventQueue.enqueue(.mouse(event))
            }
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

        // If it's a regular character (including UTF-8), return immediately
        if !buffer.hasPrefix("\u{1B}"), let ch = decodeUtf8CharFromBuffer() {
            return .keyPress(.character(ch))
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
        
        return coalesceMouseEvents(mouseEvents).map { .mouse($0) }
    }
    
    /// Clears the event queue
    public func clearEvents() {
        eventQueue.clear()
    }

    /// Coalesces consecutive move events - keep only the last position
    private func coalesceMouseEvents(_ mouseEvents: [InputMouseEvent]) -> [InputMouseEvent] {
        var result: [InputMouseEvent] = []
        var lastMoveEvent: InputMouseEvent? = nil
        
        for event in mouseEvents {
            if event.action == .move {
                lastMoveEvent = event
            } else {
                if let move = lastMoveEvent {
                    result.append(move)
                    lastMoveEvent = nil
                }
                result.append(event)
            }
        }
        
        if let move = lastMoveEvent {
            result.append(move)
        }
        
        return result
    }

    private let escapeSequences: [(String, Key)] = [
        ("\u{1B}[A", .up),
        ("\u{1B}[B", .down),
        ("\u{1B}[C", .right),
        ("\u{1B}[D", .left),
        ("\u{1B}[H", .home),
        ("\u{1B}[1~", .home),
        ("\u{1B}OH", .home),
        ("\u{1B}[F", .end),
        ("\u{1B}[4~", .end),
        ("\u{1B}OF", .end),
        ("\u{1B}[2~", .insert),
        ("\u{1B}[3~", .delete),
        ("\u{1B}[5~", .pageUp),
        ("\u{1B}[6~", .pageDown),
        ("\u{1B}[1;2A", .shiftUp),
        ("\u{1B}[1;2B", .shiftDown),
        ("\u{1B}[1;2C", .shiftRight),
        ("\u{1B}[1;2D", .shiftLeft),
        ("\u{1B}[3;2~", .shiftDelete),
        ("\u{1B}[2;2~", .shiftInsert),
        ("\u{1B}[2;5~", .ctrlInsert),
        ("\u{1B}OP", .f1),
        ("\u{1B}OQ", .f2),
        ("\u{1B}OR", .f3),
        ("\u{1B}OS", .f4),
        ("\u{1B}[11~", .f1),
        ("\u{1B}[12~", .f2),
        ("\u{1B}[13~", .f3),
        ("\u{1B}[14~", .f4),
        ("\u{1B}[15~", .f5),
        ("\u{1B}[17~", .f6),
        ("\u{1B}[18~", .f7),
        ("\u{1B}[19~", .f8),
        ("\u{1B}[20~", .f9),
        ("\u{1B}[21;2~", .shiftF10),
        ("\u{1B}[21~", .f10),
        ("\u{1B}[23~", .f11),
        ("\u{1B}[24~", .f12)
    ]

    /// Parses ANSI escape sequences
    private func parseBuffer() -> Key? {
        // Enter
        if buffer.hasPrefix("\r") || buffer.hasPrefix("\n") {
            buffer.removeFirst()
            return .enter
        }

        // Backspace
        if buffer.hasPrefix("\u{7F}") || buffer.hasPrefix("\u{08}") {
            buffer.removeFirst()
            return .backspace
        }

        // Tab
        if buffer.hasPrefix("\t") {
            buffer.removeFirst()
            return .tab
        }
        
        // Control keys (Ctrl+A-Z = 1-26)
        if let first = buffer.first {
            let scalar = first.unicodeScalars.first?.value ?? 0
            if scalar >= 1 && scalar <= 26 {
                buffer.removeFirst()
                let char = Character(UnicodeScalar(scalar + 96)!)
                return .ctrl(char)
            }
        }

        // ANSI escape sequences
        if buffer.hasPrefix("\u{1B}[") || buffer.hasPrefix("\u{1B}O") {
            return parseEscapeSequence()
        }
        
        // Alt + character (ESC followed by a character)
        if buffer.count >= 2 && buffer.hasPrefix("\u{1B}") {
            let char = buffer[buffer.index(buffer.startIndex, offsetBy: 1)]
            buffer.removeFirst(2)
            return .alt(char)
        }
        
        // Plain ESC
        if buffer == "\u{1B}" {
            // Wait for more characters for escape sequences
            return nil
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
    
    /// Decodes the first UTF-8 character from buffer, if complete
    private func decodeUtf8CharFromBuffer() -> Character? {
        let scalars = buffer.unicodeScalars
        guard !scalars.isEmpty else { return nil }
        
        var bytes: [UInt8] = []
        bytes.reserveCapacity(scalars.count)
        for scalar in scalars {
            let value = scalar.value
            guard value <= 0xFF else { return nil }
            bytes.append(UInt8(value))
        }
        
        let first = bytes[0]
        let expectedLength: Int
        if first <= 0x7F {
            expectedLength = 1
        } else if first >= 0xC2 && first <= 0xDF {
            expectedLength = 2
        } else if first >= 0xE0 && first <= 0xEF {
            expectedLength = 3
        } else if first >= 0xF0 && first <= 0xF4 {
            expectedLength = 4
        } else {
            removeBytesFromBuffer(count: 1)
            return nil
        }
        
        if bytes.count < expectedLength {
            return nil
        }
        
        if expectedLength > 1 {
            for i in 1..<expectedLength {
                if bytes[i] < 0x80 || bytes[i] > 0xBF {
                    removeBytesFromBuffer(count: 1)
                    return nil
                }
            }
        }
        
        let slice = bytes[0..<expectedLength]
        let string = String(decoding: slice, as: UTF8.self)
        guard let ch = string.first else { return nil }
        removeBytesFromBuffer(count: expectedLength)
        return ch
    }
    
    private func removeBytesFromBuffer(count: Int) {
        let scalars = buffer.unicodeScalars
        guard count > 0, scalars.count >= count else { return }
        let endIndex = scalars.index(scalars.startIndex, offsetBy: count)
        buffer.removeSubrange(scalars.startIndex..<endIndex)
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
        for (prefix, key) in escapeSequences {
            if buffer.hasPrefix(prefix) {
                buffer.removeFirst(prefix.count)
                return key
            }
        }

        // If it's an incomplete escape sequence, wait for more characters
        if buffer.count < 6 {
            return nil
        }

        // Unknown combination
        buffer.removeFirst()
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
