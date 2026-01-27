import Foundation

struct FTPRetryPolicy {
    let maxAttempts: Int = 3
    let baseDelaySeconds: Double = 30.0
    let jitterFraction: Double = 0.1

    func delayForAttempt(_ attempt: Int) -> TimeInterval {
        // Exponential backoff: 30s, 60s, 120s (capped), with small jitter
        let base = baseDelaySeconds * pow(2.0, Double(max(0, attempt - 1)))
        let capped = min(base, 120.0)
        let jitter = Double.random(in: 0...jitterFraction)
        return capped * (1.0 + jitter)
    }
}
