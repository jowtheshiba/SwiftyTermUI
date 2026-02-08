import Foundation

/// Color for terminal (supports 8, 16, 256 colors and RGB)
public enum Color: Equatable, Hashable, Sendable {
    // MARK: - Basic 8 colors

    case black
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white

    // MARK: - Bright variants

    case brightBlack
    case brightRed
    case brightGreen
    case brightYellow
    case brightBlue
    case brightMagenta
    case brightCyan
    case brightWhite

    // MARK: - Extended palette

    case indexed(UInt8) // 256-color palette (0-255)
    case rgb(UInt8, UInt8, UInt8) // RGB (will be converted to nearest indexed)

    // MARK: - Default

    case `default`

    // MARK: - ANSI Code Generation

    var ansiCode: String {
        switch self {
        case .black:
            return "\u{1B}[30m"
        case .red:
            return "\u{1B}[31m"
        case .green:
            return "\u{1B}[32m"
        case .yellow:
            return "\u{1B}[33m"
        case .blue:
            return "\u{1B}[34m"
        case .magenta:
            return "\u{1B}[35m"
        case .cyan:
            return "\u{1B}[36m"
        case .white:
            return "\u{1B}[37m"
        case .brightBlack:
            return "\u{1B}[90m"
        case .brightRed:
            return "\u{1B}[91m"
        case .brightGreen:
            return "\u{1B}[92m"
        case .brightYellow:
            return "\u{1B}[93m"
        case .brightBlue:
            return "\u{1B}[94m"
        case .brightMagenta:
            return "\u{1B}[95m"
        case .brightCyan:
            return "\u{1B}[96m"
        case .brightWhite:
            return "\u{1B}[97m"
        case let .indexed(index):
            return "\u{1B}[38;5;\(index)m"
        case let .rgb(r, g, b):
            let index = Self.rgbToIndex(r: r, g: g, b: b)
            return "\u{1B}[38;5;\(index)m"
        case .default:
            return "\u{1B}[39m"
        }
    }

    var backgroundAnsiCode: String {
        switch self {
        case .black:
            return "\u{1B}[40m"
        case .red:
            return "\u{1B}[41m"
        case .green:
            return "\u{1B}[42m"
        case .yellow:
            return "\u{1B}[43m"
        case .blue:
            return "\u{1B}[44m"
        case .magenta:
            return "\u{1B}[45m"
        case .cyan:
            return "\u{1B}[46m"
        case .white:
            return "\u{1B}[47m"
        case .brightBlack:
            return "\u{1B}[100m"
        case .brightRed:
            return "\u{1B}[101m"
        case .brightGreen:
            return "\u{1B}[102m"
        case .brightYellow:
            return "\u{1B}[103m"
        case .brightBlue:
            return "\u{1B}[104m"
        case .brightMagenta:
            return "\u{1B}[105m"
        case .brightCyan:
            return "\u{1B}[106m"
        case .brightWhite:
            return "\u{1B}[107m"
        case let .indexed(index):
            return "\u{1B}[48;5;\(index)m"
        case let .rgb(r, g, b):
            let index = Self.rgbToIndex(r: r, g: g, b: b)
            return "\u{1B}[48;5;\(index)m"
        case .default:
            return "\u{1B}[49m"
        }
    }
    
    private static func rgbToIndex(r: UInt8, g: UInt8, b: UInt8) -> UInt8 {
        let r6 = UInt8((Double(r) / 255.0 * 5.0).rounded())
        let g6 = UInt8((Double(g) / 255.0 * 5.0).rounded())
        let b6 = UInt8((Double(b) / 255.0 * 5.0).rounded())
        return 16 + 36 * r6 + 6 * g6 + b6
    }
}
