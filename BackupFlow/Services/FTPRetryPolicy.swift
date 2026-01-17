import Foundation

struct FTPRetryPolicy {
    let maxAttempts: Int = 3
    let baseDelaySeconds: Double = 2.0
    let jitterFraction: Double = 0.3

    func delayForAttempt(_ attempt: Int) -> TimeInterval {
        let delay = baseDelaySeconds
        let jitter = Double.random(in: 0...jitterFraction)
        return delay * (1.0 + jitter)
    }
}
