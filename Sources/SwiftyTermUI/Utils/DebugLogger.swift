import Foundation

/// Lightweight file logger for temporary debugging.
public enum DebugLogger {
    private static let queue = DispatchQueue(label: "swiftytermui.debug.logger", qos: .utility)
    private static let logURL: URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("retrovision.log")
    }()
    
    /// Appends a new line to the debug log (located in /tmp/retrovision.log).
    public static func log(_ message: String) {
        queue.async {
            let timestamp = makeTimestamp()
            let line = "[\(timestamp)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            
            do {
                if FileManager.default.fileExists(atPath: logURL.path) {
                    let handle = try FileHandle(forWritingTo: logURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: logURL, options: .atomic)
                }
            } catch {
                // Fallback: try writing atomically if seeking failed
                try? data.write(to: logURL, options: .atomic)
            }
        }
    }
    
    /// Deletes the current log file (optional helper).
    public static func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: logURL)
        }
    }
    
    /// Returns the log file path for reference.
    public static var logFilePath: String {
        logURL.path
    }
    
    private static func makeTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}

