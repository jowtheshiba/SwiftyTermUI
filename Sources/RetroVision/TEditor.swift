import Foundation
import SwiftyTermUI

public struct TEditorSearchOptions: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let caseSensitive = TEditorSearchOptions(rawValue: 1 << 0)
    public static let wholeWords = TEditorSearchOptions(rawValue: 1 << 1)
    public static let backwards = TEditorSearchOptions(rawValue: 1 << 2)
}

public struct TEditorRange: Equatable {
    public var start: TextPosition
    public var end: TextPosition

    public init(start: TextPosition, end: TextPosition) {
        self.start = start
        self.end = end
    }
}

@MainActor
public final class TEditor: TMemo {
    private struct Snapshot {
        var text: String
        var cursorRow: Int
        var cursorColumn: Int
        var selectionStart: TextPosition?
    }

    private var undoLimit = 100
    public var maxUndoLevels: Int {
        get { undoLimit }
        set {
            undoLimit = max(0, newValue)
            trimUndoStack()
        }
    }
    public private(set) var savedText: String
    public var isModified: Bool { text != savedText }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public private(set) var lastSearchText = ""
    public private(set) var lastSearchOptions: TEditorSearchOptions = []
    public var onModifiedChange: ((Bool) -> Void)?
    public var onStateChange: ((TEditor) -> Void)?
    public weak var statusIndicator: TEditorIndicator?
    public var onFindRequested: (() -> Void)?
    public var onReplaceRequested: (() -> Void)?

    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private var editDepth = 0
    private var reportedModified = false

    public override init(frame: Rect, text: String = "") {
        savedText = text
        super.init(frame: frame, text: text)
        contextMenu = { [weak self] in
            self?.editorContextMenuItems() ?? []
        }
    }

    public override var text: String {
        get { super.text }
        set {
            recordEdit {
                super.text = newValue
            }
        }
    }

    public override func editorModeDidChange() {
        if isReadOnly, isOverwriteMode {
            isOverwriteMode = false
            return
        }
        notifyStateChange()
    }

    public override func handleEvent(_ event: TEvent) {
        defer { notifyStateChange() }
        if isFocused, case .key(let key) = event {
            switch key {
            case .ctrl("z"):
                _ = undo()
                return
            case .ctrl("y"):
                _ = redo()
                return
            case .ctrl("f"):
                requestFind()
                return
            case .ctrl("r"):
                requestReplace()
                return
            case .ctrl("l"):
                _ = searchAgain()
                return
            case .ctrl("a"):
                selectAll()
                return
            case .insert:
                if !isReadOnly {
                    isOverwriteMode.toggle()
                }
                return
            default:
                break
            }
        }

        recordEdit {
            super.handleEvent(event)
        }
    }

    @discardableResult
    public override func handleCommand(_ command: TEvent.Command) -> Bool {
        switch command {
        case .undo:
            return undo()
        case .redo:
            return redo()
        case .find:
            requestFind()
            return true
        case .replace:
            requestReplace()
            return true
        case .searchAgain:
            return searchAgain() != nil
        case .cut:
            guard valid(command) else { return false }
            cutSelection()
            return true
        case .copy:
            guard valid(command) else { return false }
            copySelection()
            return true
        case .paste:
            guard valid(command) else { return false }
            pasteFromClipboard()
            return true
        case .clear:
            guard valid(command) else { return false }
            deleteSelection()
            return true
        case .selectAll:
            guard valid(command) else { return false }
            selectAll()
            return true
        case .toggleOverwrite:
            guard valid(command) else { return false }
            isOverwriteMode.toggle()
            return true
        default:
            return super.handleCommand(command)
        }
    }

    public override func valid(_ command: TEvent.Command) -> Bool {
        switch command {
        case .undo:
            return canUndo
        case .redo:
            return canRedo
        case .cut, .clear:
            return hasSelection && !isReadOnly
        case .copy:
            return hasSelection
        case .paste:
            return !isReadOnly && !TClipboard.text.isEmpty
        case .selectAll:
            return !text.isEmpty
        case .searchAgain:
            return !lastSearchText.isEmpty
        case .replace, .toggleOverwrite:
            return !isReadOnly
        default:
            return super.valid(command)
        }
    }

    public override func cutSelection() {
        guard !isReadOnly else { return }
        recordEdit { super.cutSelection() }
    }

    public override func pasteFromClipboard() {
        guard !isReadOnly else { return }
        recordEdit { super.pasteFromClipboard() }
    }

    public override func paste(text: String) {
        guard !isReadOnly else { return }
        recordEdit { super.paste(text: text) }
    }

    public override func deleteSelection() {
        guard !isReadOnly else { return }
        recordEdit { super.deleteSelection() }
    }

    public override func selectAll() {
        super.selectAll()
        notifyStateChange()
    }

    public override func setData(_ data: TViewData) -> Bool {
        guard case .text(let value) = data else { return false }
        load(value)
        return true
    }

    public func load(_ text: String) {
        editDepth += 1
        super.text = text
        cursorRow = 0
        cursorColumn = 0
        selectionStart = nil
        editDepth -= 1
        savedText = text
        undoStack.removeAll()
        redoStack.removeAll()
        reportModifiedState()
        notifyStateChange()
    }

    public func markSaved() {
        savedText = text
        reportModifiedState()
        notifyStateChange()
    }

    @discardableResult
    public func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        redoStack.append(snapshot())
        restore(previous)
        reportModifiedState()
        notifyStateChange()
        return true
    }

    @discardableResult
    public func redo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        undoStack.append(snapshot())
        restore(next)
        trimUndoStack()
        reportModifiedState()
        notifyStateChange()
        return true
    }

    public func findNext(
        _ query: String,
        options: TEditorSearchOptions = [],
        wrap: Bool = true
    ) -> TEditorRange? {
        guard !query.isEmpty else { return nil }
        lastSearchText = query
        lastSearchOptions = options

        let matches = matchingOffsets(query, options: options)
        guard !matches.isEmpty else { return nil }

        let currentOffset: Int
        if let selected = selectedRange() {
            currentOffset = options.contains(.backwards)
                ? offset(of: selected.start)
                : offset(of: selected.end)
        } else {
            currentOffset = offset(of: TextPosition(row: cursorRow, column: cursorColumn))
        }

        let match: Range<Int>?
        if options.contains(.backwards) {
            match = matches.last { $0.lowerBound < currentOffset } ?? (wrap ? matches.last : nil)
        } else {
            match = matches.first { $0.lowerBound >= currentOffset } ?? (wrap ? matches.first : nil)
        }

        guard let match else { return nil }
        let result = TEditorRange(start: position(at: match.lowerBound), end: position(at: match.upperBound))
        setSelection(from: result.start, to: result.end)
        notifyStateChange()
        return result
    }

    @discardableResult
    public func searchAgain(wrap: Bool = true) -> TEditorRange? {
        guard !lastSearchText.isEmpty else { return nil }
        return findNext(lastSearchText, options: lastSearchOptions, wrap: wrap)
    }

    @discardableResult
    public func replaceSelection(with replacement: String) -> Bool {
        guard !isReadOnly else { return false }
        guard let range = selectedRange() else { return false }
        let lowerBound = offset(of: range.start)
        let upperBound = offset(of: range.end)
        recordEdit {
            replaceOffsets(lowerBound..<upperBound, with: replacement)
        }
        return true
    }

    @discardableResult
    public func replaceNext(
        _ query: String,
        with replacement: String,
        options: TEditorSearchOptions = [],
        wrap: Bool = true
    ) -> Bool {
        guard !isReadOnly, !query.isEmpty else { return false }
        lastSearchText = query
        lastSearchOptions = options
        if selectionMatches(query, options: options) {
            return replaceSelection(with: replacement)
        }
        guard findNext(query, options: options, wrap: wrap) != nil else { return false }
        return replaceSelection(with: replacement)
    }

    public func showFindDialog(application: TApplication = .shared) {
        let dialog = TFindDialog(query: lastSearchText, options: lastSearchOptions)
        application.present(modal: dialog) { [weak self] command in
            guard command == .ok else { return }
            _ = self?.findNext(dialog.query, options: dialog.searchOptions)
        }
    }

    public func showReplaceDialog(application: TApplication = .shared) {
        let dialog = TReplaceDialog(query: lastSearchText, options: lastSearchOptions)
        dialog.onFindNext = { [weak self] query, options in
            _ = self?.findNext(query, options: options)
        }
        dialog.onReplace = { [weak self] query, replacement, options in
            _ = self?.replaceNext(query, with: replacement, options: options)
        }
        dialog.onReplaceAll = { [weak self] query, replacement, options in
            _ = self?.replaceAll(query, with: replacement, options: options)
        }
        application.present(modal: dialog as TWindow)
    }

    @discardableResult
    public func replaceAll(
        _ query: String,
        with replacement: String,
        options: TEditorSearchOptions = []
    ) -> Int {
        guard !isReadOnly, !query.isEmpty else { return 0 }
        lastSearchText = query
        lastSearchOptions = options
        let matches = matchingOffsets(
            query,
            options: options.subtracting(.backwards),
            nonOverlapping: true
        )
        guard !matches.isEmpty else { return 0 }

        recordEdit {
            var characters = Array(super.text)
            let replacementCharacters = Array(replacement)
            for match in matches.reversed() {
                characters.replaceSubrange(match, with: replacementCharacters)
            }
            super.text = String(characters)
            let endOffset = matches[0].lowerBound + replacementCharacters.count
            let end = position(at: endOffset)
            cursorRow = end.row
            cursorColumn = end.column
            selectionStart = nil
        }
        return matches.count
    }

    private func recordEdit(_ body: () -> Void) {
        if editDepth > 0 {
            body()
            return
        }

        let before = snapshot()
        editDepth += 1
        body()
        editDepth -= 1

        if super.text != before.text {
            undoStack.append(before)
            trimUndoStack()
            redoStack.removeAll()
            reportModifiedState()
            notifyStateChange()
        }
    }

    private func requestFind() {
        if let onFindRequested {
            onFindRequested()
        } else {
            showFindDialog()
        }
    }

    private func requestReplace() {
        if let onReplaceRequested {
            onReplaceRequested()
        } else {
            showReplaceDialog()
        }
    }

    private func editorContextMenuItems() -> [TMenuItem] {
        var items: [TMenuItem] = []
        if canUndo {
            items.append(TMenuItem(title: "Undo", action: { [weak self] in _ = self?.undo() }, shortcut: "Ctrl+Z"))
        }
        if canRedo {
            items.append(TMenuItem(title: "Redo", action: { [weak self] in _ = self?.redo() }, shortcut: "Ctrl+Y"))
        }
        if !items.isEmpty {
            items.append(.separator)
        }
        if valid(.cut) {
            items.append(TMenuItem(title: "Cut", action: { [weak self] in self?.cutSelection() }, shortcut: "Ctrl+X"))
        }
        if valid(.copy) {
            items.append(TMenuItem(title: "Copy", action: { [weak self] in self?.copySelection() }, shortcut: "Ctrl+C"))
        }
        if valid(.paste) {
            items.append(TMenuItem(title: "Paste", action: { [weak self] in self?.pasteFromClipboard() }, shortcut: "Ctrl+V"))
        }
        if valid(.clear) {
            items.append(TMenuItem(title: "Clear", action: { [weak self] in self?.deleteSelection() }, shortcut: "Del"))
        }
        if valid(.selectAll) {
            items.append(TMenuItem(title: "Select All", action: { [weak self] in self?.selectAll() }, shortcut: "Ctrl+A"))
        }
        if !items.isEmpty, !items[items.count - 1].isSeparator {
            items.append(.separator)
        }
        items.append(TMenuItem(title: "Find", action: { [weak self] in self?.requestFind() }, shortcut: "Ctrl+F"))
        if valid(.searchAgain) {
            items.append(TMenuItem(title: "Search Again", action: { [weak self] in _ = self?.searchAgain() }, shortcut: "Ctrl+L"))
        }
        if valid(.replace) {
            items.append(TMenuItem(title: "Replace", action: { [weak self] in self?.requestReplace() }, shortcut: "Ctrl+R"))
        }
        return items
    }

    private func selectionMatches(_ query: String, options: TEditorSearchOptions) -> Bool {
        guard !query.isEmpty, let selection = selectedRange() else { return false }
        let selectedOffsets = offset(of: selection.start)..<offset(of: selection.end)
        return matchingOffsets(
            query,
            options: options.subtracting(.backwards)
        ).contains(selectedOffsets)
    }

    private func notifyStateChange() {
        statusIndicator?.draw()
        onStateChange?(self)
    }

    private func snapshot() -> Snapshot {
        Snapshot(
            text: super.text,
            cursorRow: cursorRow,
            cursorColumn: cursorColumn,
            selectionStart: selectionStart
        )
    }

    private func restore(_ snapshot: Snapshot) {
        editDepth += 1
        super.text = snapshot.text
        cursorRow = snapshot.cursorRow
        cursorColumn = snapshot.cursorColumn
        selectionStart = snapshot.selectionStart
        editDepth -= 1
        setSelection(
            from: snapshot.selectionStart ?? TextPosition(row: snapshot.cursorRow, column: snapshot.cursorColumn),
            to: TextPosition(row: snapshot.cursorRow, column: snapshot.cursorColumn)
        )
        if snapshot.selectionStart == nil {
            selectionStart = nil
        }
    }

    private func trimUndoStack() {
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst(undoStack.count - maxUndoLevels)
        }
    }

    private func reportModifiedState() {
        let modified = isModified
        if modified != reportedModified {
            reportedModified = modified
            onModifiedChange?(modified)
        }
    }

    private func matchingOffsets(
        _ query: String,
        options: TEditorSearchOptions,
        nonOverlapping: Bool = false
    ) -> [Range<Int>] {
        let source = Array(super.text)
        let needle = Array(query)
        guard !needle.isEmpty, needle.count <= source.count else { return [] }
        var matches: [Range<Int>] = []
        var start = 0

        while start <= source.count - needle.count {
            let end = start + needle.count
            let candidate = String(source[start..<end])
            let matchesText = options.contains(.caseSensitive)
                ? candidate == query
                : candidate.compare(query, options: [.caseInsensitive]) == .orderedSame
            if matchesText && (!options.contains(.wholeWords) || isWholeWord(source, start..<end)) {
                matches.append(start..<end)
                start += nonOverlapping ? needle.count : 1
            } else {
                start += 1
            }
        }
        return matches
    }

    private func isWholeWord(_ characters: [Character], _ range: Range<Int>) -> Bool {
        let leftIsWord = range.lowerBound > 0 && isWordCharacter(characters[range.lowerBound - 1])
        let rightIsWord = range.upperBound < characters.count && isWordCharacter(characters[range.upperBound])
        return !leftIsWord && !rightIsWord
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character == "_" || character.isLetter || character.isNumber
    }

    private func offset(of position: TextPosition) -> Int {
        let row = max(0, min(position.row, lines.count - 1))
        var result = 0
        for index in 0..<row {
            result += lines[index].count + 1
        }
        return result + max(0, min(position.column, lines[row].count))
    }

    private func position(at offset: Int) -> TextPosition {
        var remainder = max(0, min(offset, Array(super.text).count))
        for index in lines.indices {
            if remainder <= lines[index].count {
                return TextPosition(row: index, column: remainder)
            }
            remainder -= lines[index].count + 1
        }
        let row = max(0, lines.count - 1)
        return TextPosition(row: row, column: lines[row].count)
    }

    private func replaceOffsets(_ range: Range<Int>, with replacement: String) {
        var characters = Array(super.text)
        characters.replaceSubrange(range, with: Array(replacement))
        super.text = String(characters)
        let end = position(at: range.lowerBound + replacement.count)
        cursorRow = end.row
        cursorColumn = end.column
        selectionStart = nil
    }
}
