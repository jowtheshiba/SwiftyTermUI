import Foundation

open class TValidator {
    public init() {}

    open func isValid(_ input: String) -> Bool {
        true
    }
}

public final class TFilterValidator: TValidator {
    public let allowedCharacters: Set<Character>

    public init(allowedCharacters: Set<Character>) {
        self.allowedCharacters = allowedCharacters
        super.init()
    }

    public override func isValid(_ input: String) -> Bool {
        input.allSatisfy { allowedCharacters.contains($0) }
    }
}

public final class TRangeValidator: TValidator {
    public let range: ClosedRange<Int>

    public init(_ range: ClosedRange<Int>) {
        self.range = range
        super.init()
    }

    public override func isValid(_ input: String) -> Bool {
        guard let value = Int(input.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return range.contains(value)
    }
}

public final class TStringLookupValidator: TValidator {
    public let values: Set<String>
    public let caseSensitive: Bool

    public init(values: Set<String>, caseSensitive: Bool = true) {
        self.values = values
        self.caseSensitive = caseSensitive
        super.init()
    }

    public override func isValid(_ input: String) -> Bool {
        if caseSensitive {
            return values.contains(input)
        }
        let normalized = input.lowercased()
        return values.contains { $0.lowercased() == normalized }
    }
}
