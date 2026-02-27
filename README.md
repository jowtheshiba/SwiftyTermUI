# SwiftyTermUI

> **Note:** This project is currently under development. Cross-platform support is coming later. Tested on macOS.

<img width="811" height="698" alt="scr" src="https://github.com/user-attachments/assets/f2334d0d-e7ad-435f-8a5b-cf88311cd9d2" />

&nbsp;

SwiftyTermUI consists of two main parts:
- **Low-level engine**: A Swift analogue of `ncurses` for direct terminal control and drawing primitives, built from scratch without any external dependencies.
- **High-level framework**: An attempt to recreate the classic `Turbo Vision` experience in a modern context.

## Main API

```swift
let tui = SwiftyTermUI.shared

// Initialize terminal
try tui.initialize()

// Draw content
tui.drawString(row: 0, column: 0, text: "Hello")
tui.drawChar(row: 1, column: 0, character: "A", attributes: TextAttributes(bold: true))

// Render to terminal
try tui.refresh()

// Read input
if let event = tui.readEvent() {
    switch event {
    case .keyPress(let key):
        // Handle key
    case .terminalResize:
        // Handle resize
    }
}

// Cleanup
tui.shutdown()
```

## Building

```bash
swift build
```

## Examples

SwiftyTermUI includes several examples demonstrating different features:

| Example | Description |
|---------|-------------|
| `HelloTermUI.swift` | Basic setup and text drawing with colors and attributes |
| `DrawingExample.swift` | Lines, rectangles, and geometric shapes drawing |
| `WindowExample.swift` | Window management, panels, and window stacking |
| `InputExample.swift` | Keyboard input handling including special keys |
| `ComponentsExample.swift` | High-level components (Menu, Form, Button, TextBox, ProgressBar) |
| `OptimizationExample.swift` | Demonstrates render optimization features and statistics |
| `RetroDemo.swift` | A comprehensive demo of retro-styled UI components and interactions |

Run any example with:
```bash
swift run <ExampleName>
```
