import SwiftyTermUI

public class TTab: TView {
    public var title: String
    
    public init(title: String) {
        self.title = title
        super.init(frame: Rect(x: 0, y: 0, width: 0, height: 0))
    }
    
    @MainActor
    public override func draw() {
        guard isVisible else { return }
        for view in subviews {
            view.draw()
        }
    }
}
