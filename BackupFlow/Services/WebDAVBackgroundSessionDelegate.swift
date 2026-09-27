import Foundation
import OSLog
import CryptoKit

final class WebDAVBackgroundSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let logger: Logger
    private let onFinishEvents: () -> Void
    private let onTaskProgress: ((URLSessionTask, Int64, Int64) -> Void)?
    private let onTaskComplete: ((URLSessionTask, Error?) -> Void)?
    private let allowSelfSigned: Bool
    var credential: URLCredential?
    var pinnedCertHashes: [String]?

    init(
        logger: Logger,
        allowSelfSigned: Bool = false,
        credential: URLCredential? = nil,
        pinnedCertHashes: [String]? = nil,
        onTaskProgress: ((URLSessionTask, Int64, Int64) -> Void)? = nil,
        onTaskComplete: ((URLSessionTask, Error?) -> Void)? = nil,
        onFinishEvents: @escaping () -> Void
    ) {
        self.logger = logger
        self.allowSelfSigned = allowSelfSigned
        self.credential = credential
        self.pinnedCertHashes = pinnedCertHashes
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

    private func leafCertificateSHA256Base64(from trust: SecTrust) -> String? {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else { return nil }
        let data = SecCertificateCopyData(leaf) as Data
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Handle Basic or Digest auth using stored credential if present
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest {
            if let cred = self.credential {
                completionHandler(.useCredential, cred)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
            return
        }
        // Handle TLS server trust
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            // If pinning is configured, validate against pinned hashes
            if let pins = pinnedCertHashes, !pins.isEmpty, let serverHash = leafCertificateSHA256Base64(from: serverTrust) {
                if pins.contains(serverHash) {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                } else {
                    self.logger.error("🔒 TLS pinning failed: server certificate hash not in pinned set")
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
                return
            }
            // No pinning configured: allow self-signed if permitted, otherwise default handling
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

