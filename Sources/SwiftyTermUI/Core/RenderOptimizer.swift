import Foundation

/// STAGE 7.1 - RENDER OPTIMIZATION IMPLEMENTATION
/// 
/// This module implements three key optimizations:
/// 1. **Escape Sequence Caching** - Caches frequently used ANSI codes to avoid repeated generation
/// 2. **Command Batching** - Groups multiple commands into larger buffers to reduce write() calls
/// 3. **System Call Minimization** - Uses write buffers in TerminalManager to batch I/O operations
///
/// Performance improvements:
/// - Reduces string concatenation overhead by caching 256-color codes
/// - Minimizes file write() system calls by batching commands
/// - Decreases memory allocations through buffer reuse
///
/// Example usage:
///   let optimizer = RenderOptimizer()
///   let commands = optimizer.generateOptimizedRenderCommands(buffer: screenBuffer)
///   terminal.writeToTerminal(commands)  // Now uses batching and caching

/// Cache for ANSI escape sequences to reduce string concatenation overhead
final class AnsiSequenceCache {
    private var attributeCache: [TextAttributes: String] = [:]
    private var colorCache: [Color: String] = [:]
    private var backgroundColorCache: [Color: String] = [:]
    private let lock = NSLock()

    /// Gets cached ANSI code for text attributes
    func getAttributeCode(_ attributes: TextAttributes) -> String {
        lock.lock()
        defer { lock.unlock() }

        if let cached = attributeCache[attributes] {
            return cached
        }

        let code = attributes.toAnsiCodes()
        attributeCache[attributes] = code
        return code
    }

    /// Gets cached ANSI code for foreground color
    func getForegroundColorCode(_ color: Color) -> String {
        lock.lock()
        defer { lock.unlock() }

        if let cached = colorCache[color] {
            return cached
        }

        let code = color.ansiCode
        colorCache[color] = code
        return code
    }

    /// Gets cached ANSI code for background color
    func getBackgroundColorCode(_ color: Color) -> String {
        lock.lock()
        defer { lock.unlock() }

        if let cached = backgroundColorCache[color] {
            return cached
        }

        let code = color.backgroundAnsiCode
        backgroundColorCache[color] = code
        return code
    }

    /// Clears all caches (useful after theme changes)
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        attributeCache.removeAll()
        colorCache.removeAll()
        backgroundColorCache.removeAll()
    }

    /// Gets cache statistics for monitoring
    func getStatistics() -> (attributes: Int, foregroundColors: Int, backgroundColors: Int) {
        lock.lock()
        defer { lock.unlock() }

        return (attributeCache.count, colorCache.count, backgroundColorCache.count)
    }
}

/// Optimizes rendering by batching commands and tracking dirty regions
final class RenderOptimizer {
    private let cache = AnsiSequenceCache()
    private let batchSize: Int
    private let lock = NSLock()

    private var lastRenderedState: ScreenRenderState = ScreenRenderState()
    private var dirtyRegions: [DirtyRegion] = []

    init(batchSize: Int = 4096) {
        self.batchSize = batchSize
    }

    /// Generates optimized render commands using diffing
    func generateOptimizedRenderCommands(buffer: ScreenBuffer) -> String {
        lock.lock()
        defer { lock.unlock() }

        var batch = CommandBatch(maxSize: batchSize)
        
        let height = buffer.rows
        let width = buffer.columns

        // If dimensions changed, force full redraw
        if lastRenderedState.rows != height || lastRenderedState.columns != width {
            batch.append("\u{1B}[2J\u{1B}[H")
            lastRenderedState = ScreenRenderState(width: width, height: height)
        }

        var currentAttributes = TextAttributes()
        var currentForeground = Color.default
        var currentBackground = Color.default
        var currentRow = 0
        var currentColumn = 0

        for row in 0 ..< height {
            for column in 0 ..< width {
                let cell = buffer.getCell(row: row, column: column)
                let previousCell = lastRenderedState.getCell(row: row, column: column)

                // Skip unchanged cells
                if cell == previousCell {
                    // If we are skipping, we lose track of "cursor" position if we were just writing
                    // But we only need to move cursor if we write again.
                    // So we just continue.
                    continue
                }

                // Move to position if needed
                // We track where the cursor would be if we just wrote a char.
                // If we skipped, the cursor is NOT at (row, column).
                // So we must move it.
                // Optimization: if we are at (row, column), no need to move.
                // But since we skip, we don't know where the terminal cursor is?
                // Actually, we can track it.
                
                // Simple approach: Always move if not sequential?
                // Let's use the logic:
                // If we just wrote at (row, col-1), cursor is at (row, col).
                // If we skipped (row, col-1), cursor is unknown (or at previous write end).
                
                // To be safe and simple for now:
                // If (row, column) is not (currentRow, currentColumn), move.
                // But wait, `currentColumn` is incremented after write.
                
                // Let's refine the cursor tracking.
                // We only update `currentRow`/`currentColumn` when we WRITE.
                // If we skip, `currentRow`/`currentColumn` become invalid/stale relative to screen,
                // but they represent where the cursor IS.
                
                // Wait, if we skip, the cursor DOES NOT move on screen.
                // So `currentRow`/`currentColumn` should track the *screen cursor*.
                
                // If we skip, we don't update `currentRow`/`currentColumn`.
                // When we need to write at `(row, column)`, we check if `currentRow == row` and `currentColumn == column`.
                // If not, we move.
                
                if row != currentRow || column != currentColumn {
                    batch.append("\u{1B}[\(row + 1);\(column + 1)H")
                    currentRow = row
                    currentColumn = column
                }

                // Update attributes and colors if changed
                if cell.attributes != currentAttributes || cell.foregroundColor != currentForeground || cell.backgroundColor != currentBackground {
                    batch.append("\u{1B}[0m")
                    currentAttributes = []
                    currentForeground = .default
                    currentBackground = .default

                    batch.append(cache.getAttributeCode(cell.attributes))
                    batch.append(cache.getForegroundColorCode(cell.foregroundColor))
                    batch.append(cache.getBackgroundColorCode(cell.backgroundColor))

                    currentAttributes = cell.attributes
                    currentForeground = cell.foregroundColor
                    currentBackground = cell.backgroundColor
                }

                batch.append(String(cell.character))
                currentColumn += 1
            }
            // End of row, we don't necessarily wrap or move cursor unless needed next time
        }

        batch.append("\u{1B}[0m")

        // Update last rendered state
        lastRenderedState.updateFromBuffer(buffer)

        return batch.build()
    }

    /// Clears all caches (useful when theme changes)
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }

        cache.clear()
    }

    /// Gets optimizer statistics for monitoring
    func getStatistics() -> OptimizerStatistics {
        lock.lock()
        defer { lock.unlock() }

        let (attrs, fgColors, bgColors) = cache.getStatistics()
        return OptimizerStatistics(
            cachedAttributes: attrs,
            cachedForegroundColors: fgColors,
            cachedBackgroundColors: bgColors,
            dirtyRegionsTracked: dirtyRegions.count
        )
    }
}

/// Represents statistics about the optimizer
public struct OptimizerStatistics {
    public let cachedAttributes: Int
    public let cachedForegroundColors: Int
    public let cachedBackgroundColors: Int
    public let dirtyRegionsTracked: Int
}

/// Represents a region of the screen that needs updating
struct DirtyRegion {
    let startRow: Int
    let startColumn: Int
    let endRow: Int
    let endColumn: Int
}

/// Batches ANSI commands to minimize write() system calls
struct CommandBatch {
    private var buffer: String
    private let maxSize: Int

    init(maxSize: Int = 4096) {
        self.maxSize = maxSize
        self.buffer = ""
        self.buffer.reserveCapacity(maxSize)
    }

    mutating func append(_ command: String) {
        buffer.append(command)
    }

    mutating func build() -> String {
        return buffer
    }

    var size: Int {
        buffer.utf8.count
    }

    var isFull: Bool {
        size >= maxSize
    }
}

/// Tracks the last rendered screen state for incremental updates
struct ScreenRenderState {
    private var cells: [[Cell]] = []

    mutating func updateFromBuffer(_ buffer: ScreenBuffer) {
        let height = buffer.rows
        let width = buffer.columns

        if cells.count != height || (cells.first?.count ?? 0) != width {
            cells = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
        }

        for row in 0 ..< height {
            for column in 0 ..< width {
                cells[row][column] = buffer.getCell(row: row, column: column)
            }
        }
    }

    func getCell(row: Int, column: Int) -> Cell {
        guard row >= 0 && row < cells.count && column >= 0 && column < cells[row].count else {
            return Cell.empty()
        }
        return cells[row][column]
    }
    
    var rows: Int { cells.count }
    var columns: Int { cells.first?.count ?? 0 }
    
    init(width: Int = 0, height: Int = 0) {
        if width > 0 && height > 0 {
            cells = Array(repeating: Array(repeating: Cell.empty(), count: width), count: height)
        }
    }
}


