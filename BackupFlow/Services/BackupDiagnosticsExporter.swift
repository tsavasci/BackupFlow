import Foundation
import UIKit

/// Builds a password-redacted diagnostics report for user troubleshooting and support.
enum BackupDiagnosticsExporter {
    nonisolated static func sanitize(_ text: String) -> String {
        var result = text
        let patterns: [(String, String)] = [
            // URL user:password@host -> user:***@host
            (#"([a-zA-Z][a-zA-Z0-9+\-.]*://[^:\s/@]+:)([^@\s/]+)(@)"#, "$1***$3"),
            // key=value or key: value for password / token / secret / authorization
            (#"(?i)\b(password|passwd|pwd|passphrase|secret|token|authorization)\b(\s*[:=]\s*)(\S+)"#, "$1$2***")
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
            }
        }
        return result
    }

    static func buildReport(historyItem: BackupHistory? = nil) -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let locale = Locale.current.identifier

        var lines: [String] = [
            "BackupFlow Diagnostics Report",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "App Version: \(version) (\(build))",
            "OS: \(osVersion)",
            "Locale: \(locale)",
            ""
        ]

        if let item = historyItem {
            lines.append("--- Run Summary ---")
            lines.append("Task: \(item.taskDisplayName ?? "N/A")")
            lines.append("Status: \(item.status)\(item.failureCategory.map { " (\($0.rawValue))" } ?? "")")
            lines.append("Files: \(item.filesProcessed) | Bytes: \(item.totalBytes) | Duration: \(String(format: "%.1fs", item.duration))")
            if let errorMessage = item.errorMessage, !errorMessage.isEmpty {
                lines.append("Error: \(sanitize(errorMessage))")
            }
            lines.append("")
        }

        lines.append("--- Recent Logs ---")
        let logs = DebugLogBuffer.shared.recentEntries()
        if logs.isEmpty {
            lines.append("(No logs recorded in this session)")
        } else {
            lines.append(contentsOf: logs.map(sanitize))
        }
        return lines.joined(separator: "\n")
    }
}
