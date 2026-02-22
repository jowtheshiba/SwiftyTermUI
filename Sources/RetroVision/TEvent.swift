import SwiftyTermUI

/// Represents an event in the RetroVision framework
public enum TEvent {
    case key(Key)
    case mouse(MouseEvent)
    case paste(String)
    case command(Command)
    case nothing
    
    public enum Command {
        case close
        case quit
        case submit
        case cancel
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
