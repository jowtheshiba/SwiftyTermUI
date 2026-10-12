import SwiftyTermUI

public struct THelpContext: Hashable, Sendable, ExpressibleByIntegerLiteral {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int) {
        rawValue = value
    }

    public static let none = THelpContext(rawValue: 0)
}

public struct THelpLink: Equatable, Sendable {
    public var title: String
    public var context: THelpContext

    public init(title: String, context: THelpContext) {
        self.title = title
        self.context = context
    }
}

public struct THelpTopic: Equatable, Sendable {
    public var context: THelpContext
    public var title: String
    public var text: String
    public var links: [THelpLink]

    public init(context: THelpContext, title: String, text: String, links: [THelpLink] = []) {
        self.context = context
        self.title = title
        self.text = text
        self.links = links
    }
}

@MainActor
public final class THelpSystem {
    private var topics: [THelpContext: THelpTopic] = [:]

    public init(topics: [THelpTopic] = []) {
        register(topics)
    }

    public func register(_ topic: THelpTopic) {
        topics[topic.context] = topic
    }

    public func register(_ topics: [THelpTopic]) {
        for topic in topics {
            register(topic)
        }
    }

    public func removeTopic(for context: THelpContext) {
        topics.removeValue(forKey: context)
    }

    public func topic(for context: THelpContext) -> THelpTopic? {
        topics[context]
    }

    public var allTopics: [THelpTopic] {
        topics.values.sorted { $0.context.rawValue < $1.context.rawValue }
    }
}

@MainActor
public final class THelpViewer: TDialog {
    public let helpSystem: THelpSystem
    public private(set) var currentContext: THelpContext
    public private(set) var topic: THelpTopic
    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }

    private var backStack: [THelpContext] = []
    private var forwardStack: [THelpContext] = []
    private var bodyView: TMemo!
    private var linkList: TListBox!
    private var backButton: TButton!
    private var forwardButton: TButton!
    private var closeButton: TButton!

    public init(frame: Rect, helpSystem: THelpSystem, context: THelpContext) {
        guard let topic = helpSystem.topic(for: context) else {
            preconditionFailure("Missing help topic for context \(context.rawValue)")
        }
        self.helpSystem = helpSystem
        self.currentContext = context
        self.topic = topic
        super.init(frame: frame, title: topic.title)
        setupViews()
        applyTopic()
    }

    public func navigate(to context: THelpContext) {
        guard context != currentContext, helpSystem.topic(for: context) != nil else { return }
        backStack.append(currentContext)
        forwardStack.removeAll()
        show(context)
    }

    public func goBack() {
        guard let context = backStack.popLast() else { return }
        forwardStack.append(currentContext)
        show(context)
    }

    public func goForward() {
        guard let context = forwardStack.popLast() else { return }
        backStack.append(currentContext)
        show(context)
    }

    public func followLink(at index: Int) {
        guard topic.links.indices.contains(index) else { return }
        navigate(to: topic.links[index].context)
    }

    public override func handleEvent(_ event: TEvent) {
        if case .key(let key) = event {
            switch key {
            case .backspace:
                goBack()
                return
            case .ctrl("f"):
                goForward()
                return
            default:
                break
            }
        }
        super.handleEvent(event)
    }

    private func setupViews() {
        let contentWidth = max(1, frame.width - 4)
        let bodyHeight = max(1, frame.height - 10)
        bodyView = TMemo(frame: Rect(x: 2, y: 2, width: contentWidth, height: bodyHeight), text: "")
        bodyView.isReadOnly = true
        linkList = TListBox(frame: Rect(x: 2, y: bodyHeight + 3, width: contentWidth, height: 3))
        backButton = TButton(frame: Rect(x: 2, y: frame.height - 3, width: 12, height: 1), title: "Back", action: { [weak self] in
            self?.goBack()
        })
        forwardButton = TButton(frame: Rect(x: 16, y: frame.height - 3, width: 12, height: 1), title: "Forward", action: { [weak self] in
            self?.goForward()
        })
        closeButton = TButton(frame: Rect(x: max(30, frame.width - 14), y: frame.height - 3, width: 12, height: 1), title: "Close", command: .cancel)
        backButton.actionDelayMicroseconds = 0
        forwardButton.actionDelayMicroseconds = 0
        closeButton.actionDelayMicroseconds = 0
        linkList.onSelect = { [weak self] index, _ in
            self?.followLink(at: index)
        }
        addSubview(bodyView)
        addSubview(linkList)
        addSubview(backButton)
        addSubview(forwardButton)
        addSubview(closeButton)
        RetroTextUtils.focus(view: linkList)
    }

    private func show(_ context: THelpContext) {
        guard let nextTopic = helpSystem.topic(for: context) else { return }
        currentContext = context
        topic = nextTopic
        applyTopic()
    }

    private func applyTopic() {
        title = topic.title
        bodyView.text = topic.text
        bodyView.cursorRow = 0
        bodyView.cursorColumn = 0
        bodyView.clearSelection()
        linkList.items = topic.links.map { "→ \($0.title)" }
        linkList.isVisible = !topic.links.isEmpty
        backButton.isEnabled = canGoBack
        forwardButton.isEnabled = canGoForward
        if topic.links.isEmpty {
            RetroTextUtils.focus(view: bodyView)
        } else {
            RetroTextUtils.focus(view: linkList)
        }
        owningApplication?.redraw()
    }
}
