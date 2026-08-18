import Foundation

/// Formats an axis value compactly: whole numbers without a decimal point,
/// everything else trimmed to two significant fractional digits.
func formatAxisValue(_ value: Double) -> String {
    if value.rounded() == value, abs(value) < 1_000_000 {
        return String(Int(value))
    }
    return String(format: "%.2f", value)
}
