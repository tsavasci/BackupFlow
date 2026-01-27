import Foundation
import OSLog

final class WebDAVBackgroundSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let logger: Logger
    private let onFinishEvents: () -> Void
    private let onTaskProgress: ((URLSessionTask, Int64, Int64) -> Void)?
    private let onTaskComplete: ((URLSessionTask, Error?) -> Void)?
    private let allowSelfSigned: Bool

    init(
        logger: Logger,
        allowSelfSigned: Bool = false,
        onTaskProgress: ((URLSessionTask, Int64, Int64) -> Void)? = nil,
        onTaskComplete: ((URLSessionTask, Error?) -> Void)? = nil,
        onFinishEvents: @escaping () -> Void
    ) {
        self.logger = logger
        self.allowSelfSigned = allowSelfSigned
        self.onTaskProgress = onTaskProgress
        self.onTaskComplete = onTaskComplete
        self.onFinishEvents = onFinishEvents
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [onTaskComplete] in
            onTaskComplete?(task, error)
        }

        if let error = error {
            logger.error("🌐 Background URLSession task failed: \(error.localizedDescription)")
        } else {
            logger.info("🌐 Background URLSession task completed successfully")
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        DispatchQueue.main.async { [onTaskProgress] in
            onTaskProgress?(task, totalBytesSent, totalBytesExpectedToSend)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { [onFinishEvents] in
            self.logger.info("🌐 All background URLSession events done, calling completion handler")
            onFinishEvents()
        }
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Handle Basic auth via headers or default handling
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        // Handle TLS server trust
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            if allowSelfSigned {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
