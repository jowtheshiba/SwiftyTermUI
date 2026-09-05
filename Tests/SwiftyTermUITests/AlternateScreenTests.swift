import Foundation
import Testing
@testable import SwiftyTermUI

/// Captures everything TerminalManager would write to stdout, so tests can
/// assert exact escape-sequence order without a tty:
///
/// - `?1049h` must come before the first paint, with no extra `2J` on enter
/// - `2J H` must come before `?1049l` on exit
@MainActor
struct AlternateScreenTests {

    private static let enterAlt = "\u{1B}[?1049h"
    private static let leaveAlt = "\u{1B}[?1049l"
    private static let clearScreen = "\u{1B}[2J"
    private static let home = "\u{1B}[H"

    /// Installs a capture sink, runs `run`, and returns everything
    /// TerminalManager emitted. Never touches the real tty.
    private func capturedOutput(_ run: (TerminalManager) -> Void) -> String {
        let terminal = TerminalManager.shared
        terminal._resetForTesting()
        var chunks: [String] = []
        terminal.outputSink = { data in
            chunks.append(String(data: data, encoding: .utf8) ?? "")
        }
        run(terminal)
        let output = chunks.joined()
        terminal._resetForTesting()
        return output
    }

    // MARK: - Enter

    @Test func enterEmits1049hWithNoExtraClear() {
        let output = capturedOutput { terminal in
            terminal.enterAlternateScreen()
        }
        #expect(output == Self.enterAlt, "enter must emit exactly ?1049h (?1049h already clears; no extra 2J flash)")
    }

    @Test func enterIsIdempotent() {
        let terminal = TerminalManager.shared
        terminal._resetForTesting()
        var chunks: [String] = []
        terminal.outputSink = { data in
            chunks.append(String(data: data, encoding: .utf8) ?? "")
        }
        terminal.enterAlternateScreen()
        terminal.enterAlternateScreen()
        let output = chunks.joined()
        terminal._resetForTesting()
        #expect(output == Self.enterAlt, "double enter must still emit ?1049h exactly once")
    }

    @Test func leaveIsNoOpWhenInactive() {
        let output = capturedOutput { terminal in
            terminal.leaveAlternateScreen()
        }
        #expect(output.isEmpty, "leave with no active alt buffer must emit nothing")
    }

    // MARK: - Exit ordering

    @Test func cleanupEmitsClearBeforeLeaveAlt() {
        let terminal = TerminalManager.shared
        terminal._resetForTesting()
        var chunks: [String] = []
        terminal.outputSink = { data in
            chunks.append(String(data: data, encoding: .utf8) ?? "")
        }
        // Simulate a running session without touching the real tty.
        terminal._setRawModeForTesting(true)
        terminal.enterAlternateScreen()
        chunks.removeAll() // drop the ?1049h enter sequence; inspect exit only

        terminal.cleanup()
        let exit = chunks.joined()

        guard let clearRange = exit.range(of: Self.clearScreen),
              let homeRange = exit.range(of: Self.home),
              let leaveRange = exit.range(of: Self.leaveAlt)
        else {
            Issue.record("exit output missing 2J/H/?1049l: \(exit.debugDescription)")
            terminal._resetForTesting()
            return
        }
        #expect(clearRange.lowerBound < leaveRange.lowerBound, "2J must run while still in the alt buffer, before ?1049l")
        #expect(homeRange.lowerBound < leaveRange.lowerBound, "H must run while still in the alt buffer, before ?1049l")
        #expect(exit.range(of: "\u{1B}[?25h") != nil, "cursor restore must be part of exit")
        #expect(exit.range(of: "\u{1B}[?2004l") != nil, "bracketed-paste off must be part of exit")
        #expect(!(terminal.isAlternateScreenActive), "flag must be cleared by cleanup")

        // Double shutdown safety: second cleanup is a silent no-op.
        chunks.removeAll()
        terminal.cleanup()
        #expect(chunks.joined().isEmpty, "double cleanup must emit nothing")
        terminal._resetForTesting()
    }

    @Test func cleanupWithoutRawModeStillLeavesStrandedAltBuffer() {
        // initialize() threw (or was never called) but the alt buffer was
        // entered directly: cleanup must not strand the terminal there.
        let terminal = TerminalManager.shared
        terminal._resetForTesting()
        var chunks: [String] = []
        terminal.outputSink = { data in
            chunks.append(String(data: data, encoding: .utf8) ?? "")
        }
        terminal.enterAlternateScreen()
        #expect(terminal.isAlternateScreenActive)
        chunks.removeAll()

        terminal.cleanup()
        #expect(chunks.joined() == Self.leaveAlt)
        #expect(!(terminal.isAlternateScreenActive))
        terminal._resetForTesting()
    }

    // MARK: - Full repaint after entering

    @Test func invalidateForcesFullRepaint() {
        let optimizer = RenderOptimizer()
        let buffer = ScreenBuffer(width: 10, height: 4)

        let first = optimizer.generateOptimizedRenderCommands(buffer: buffer)
        #expect(first.contains("\u{1B}[2J"), "first paint after dimension change is a full redraw")

        let steady = optimizer.generateOptimizedRenderCommands(buffer: buffer)
        #expect(!(steady.contains("\u{1B}[2J")), "unchanged buffer paints (almost) nothing")

        // Simulate entering the alternate screen: the fresh buffer shares
        // nothing with the previously rendered state.
        optimizer.invalidate()
        let afterEnter = optimizer.generateOptimizedRenderCommands(buffer: buffer)
        #expect(afterEnter.contains("\u{1B}[2J"), "invalidate must force a full repaint so no stale cells leak in")
    }
}
