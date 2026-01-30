import SwiftyTermUI

enum RetroTextUtils {
    static func resolvedContentColors(for view: TView) -> (fg: Color, bg: Color) {
        var current: TView? = view
        while let node = current {
            if let window = node as? TWindow {
                switch window.style {
                case .window:
                    return (.white, .blue)
                case .dialog:
                    return (.black, .white)
                }
            }
            current = node.superview
        }
        return (.black, .white)
    }
    
    static func clampText(_ text: String, maxWidth: Int) -> String {
        guard maxWidth > 0 else { return "" }
        if text.count <= maxWidth {
            return text
        }
        return String(text.prefix(maxWidth))
    }
    
    static func wrapText(_ text: String, maxWidth: Int, maxLines: Int) -> [String] {
        guard maxWidth > 0, maxLines > 0 else { return [] }
        
        var lines: [String] = []
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false)
        
        for paragraphSub in paragraphs {
            if lines.count >= maxLines { break }
            let paragraph = String(paragraphSub)
            if paragraph.isEmpty {
                lines.append("")
                continue
            }
            
            let words = paragraph.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if words.isEmpty {
                lines.append("")
                continue
            }
            
            var current = ""
            for wordSub in words {
                if lines.count >= maxLines { break }
                let word = String(wordSub)
                if word.count > maxWidth {
                    if !current.isEmpty {
                        lines.append(current)
                        current = ""
                        if lines.count >= maxLines { break }
                    }
                    var idx = word.startIndex
                    while idx < word.endIndex && lines.count < maxLines {
                        let end = word.index(idx, offsetBy: maxWidth, limitedBy: word.endIndex) ?? word.endIndex
                        lines.append(String(word[idx..<end]))
                        idx = end
                    }
                    continue
                }
                
                if current.isEmpty {
                    current = word
                } else if current.count + 1 + word.count <= maxWidth {
                    current += " " + word
                } else {
                    lines.append(current)
                    current = word
                }
            }
            
            if lines.count >= maxLines { break }
            if !current.isEmpty {
                lines.append(current)
            }
        }
        
        return lines
    }
    
    static func parseHotKey(_ text: String) -> (displayText: String, hotKey: Character?, underlineIndex: Int?) {
        var display = ""
        var hotKey: Character?
        var underlineIndex: Int?
        
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if ch == "~" {
                if i + 1 < chars.count {
                    let next = chars[i + 1]
                    if next == "~" {
                        display.append("~")
                        i += 2
                        continue
                    }
                    if hotKey == nil {
                        hotKey = String(next).lowercased().first
                        underlineIndex = display.count
                    }
                    display.append(next)
                    i += 2
                    continue
                }
                i += 1
                continue
            }
            
            display.append(ch)
            i += 1
        }
        
        return (display, hotKey, underlineIndex)
    }
    
    @MainActor
    static func focus(view: TView) {
        if let container = view.superview {
            for item in container.subviews {
                item.isFocused = (item === view)
            }
        } else {
            view.isFocused = true
        }
    }
}
