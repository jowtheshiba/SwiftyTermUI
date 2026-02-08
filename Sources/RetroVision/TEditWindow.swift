import SwiftyTermUI

/// Editor window with embedded memo and scrollbars
public final class TEditWindow: TWindow {
    public let memo: TMemo
    
    public init(frame: Rect, title: String, text: String = "") {
        self.memo = TMemo(frame: Rect(x: 1, y: 1, width: max(0, frame.width - 2), height: max(0, frame.height - 2)), text: text)
        super.init(frame: frame, title: title, style: .window)
        showScrollBars()
        addSubview(memo)
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
