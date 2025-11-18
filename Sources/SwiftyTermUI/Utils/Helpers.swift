import Foundation

/// Helper functions
public struct Helpers {
    
    /// Checks if coordinates are within bounds
    public static func isInBounds(row: Int, column: Int, maxRow: Int, maxColumn: Int) -> Bool {
        row >= 0 && row < maxRow && column >= 0 && column < maxColumn
    }
    
    /// Clamps value within a range
    public static func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        min(max(value, minValue), maxValue)
    }
    
    /// Calculates distance between two points
    public static func distance(fromRow: Int, fromColumn: Int, toRow: Int, toColumn: Int) -> Double {
        let dx = Double(toColumn - fromColumn)
        let dy = Double(toRow - fromRow)
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Converts HSV (Hue, Saturation, Value) to RGB
    public static func hsvToRgb(h: Double, s: Double, v: Double) -> (r: UInt8, g: UInt8, b: UInt8) {
        let c = v * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        
        var r = 0.0, g = 0.0, b = 0.0
        
        switch h {
        case 0..<60:
            (r, g, b) = (c, x, 0)
        case 60..<120:
            (r, g, b) = (x, c, 0)
        case 120..<180:
            (r, g, b) = (0, c, x)
        case 180..<240:
            (r, g, b) = (0, x, c)
        case 240..<300:
            (r, g, b) = (x, 0, c)
        default:
            (r, g, b) = (c, 0, x)
        }
        
        return (
            UInt8((r + m) * 255),
            UInt8((g + m) * 255),
            UInt8((b + m) * 255)
        )
    }
    
    /// Converts RGB to HSV
    public static func rgbToHsv(r: UInt8, g: UInt8, b: UInt8) -> (h: Double, s: Double, v: Double) {
        let rf = Double(r) / 255.0
        let gf = Double(g) / 255.0
        let bf = Double(b) / 255.0
        
        let maxC = max(rf, gf, bf)
        let minC = min(rf, gf, bf)
        let delta = maxC - minC
        
        var h = 0.0
        let s = maxC == 0 ? 0 : delta / maxC
        let v = maxC
        
        if delta != 0 {
            if maxC == rf {
                h = 60 * ((gf - bf) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == gf {
                h = 60 * ((bf - rf) / delta + 2)
            } else {
                h = 60 * ((rf - gf) / delta + 4)
            }
        }
        
        if h < 0 {
            h += 360
        }
        
        return (h, s, v)
    }
    
    /// Creates Color from RGB values
    public static func colorFromRgb(r: UInt8, g: UInt8, b: UInt8) -> Color {
        .rgb(r, g, b)
    }
    
    /// Creates Color from HEX string (e.g. "#FF5500")
    public static func colorFromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        guard hexSanitized.count == 6 else { return nil }
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = UInt8((rgb & 0xFF0000) >> 16)
        let g = UInt8((rgb & 0x00FF00) >> 8)
        let b = UInt8(rgb & 0x0000FF)
        
        return .rgb(r, g, b)
    }
    
    /// Calculates intersection area of two rectangles
    public static func intersection(
        rect1: (x: Int, y: Int, width: Int, height: Int),
        rect2: (x: Int, y: Int, width: Int, height: Int)
    ) -> (x: Int, y: Int, width: Int, height: Int)? {
        let x1 = max(rect1.x, rect2.x)
        let y1 = max(rect1.y, rect2.y)
        let x2 = min(rect1.x + rect1.width, rect2.x + rect2.width)
        let y2 = min(rect1.y + rect1.height, rect2.y + rect2.height)
        
        let width = x2 - x1
        let height = y2 - y1
        
        guard width > 0 && height > 0 else { return nil }
        
        return (x1, y1, width, height)
    }
    
    /// Checks if two rectangles overlap
    public static func rectsOverlap(
        rect1: (x: Int, y: Int, width: Int, height: Int),
        rect2: (x: Int, y: Int, width: Int, height: Int)
    ) -> Bool {
        intersection(rect1: rect1, rect2: rect2) != nil
    }
}
