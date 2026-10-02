import Foundation

open class TCollection<Element> {
    var storage: [Element]

    public init(_ elements: [Element] = []) {
        storage = elements
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }
    public var elements: [Element] { storage }

    public subscript(index: Int) -> Element {
        storage[index]
    }

    public func at(_ index: Int) -> Element? {
        guard storage.indices.contains(index) else { return nil }
        return storage[index]
    }

    @discardableResult
    open func atPut(_ index: Int, _ item: Element) -> Bool {
        guard storage.indices.contains(index) else { return false }
        storage[index] = item
        return true
    }

    @discardableResult
    open func insert(_ item: Element) -> Int {
        storage.append(item)
        return storage.count - 1
    }

    @discardableResult
    open func insert(_ item: Element, at index: Int) -> Int {
        let target = max(0, min(index, storage.count))
        storage.insert(item, at: target)
        return target
    }

    @discardableResult
    open func atDelete(_ index: Int) -> Element? {
        guard storage.indices.contains(index) else { return nil }
        return storage.remove(at: index)
    }

    open func removeAll(keepingCapacity: Bool = false) {
        storage.removeAll(keepingCapacity: keepingCapacity)
    }

    open func replaceAll(with elements: [Element]) {
        storage = elements
    }

    public func indexOf(where predicate: (Element) throws -> Bool) rethrows -> Int? {
        try storage.firstIndex(where: predicate)
    }

    public func firstThat(_ predicate: (Element) throws -> Bool) rethrows -> Element? {
        try storage.first(where: predicate)
    }

    public func forEach(_ body: (Element) throws -> Void) rethrows {
        try storage.forEach(body)
    }
}

open class TSortedCollection<Element>: TCollection<Element> {
    public typealias Comparator = (Element, Element) -> ComparisonResult

    public let compare: Comparator
    public var duplicates: Bool

    public init(_ elements: [Element] = [], duplicates: Bool = false, compare: @escaping Comparator) {
        self.compare = compare
        self.duplicates = duplicates
        super.init()
        replaceAll(with: elements)
    }

    public func search(_ item: Element) -> (index: Int, found: Bool) {
        var low = 0
        var high = storage.count

        while low < high {
            let middle = low + (high - low) / 2
            if compare(storage[middle], item) == .orderedAscending {
                low = middle + 1
            } else {
                high = middle
            }
        }

        let found = low < storage.count && compare(storage[low], item) == .orderedSame
        return (low, found)
    }

    @discardableResult
    open override func insert(_ item: Element) -> Int {
        let result = search(item)
        if result.found && !duplicates {
            return result.index
        }

        var index = result.index
        if duplicates {
            while index < storage.count && compare(storage[index], item) == .orderedSame {
                index += 1
            }
        }
        storage.insert(item, at: index)
        return index
    }

    @discardableResult
    open override func insert(_ item: Element, at index: Int) -> Int {
        insert(item)
    }

    open override func replaceAll(with elements: [Element]) {
        storage.removeAll(keepingCapacity: true)
        for element in elements {
            _ = insert(element)
        }
    }

    @discardableResult
    open override func atPut(_ index: Int, _ item: Element) -> Bool {
        guard storage.indices.contains(index) else { return false }
        storage.remove(at: index)
        _ = insert(item)
        return true
    }
}

public final class TStringCollection: TSortedCollection<String> {
    public let caseSensitive: Bool

    public init(_ strings: [String] = [], caseSensitive: Bool = true, duplicates: Bool = false) {
        self.caseSensitive = caseSensitive
        super.init(strings, duplicates: duplicates) { lhs, rhs in
            if caseSensitive {
                return lhs.compare(rhs)
            }
            return lhs.caseInsensitiveCompare(rhs)
        }
    }
}
