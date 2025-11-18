# SwiftyTermUI

Native Swift Terminal User Interface (TUI) library, inspired by ncurses but built from scratch without any external dependencies.

## Architecture

### Core Modules

- **TerminalManager** - Handles terminal initialization, cleanup, and system interaction
  - Buffered I/O with 8KB threshold for minimizing write() system calls
- **ScreenBuffer** - Double-buffering system with dirty cell tracking for efficient rendering
- **InputHandler** - Parses keyboard input including special keys and ANSI escape sequences
- **RenderOptimizer** - Optimizes rendering performance through caching and batching
  - AnsiSequenceCache: Caches ANSI codes for colors and text attributes
  - CommandBatch: Groups commands into buffers (default 4KB) before output
- **TextAttributes** - Text styling (bold, underline, italic, blink, reverse, dim)
- **Color** - Terminal color support with multiple palette types

### Main API

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

Run any example with:
```bash
swift run <ExampleName>
```
