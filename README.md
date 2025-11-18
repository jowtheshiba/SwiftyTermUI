# SwiftyTermUI

Native Swift Terminal User Interface (TUI) library, inspired by ncurses but built from scratch without any external dependencies.

## Project Status

- **Stage 1: Foundation** ✅ COMPLETE
  - Terminal management (raw mode, signal handling)
  - Screen buffering with optimized rendering
  - Text attributes (bold, underline, italic, etc.)
  - Color support (8, 16, 256-color palettes)
  - Input handling (keyboard, special keys)
  - ANSI escape sequence generation

## Architecture

### Core Modules

- **TerminalManager** - Handles terminal initialization, cleanup, and system interaction
- **ScreenBuffer** - Double-buffering system with dirty cell tracking for efficient rendering
- **InputHandler** - Parses keyboard input including special keys and ANSI escape sequences
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

## Example

See `Examples/HelloTermUI.swift` for a basic usage example.

## Design Decisions

1. **Double Buffering** - All drawing operations write to an in-memory buffer first, then `refresh()` flushes to terminal
2. **Minimal ANSI** - Only necessary escape sequences are sent to reduce overhead
3. **Thread Safety** - All public operations are protected with locks
4. **Main Actor** - SingletonInstances use `@MainActor` for concurrency safety
5. **No External Dependencies** - Uses only Darwin framework on macOS/BSD

## Next Stages

- Stage 2: Basic Components (windows, boxes, lines)
- Stage 3: Window Management (panels, stacking)
- Stage 4: Advanced Input (mouse, resize events)
- Stage 5: Utilities and Helpers
- Stage 6: High-level Components (menus, forms, buttons)
- Stage 7: Optimization and Polish
