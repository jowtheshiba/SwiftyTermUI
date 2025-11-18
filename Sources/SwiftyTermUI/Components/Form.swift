import Foundation

/// Form with multiple input fields
public final class Form {
    public var x: Int
    public var y: Int
    public var width: Int
    
    public var fields: [TextField] = []
    public var title: String?
    
    private var focusedFieldIndex: Int = 0
    
    public var onSubmit: (([String]) -> Void)?
    
    public init(x: Int, y: Int, width: Int, title: String? = nil) {
        self.x = x
        self.y = y
        self.width = width
        self.title = title
    }
    
    /// Adds field to form
    public func addField(_ field: TextField) {
        fields.append(field)
        updateFieldPositions()
    }
    
    /// Moves focus to next field
    public func focusNext() {
        if focusedFieldIndex < fields.count - 1 {
            fields[focusedFieldIndex].isFocused = false
            focusedFieldIndex += 1
            fields[focusedFieldIndex].isFocused = true
        }
    }
    
    /// Moves focus to previous field
    public func focusPrevious() {
        if focusedFieldIndex > 0 {
            fields[focusedFieldIndex].isFocused = false
            focusedFieldIndex -= 1
            fields[focusedFieldIndex].isFocused = true
        }
    }
    
    /// Sets focus to first field
    public func focusFirst() {
        fields.forEach { $0.isFocused = false }
        if !fields.isEmpty {
            focusedFieldIndex = 0
            fields[0].isFocused = true
        }
    }
    
    /// Validates all fields
    public func validate() -> Bool {
        fields.allSatisfy { $0.isValid() }
    }
    
    /// Gets values of all fields
    public func getValues() -> [String] {
        fields.map { $0.value }
    }
    
    /// Clears all fields
    public func clear() {
        fields.forEach { field in
            field.value = ""
            field.cursorPosition = 0
        }
    }
    
    /// Submits form
    public func submit() {
        guard validate() else { return }
        onSubmit?(getValues())
    }
    
    private func updateFieldPositions() {
        var currentY = y
        
        if title != nil {
            currentY += 2
        }
        
        for field in fields {
            field.x = x
            field.y = currentY
            field.width = width
            
            currentY += (field.label != nil ? 2 : 1) + 1
        }
    }
    
    /// Renders form on screen
    @MainActor public func render(to tui: SwiftyTermUI) {
        var currentY = y
        
        // Title
        if let title = title {
            tui.drawString(row: currentY, column: x, text: title, attributes: [.bold, .underline], foregroundColor: .brightYellow)
            currentY += 2
        }
        
        // Fields
        for field in fields {
            field.render(to: tui)
        }
    }
    
    /// Handles keyboard event
    public func handleInput(_ event: InputEvent) -> Bool {
        guard case .keyPress(let key) = event else { return false }
        
        // Tab - next field
        if key == .tab {
            focusNext()
            return true
        }
        
        // Enter - submit or next field
        if key == .enter {
            if focusedFieldIndex == fields.count - 1 {
                submit()
            } else {
                focusNext()
            }
            return true
        }
        
        // Pass event to current field
        if focusedFieldIndex < fields.count {
            return fields[focusedFieldIndex].handleInput(event)
        }
        
        return false
    }
}
