import Foundation
import os.log

@MainActor
final class TelemetryReporter: ObservableObject {
    static let shared = TelemetryReporter()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "Telemetry")
    
    // Simple in-memory rate limiting state (no-op defaults)
    private var lastEventTimestamps: [String: Date] = [:]
    private var minIntervalByKey: [String: TimeInterval] = [
        // Example: "retry": 0.5
    ]
    
    private init() {}
    
    // MARK: - Public API
    func retryOccurred(error: Error, attempt: Int, delay: TimeInterval) {
        guard shouldEmit(key: "retry") else { return }
        #if DEBUG
        logger.debug("Telemetry: retryOccurred attempt=\(attempt), delay=\(String(format: \"%.2f\", delay))s, error=\(error.localizedDescription)")
        #endif
        // TODO: Integrate with your analytics/telemetry backend here.
    }
    
    func reporterDisconnected(reason: String) {
        guard shouldEmit(key: "reporterDisconnected") else { return }
        #if DEBUG
        logger.debug("Telemetry: reporterDisconnected reason=\(reason)")
        #endif
    }
    
    func rateLimited(endpoint: String, statusCode: Int) {
        guard shouldEmit(key: "rateLimited") else { return }
        #if DEBUG
        logger.debug("Telemetry: rateLimited endpoint=\(endpoint), status=\(statusCode)")
        #endif
    }
    
    // MARK: - Debounce/Throttle Scaffolding
    private func shouldEmit(key: String) -> Bool {
        // Throttle by key if a minimum interval is configured
        if let minInterval = minIntervalByKey[key], let last = lastEventTimestamps[key] {
            if Date().timeIntervalSince(last) < minInterval {
                return false
            }
        }
        lastEventTimestamps[key] = Date()
        return true
    }
}
