import SwiftyTermUI

@MainActor
public final class TFindDialog: TDialog {
    public let queryInput: TInputLine
    public let optionsControl: TCheckBoxes

    public var query: String { queryInput.text }
    public var searchOptions: TEditorSearchOptions {
        Self.searchOptions(from: optionsControl.value)
    }

    public init(
        query: String = "",
        options: TEditorSearchOptions = [],
        frame: Rect = Rect(x: 12, y: 5, width: 56, height: 12)
    ) {
        queryInput = TInputLine(frame: Rect(x: 15, y: 2, width: 36, height: 1), text: query)
        optionsControl = TCheckBoxes(
            frame: Rect(x: 4, y: 4, width: 28, height: 3),
            items: [
                TClusterItem("~C~ase sensitive"),
                TClusterItem("~W~hole words"),
                TClusterItem("~B~ackwards")
            ],
            value: Self.controlValue(from: options)
        )
        super.init(frame: frame, title: "Find")

        let label = TLabel(
            frame: Rect(x: 3, y: 2, width: 12, height: 1),
            text: "~F~ind text:",
            target: queryInput
        )
        let findButton = TButton(
            frame: Rect(x: 13, y: 8, width: 12, height: 1),
            title: "Find",
            command: .ok
        )
        findButton.isDefault = true
        findButton.actionDelayMicroseconds = 0
        let cancelButton = TButton(
            frame: Rect(x: 31, y: 8, width: 12, height: 1),
            title: "Cancel",
            command: .cancel
        )
        cancelButton.actionDelayMicroseconds = 0

        addSubview(label)
        addSubview(queryInput)
        addSubview(optionsControl)
        addSubview(findButton)
        addSubview(cancelButton)
    }

    public override func valid(_ command: TEvent.Command) -> Bool {
        if command == .ok {
            return !query.isEmpty
        }
        return super.valid(command)
    }

    private static func controlValue(from options: TEditorSearchOptions) -> Int {
        var value = 0
        if options.contains(.caseSensitive) { value |= 1 << 0 }
        if options.contains(.wholeWords) { value |= 1 << 1 }
        if options.contains(.backwards) { value |= 1 << 2 }
        return value
    }

    private static func searchOptions(from value: Int) -> TEditorSearchOptions {
        var options: TEditorSearchOptions = []
        if value & (1 << 0) != 0 { options.insert(.caseSensitive) }
        if value & (1 << 1) != 0 { options.insert(.wholeWords) }
        if value & (1 << 2) != 0 { options.insert(.backwards) }
        return options
    }
}

@MainActor
public final class TReplaceDialog: TDialog {
    public let queryInput: TInputLine
    public let replacementInput: TInputLine
    public let optionsControl: TCheckBoxes
    public var onFindNext: ((String, TEditorSearchOptions) -> Void)?
    public var onReplace: ((String, String, TEditorSearchOptions) -> Void)?
    public var onReplaceAll: ((String, String, TEditorSearchOptions) -> Void)?

    public var query: String { queryInput.text }
    public var replacement: String { replacementInput.text }
    public var searchOptions: TEditorSearchOptions {
        var options: TEditorSearchOptions = []
        if optionsControl.value & (1 << 0) != 0 { options.insert(.caseSensitive) }
        if optionsControl.value & (1 << 1) != 0 { options.insert(.wholeWords) }
        if optionsControl.value & (1 << 2) != 0 { options.insert(.backwards) }
        return options
    }

    public init(
        query: String = "",
        replacement: String = "",
        options: TEditorSearchOptions = [],
        frame: Rect = Rect(x: 10, y: 3, width: 60, height: 16)
    ) {
        queryInput = TInputLine(frame: Rect(x: 17, y: 2, width: 37, height: 1), text: query)
        replacementInput = TInputLine(frame: Rect(x: 17, y: 4, width: 37, height: 1), text: replacement)
        var controlValue = 0
        if options.contains(.caseSensitive) { controlValue |= 1 << 0 }
        if options.contains(.wholeWords) { controlValue |= 1 << 1 }
        if options.contains(.backwards) { controlValue |= 1 << 2 }
        optionsControl = TCheckBoxes(
            frame: Rect(x: 4, y: 6, width: 28, height: 3),
            items: [
                TClusterItem("~C~ase sensitive"),
                TClusterItem("~W~hole words"),
                TClusterItem("~B~ackwards")
            ],
            value: controlValue
        )
        super.init(frame: frame, title: "Replace")

        let queryLabel = TLabel(
            frame: Rect(x: 3, y: 2, width: 14, height: 1),
            text: "~F~ind text:",
            target: queryInput
        )
        let replacementLabel = TLabel(
            frame: Rect(x: 3, y: 4, width: 14, height: 1),
            text: "~R~eplace with:",
            target: replacementInput
        )
        let findButton = TButton(frame: Rect(x: 3, y: 11, width: 12, height: 1), title: "Find Next")
        findButton.isDefault = true
        findButton.actionDelayMicroseconds = 0
        let replaceButton = TButton(frame: Rect(x: 17, y: 11, width: 12, height: 1), title: "Replace")
        replaceButton.actionDelayMicroseconds = 0
        let allButton = TButton(frame: Rect(x: 31, y: 11, width: 12, height: 1), title: "All")
        allButton.actionDelayMicroseconds = 0
        let cancelButton = TButton(
            frame: Rect(x: 45, y: 11, width: 12, height: 1),
            title: "Cancel",
            command: .cancel
        )
        cancelButton.actionDelayMicroseconds = 0

        findButton.action = { [weak self] in
            guard let self, !query.isEmpty else { return }
            onFindNext?(query, searchOptions)
        }
        replaceButton.action = { [weak self] in
            guard let self, !query.isEmpty else { return }
            onReplace?(query, replacement, searchOptions)
        }
        allButton.action = { [weak self] in
            guard let self, !query.isEmpty else { return }
            onReplaceAll?(query, replacement, searchOptions)
        }

        addSubview(queryLabel)
        addSubview(queryInput)
        addSubview(replacementLabel)
        addSubview(replacementInput)
        addSubview(optionsControl)
        addSubview(findButton)
        addSubview(replaceButton)
        addSubview(allButton)
        addSubview(cancelButton)
    }
}
