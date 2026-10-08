import SwiftyTermUI

@MainActor
public final class TEditWindow: TWindow {
    public let editor: TEditor
    public var memo: TMemo { editor }
    
    public init(frame: Rect, title: String, text: String = "") {
        self.editor = TEditor(frame: Rect(x: 1, y: 1, width: max(0, frame.width - 2), height: max(0, frame.height - 2)), text: text)
        super.init(frame: frame, title: title, style: .window)
        showScrollBars()
        addSubview(editor)
        linkScrollBars()
    }
    
    @MainActor
    public override func draw() {
        var memoFrame = contentFrame
        if showsHorizontalScrollBar {
            memoFrame.height = max(0, memoFrame.height - 1)
        }
        memo.frame = memoFrame
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
