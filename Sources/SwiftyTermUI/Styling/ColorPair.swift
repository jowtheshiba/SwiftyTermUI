import Foundation

/// Color pair for foreground and background
public struct ColorPair: Equatable {
    public let foreground: Color
    public let background: Color
    
    public init(foreground: Color = .default, background: Color = .default) {
        self.foreground = foreground
        self.background = background
    }
    
    public func toAnsiCodes() -> String {
        foreground.ansiCode + background.backgroundAnsiCode
    }
    
    public static func basic(_ fg: Color, _ bg: Color = .default) -> ColorPair {
        ColorPair(foreground: fg, background: bg)
    }
}
