import Foundation

struct WebDAVRetryPolicy {
    let maxAttempts: Int = 3
    let baseDelaySeconds: Double = 1.0
    let maxDelaySeconds: Double = 32.0
    let jitterFraction: Double = 0.1

    func delayForAttempt(_ attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelaySeconds * pow(2.0, Double(attempt - 1))
        let cappedDelay = min(exponentialDelay, maxDelaySeconds)
        let jitter = Double.random(in: 0...(cappedDelay * jitterFraction))
        return cappedDelay + jitter
    }

    func shouldRetry(error: Error) -> Bool {
        let nsError = error as NSError
        let retryableNetworkCodes = [
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost,
            NSURLErrorTimedOut,
            NSURLErrorResourceUnavailable
        ]

        if nsError.domain == NSURLErrorDomain && retryableNetworkCodes.contains(nsError.code) {
            return true
        }

        if let statusCode = (nsError.userInfo["StatusCode"] as? NSNumber)?.intValue,
           statusCode == 429 || statusCode == 503 || (500...599).contains(statusCode) {
            return true
        }

        return false
    }
}
