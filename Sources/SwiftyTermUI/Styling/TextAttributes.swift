import Foundation

/// Атрибути для тексту
public struct TextAttributes: Equatable, OptionSet, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let bold = TextAttributes(rawValue: 1 << 0)
    public static let italic = TextAttributes(rawValue: 1 << 1)
    public static let underline = TextAttributes(rawValue: 1 << 2)
    public static let blink = TextAttributes(rawValue: 1 << 3)
    public static let reverse = TextAttributes(rawValue: 1 << 4)
    public static let dim = TextAttributes(rawValue: 1 << 5)
    
    public var bold: Bool {
        contains(.bold)
    }
    
    public var italic: Bool {
        contains(.italic)
    }
    
    public var underline: Bool {
        contains(.underline)
    }
    
    public var blink: Bool {
        contains(.blink)
    }
    
    public var reverse: Bool {
        contains(.reverse)
    }
    
    public var dim: Bool {
        contains(.dim)
    }
    
    public func toAnsiCodes() -> String {
        var codes = [String]()
        
        if contains(.bold) {
            codes.append("\u{1B}[1m")
        }
        if contains(.italic) {
            codes.append("\u{1B}[3m")
        }
        if contains(.underline) {
            codes.append("\u{1B}[4m")
        }
        if contains(.blink) {
            codes.append("\u{1B}[5m")
        }
        if contains(.reverse) {
            codes.append("\u{1B}[7m")
        }
        if contains(.dim) {
            codes.append("\u{1B}[2m")
        }
        
        return codes.joined()
    }
}
