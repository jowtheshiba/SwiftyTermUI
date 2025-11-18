import Foundation

/// Utilities for text formatting
public struct TextUtils {
    
    /// Truncates text to a specified width
    public static func truncate(_ text: String, to width: Int, suffix: String = "...") -> String {
        if text.count <= width {
            return text
        }
        
        let maxLength = max(0, width - suffix.count)
        return String(text.prefix(maxLength)) + suffix
    }
    
    /// Wraps text into multiple lines according to maximum width
    public static func wrap(_ text: String, width: Int) -> [String] {
        guard width > 0 else { return [] }
        
        var lines: [String] = []
        var currentLine = ""
        
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        
        for word in words {
            let wordStr = String(word)
            
            // If word is longer than width, split it
            if wordStr.count > width {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                    currentLine = ""
                }
                
                var remaining = wordStr
                while remaining.count > width {
                    lines.append(String(remaining.prefix(width)))
                    remaining = String(remaining.dropFirst(width))
                }
                currentLine = remaining
                continue
            }
            
            let testLine = currentLine.isEmpty ? wordStr : currentLine + " " + wordStr
            
            if testLine.count <= width {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = wordStr
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.isEmpty ? [""] : lines
    }
    
    /// Adds padding on the left
    public static func padLeft(_ text: String, to width: Int, with char: Character = " ") -> String {
        let padding = max(0, width - text.count)
        return String(repeating: char, count: padding) + text
    }
    
    /// Adds padding on the right
    public static func padRight(_ text: String, to width: Int, with char: Character = " ") -> String {
        let padding = max(0, width - text.count)
        return text + String(repeating: char, count: padding)
    }
    
    /// Adds padding on both sides (centering)
    public static func padCenter(_ text: String, to width: Int, with char: Character = " ") -> String {
        let totalPadding = max(0, width - text.count)
        let leftPadding = totalPadding / 2
        let rightPadding = totalPadding - leftPadding
        
        return String(repeating: char, count: leftPadding) + text + String(repeating: char, count: rightPadding)
    }
    
    /// Splits text into lines taking into account newline characters
    public static func splitLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
    }
    
    /// Removes ANSI escape codes from text
    public static func stripAnsiCodes(_ text: String) -> String {
        let pattern = "\\x1B\\[[0-9;]*[a-zA-Z]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
    
    /// Calculates visual length of text (without ANSI codes)
    public static func visualLength(_ text: String) -> Int {
        stripAnsiCodes(text).count
    }
}
