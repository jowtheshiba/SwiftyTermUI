import SwiftyTermUI

/// A foreground/background color pair for a UI role
public struct TColorPair: Equatable, Sendable {
    public var fg: Color
    public var bg: Color

    public init(fg: Color, bg: Color) {
        self.fg = fg
        self.bg = bg
    }
}

/// Central color palette for all RetroVision widgets.
/// Replace `TTheme.current` (or individual roles) to recolor the application;
/// widgets read the theme on every draw.
public struct TTheme: Sendable {
    // MARK: - Desktop
    public var desktopFill = TColorPair(fg: .black, bg: .white)
    public var mouseCursor = TColorPair(fg: .black, bg: .brightWhite)
    /// Shadow cast by windows, buttons, and menus
    public var shadowColor: Color = .black

    // MARK: - Windows
    public var windowFrame = TColorPair(fg: .white, bg: .blue)
    public var windowContent = TColorPair(fg: .white, bg: .blue)
    public var dialogFrame = TColorPair(fg: .brightWhite, bg: .white)
    public var dialogContent = TColorPair(fg: .black, bg: .white)
    /// Border color while a window is dragged or resized
    public var frameHighlight: Color = .brightGreen
    public var closeButton: Color = .green

    // MARK: - Menus
    public var menuBar = TColorPair(fg: .black, bg: .white)
    public var menuBarSelected = TColorPair(fg: .white, bg: .black)
    public var menuItem = TColorPair(fg: .black, bg: .white)
    public var menuItemSelected = TColorPair(fg: .brightWhite, bg: .green)

    // MARK: - Status line
    public var statusLine = TColorPair(fg: .white, bg: .blue)
    public var statusKey: Color = .brightWhite

    // MARK: - Controls
    public var button = TColorPair(fg: .black, bg: .green)
    public var buttonFocusedText: Color = .brightWhite
    /// Checkbox/radio marks and list box background
    public var control = TColorPair(fg: .black, bg: .indexed(30))
    public var listSelection = TColorPair(fg: .brightWhite, bg: .green)
    public var inputLine = TColorPair(fg: .white, bg: .blue)
    /// Selected text in input lines and memos
    public var inputSelection = TColorPair(fg: .black, bg: .white)
    public var inputCursor: Color = .brightWhite
    public var tabActive = TColorPair(fg: .brightWhite, bg: .blue)

    public init() {}

    /// The active theme, read by all widgets when drawing
    @MainActor
    public static var current = TTheme()
}
