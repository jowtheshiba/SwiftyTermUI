import SwiftyTermUI

/// Represents an event in the RetroVision framework
public enum TEvent {
    case key(Key)
    case mouse(MouseEvent)
    case paste(String)
    case command(Command)
    case broadcast(Broadcast)
    case nothing
    
    public struct Command: Hashable, Sendable, ExpressibleByIntegerLiteral {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public init(integerLiteral value: Int) {
            rawValue = value
        }

        public static let close = Command(rawValue: 1)
        public static let quit = Command(rawValue: 2)
        public static let submit = Command(rawValue: 3)
        public static let cancel = Command(rawValue: 4)
        public static let zoom = Command(rawValue: 5)
        public static let resize = Command(rawValue: 6)
        public static let next = Command(rawValue: 7)
        public static let previous = Command(rawValue: 8)
        public static let tile = Command(rawValue: 9)
        public static let cascade = Command(rawValue: 10)
    }

    public struct Broadcast {
        public struct Name: Hashable, Sendable, ExpressibleByStringLiteral {
            public let rawValue: String

            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(stringLiteral value: String) {
                rawValue = value
            }

            public static let viewAdded = Name(rawValue: "viewAdded")
            public static let viewRemoved = Name(rawValue: "viewRemoved")
            public static let selectionChanged = Name(rawValue: "selectionChanged")
            public static let commandSetChanged = Name(rawValue: "commandSetChanged")
        }

        public let name: Name
        public let source: TView?
        public let payload: Any?

        public init(name: Name, source: TView? = nil, payload: Any? = nil) {
            self.name = name
            self.source = source
            self.payload = payload
        }
    }

    public var mask: TEventMask {
        switch self {
        case .key: return .keyboard
        case .mouse: return .mouse
        case .paste: return .paste
        case .command: return .command
        case .broadcast: return .broadcast
        case .nothing: return []
        }
    }
    
    public struct MouseEvent: Sendable {
        public enum Button: Sendable {
            case left
            case middle
            case right
            case wheelUp
            case wheelDown
            case none
        }
        
        public enum Action: Sendable {
            case down
            case up
            case drag
            case move
            case scroll
        }
        
        public struct Modifiers: OptionSet, Sendable {
            public let rawValue: Int
            
            public init(rawValue: Int) {
                self.rawValue = rawValue
            }
            
            public static let shift = Modifiers(rawValue: 1 << 0)
            public static let alt = Modifiers(rawValue: 1 << 1)
            public static let control = Modifiers(rawValue: 1 << 2)
        }
        
        public var position: Point
        public let button: Button
        public let action: Action
        public var clickCount: Int
        public let modifiers: Modifiers
        
        public init(position: Point, button: Button, action: Action, clickCount: Int = 1, modifiers: Modifiers = []) {
            self.position = position
            self.button = button
            self.action = action
            self.clickCount = clickCount
            self.modifiers = modifiers
        }
        
        public func with(position: Point) -> MouseEvent {
            MouseEvent(position: position, button: button, action: action, clickCount: clickCount, modifiers: modifiers)
        }
    }
}
