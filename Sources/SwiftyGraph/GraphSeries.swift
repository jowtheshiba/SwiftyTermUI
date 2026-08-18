import SwiftyTermUI

/// A named sequence of values to plot, together with its display color.
public struct GraphSeries: Sendable {
    public var name: String
    public var values: [Double]
    public var color: Color

    public init(name: String, values: [Double], color: Color = .brightCyan) {
        self.name = name
        self.values = values
        self.color = color
    }
}

/// A single (x, y) data point for a scatter chart.
public struct GraphPoint: Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A named collection of (x, y) points to plot, together with its display color.
public struct ScatterSeries: Sendable {
    public var name: String
    public var points: [GraphPoint]
    public var color: Color

    public init(name: String, points: [GraphPoint], color: Color = .brightCyan) {
        self.name = name
        self.points = points
        self.color = color
    }
}

/// A small set of vibrant colors for coloring multiple series without
/// having to pick RGB values by hand.
public enum GraphPalette {
    public static let colors: [Color] = [
        .rgb(90, 200, 250),
        .rgb(255, 105, 180),
        .rgb(255, 214, 10),
        .rgb(100, 220, 120),
        .rgb(191, 90, 242),
        .rgb(255, 140, 0),
    ]

    public static func color(at index: Int) -> Color {
        colors[index % colors.count]
    }
}
