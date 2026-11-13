import Foundation

/// Thread-safe in-memory ring buffer retaining recent sanitized diagnostic log lines.
nonisolated final class DebugLogBuffer: @unchecked Sendable {
    static let shared = DebugLogBuffer()

    private let lock = NSLock()
    private let maxEntries = 300
    private var entries: [String] = []
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

    func append(_ message: String) {
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        lock.withLock {
            entries.append(line)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
        }
    }

    func recentEntries() -> [String] {
        lock.withLock { entries }
    }

    func clear() {
        lock.withLock { entries.removeAll() }
    }
}

nonisolated func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    DebugLogBuffer.shared.append(message)
#if DEBUG
    Swift.print(message, terminator: terminator)
#endif
}
