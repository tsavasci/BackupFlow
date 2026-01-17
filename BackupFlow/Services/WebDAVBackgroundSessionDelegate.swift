import Foundation
import OSLog

final class WebDAVBackgroundSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let logger: Logger
    private let onFinishEvents: () -> Void

    init(logger: Logger, onFinishEvents: @escaping () -> Void) {
        self.logger = logger
        self.onFinishEvents = onFinishEvents
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("🌐 Background URLSession task failed: \(error.localizedDescription)")
        } else {
            logger.info("🌐 Background URLSession task completed successfully")
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { [onFinishEvents] in
            self.logger.info("🌐 All background URLSession events done, calling completion handler")
            onFinishEvents()
        }
    }
}
