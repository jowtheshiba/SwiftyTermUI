import SwiftyTermUI

/// Represents an event in the RetroVision framework
public enum TEvent {
    case key(Key)
    case mouse(MouseEvent) // Placeholder for future mouse support
    case command(Command)
    case nothing
    
    public enum Command {
        case close
        case quit
        case submit
        case cancel
    }
    
    public struct MouseEvent {
        public let x: Int
        public let y: Int
        public let action: Action
        
        public enum Action {
            case click
            case doubleClick
            case move
        }
    }
}
