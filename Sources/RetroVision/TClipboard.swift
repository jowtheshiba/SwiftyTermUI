import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
public struct TClipboard {
    private static var _text: String = ""
    
    public static var text: String {
        get {
            #if canImport(AppKit)
            return NSPasteboard.general.string(forType: .string) ?? _text
            #else
            return _text
            #endif
        }
        set {
            _text = newValue
            #if canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(newValue, forType: .string)
            #endif
        }
    }
}

public struct TextPosition: Equatable, Comparable {
    public var row: Int
    public var column: Int
    
    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
    
    public static func < (lhs: TextPosition, rhs: TextPosition) -> Bool {
        if lhs.row != rhs.row { return lhs.row < rhs.row }
        return lhs.column < rhs.column
    }
}
