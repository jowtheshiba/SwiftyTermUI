import SwiftyTermUI

@MainActor
public final class TEditWindow: TWindow {
    public let editor: TEditor
    public let indicator: TEditorIndicator
    public var memo: TMemo { editor }
    
    public init(frame: Rect, title: String, text: String = "") {
        self.editor = TEditor(frame: Rect(x: 1, y: 1, width: max(0, frame.width - 2), height: max(0, frame.height - 2)), text: text)
        self.indicator = TEditorIndicator(frame: Rect(x: 1, y: max(0, frame.height - 1), width: 1, height: 1))
        super.init(frame: frame, title: title, style: .window)
        showScrollBars()
        addSubview(editor)
        indicator.editor = editor
        editor.statusIndicator = indicator
        addSubview(indicator)
        linkScrollBars()
    }
    
    @MainActor
    public override func draw() {
        var memoFrame = contentFrame
        if showsHorizontalScrollBar {
            memoFrame.height = max(0, memoFrame.height - 1)
        }
        memo.frame = memoFrame
        let innerWidth = max(0, frame.width - 2)
        let scrollBarWidth = showsHorizontalScrollBar ? max(1, innerWidth / 2) : 0
        indicator.frame = Rect(
            x: 1,
            y: max(0, frame.height - 1),
            width: max(0, innerWidth - scrollBarWidth),
            height: 1
        )
        linkScrollBars()
        super.draw()
    }
    
    private func showScrollBars() {
        showsVerticalScrollBar = true
        showsHorizontalScrollBar = true
    }
    
    private func linkScrollBars() {
        if let vertical = verticalScrollBar {
            memo.verticalScrollBar = vertical
        }
        if let horizontal = horizontalScrollBar {
            memo.horizontalScrollBar = horizontal
        }
    }
}
