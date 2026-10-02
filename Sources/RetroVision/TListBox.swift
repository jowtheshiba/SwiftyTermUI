import SwiftyTermUI

open class TListBox: TListViewer {
    public var items: [String] {
        get { collection.elements }
        set {
            collection.replaceAll(with: newValue)
            reloadCollection()
        }
    }

    public init(frame: Rect, items: [String] = [], selectedIndex: Int = 0) {
        super.init(frame: frame, collection: TCollection(items), selectedIndex: selectedIndex)
    }

    public override init(frame: Rect, collection: TCollection<String>, selectedIndex: Int = 0) {
        super.init(frame: frame, collection: collection, selectedIndex: selectedIndex)
    }
}
