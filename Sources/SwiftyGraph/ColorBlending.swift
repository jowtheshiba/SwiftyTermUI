import SwiftyTermUI

func rgbComponents(of color: Color) -> (Double, Double, Double) {
    switch color {
    case let .rgb(r, g, b): return (Double(r), Double(g), Double(b))
    case .black: return (0, 0, 0)
    case .red: return (205, 0, 0)
    case .green: return (0, 205, 0)
    case .yellow: return (205, 205, 0)
    case .blue: return (0, 0, 238)
    case .magenta: return (205, 0, 205)
    case .cyan: return (0, 205, 205)
    case .white: return (229, 229, 229)
    case .brightBlack: return (127, 127, 127)
    case .brightRed: return (255, 0, 0)
    case .brightGreen: return (0, 255, 0)
    case .brightYellow: return (255, 255, 0)
    case .brightBlue: return (92, 92, 255)
    case .brightMagenta: return (255, 0, 255)
    case .brightCyan: return (0, 255, 255)
    case .brightWhite: return (255, 255, 255)
    case .indexed, .default: return (128, 128, 128)
    }
}

func interpolateColor(_ from: Color, _ to: Color, t: Double) -> Color {
    let clampedT = t.clamped(to: 0...1)
    let (r0, g0, b0) = rgbComponents(of: from)
    let (r1, g1, b1) = rgbComponents(of: to)
    let r = UInt8((r0 + (r1 - r0) * clampedT).rounded().clamped(to: 0...255))
    let g = UInt8((g0 + (g1 - g0) * clampedT).rounded().clamped(to: 0...255))
    let b = UInt8((b0 + (b1 - b0) * clampedT).rounded().clamped(to: 0...255))
    return .rgb(r, g, b)
}

/// Lightens (positive factor) or darkens (negative factor) a color by
/// adjusting its HSV value while keeping hue mostly intact, rather than
/// blending the raw RGB toward white/black — which desaturates strongly
/// tinted colors (a green, say) into a washed-out mint or muddy near-black.
/// Used to fake lit/shaded faces on pseudo-3D shapes.
func shaded(_ color: Color, by factor: Double) -> Color {
    let clampedFactor = factor.clamped(to: -1...1)
    let (r, g, b) = rgbComponents(of: color)
    let (h, s, v) = Helpers.rgbToHsv(
        r: UInt8(r.clamped(to: 0...255)),
        g: UInt8(g.clamped(to: 0...255)),
        b: UInt8(b.clamped(to: 0...255))
    )

    let newValue: Double
    let newSaturation: Double
    if clampedFactor >= 0 {
        // Highlight: brighter and a touch less saturated.
        newValue = (v + (1 - v) * clampedFactor).clamped(to: 0...1)
        newSaturation = (s * (1 - clampedFactor * 0.35)).clamped(to: 0...1)
    } else {
        // Shadow: darker, saturation preserved (shadows read as muddy when desaturated).
        newValue = (v * (1 + clampedFactor)).clamped(to: 0...1)
        newSaturation = s
    }

    let (nr, ng, nb) = Helpers.hsvToRgb(h: h, s: newSaturation, v: newValue)
    return .rgb(nr, ng, nb)
}
