import Foundation

public indirect enum TViewData: Equatable, Sendable {
    case text(String)
    case boolean(Bool)
    case integer(Int)
    case strings([String])
    case group([TViewData])
}

public struct TViewState: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let visible = TViewState(rawValue: 1 << 0)
    public static let active = TViewState(rawValue: 1 << 1)
    public static let selected = TViewState(rawValue: 1 << 2)
    public static let focused = TViewState(rawValue: 1 << 3)
    public static let disabled = TViewState(rawValue: 1 << 4)
    public static let modal = TViewState(rawValue: 1 << 5)
    public static let dragging = TViewState(rawValue: 1 << 6)
    public static let exposed = TViewState(rawValue: 1 << 7)
}

public struct TViewOptions: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let selectable = TViewOptions(rawValue: 1 << 0)
    public static let topSelect = TViewOptions(rawValue: 1 << 1)
    public static let firstClick = TViewOptions(rawValue: 1 << 2)
    public static let framed = TViewOptions(rawValue: 1 << 3)
    public static let preProcess = TViewOptions(rawValue: 1 << 4)
    public static let postProcess = TViewOptions(rawValue: 1 << 5)
    public static let centered = TViewOptions(rawValue: 1 << 6)
    public static let validate = TViewOptions(rawValue: 1 << 7)
}

public struct TGrowMode: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let lowX = TGrowMode(rawValue: 1 << 0)
    public static let lowY = TGrowMode(rawValue: 1 << 1)
    public static let highX = TGrowMode(rawValue: 1 << 2)
    public static let highY = TGrowMode(rawValue: 1 << 3)
    public static let relative = TGrowMode(rawValue: 1 << 4)
    public static let growLoX = lowX
    public static let growLoY = lowY
    public static let growHiX = highX
    public static let growHiY = highY
    public static let growRel = relative
}

public struct TEventMask: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let keyboard = TEventMask(rawValue: 1 << 0)
    public static let mouse = TEventMask(rawValue: 1 << 1)
    public static let paste = TEventMask(rawValue: 1 << 2)
    public static let command = TEventMask(rawValue: 1 << 3)
    public static let broadcast = TEventMask(rawValue: 1 << 4)
    public static let all: TEventMask = [.keyboard, .mouse, .paste, .command, .broadcast]
}

public struct TCommandSet: Sendable {
    private var storage: Set<TEvent.Command>

    public init(_ commands: Set<TEvent.Command> = []) {
        storage = commands
    }

    public mutating func insert(_ command: TEvent.Command) {
        storage.insert(command)
    }

    public mutating func remove(_ command: TEvent.Command) {
        storage.remove(command)
    }

    public func contains(_ command: TEvent.Command) -> Bool {
        storage.contains(command)
    }
}
