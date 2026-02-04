import Foundation
import FilesProvider
import OSLog

final class WebDAVBackgroundUploader {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func upload(
        provider: WebDAVFileProvider,
        localURL: URL,
        remotePath: String,
        executeWithRetry: @escaping (@escaping () async throws -> Void) async throws -> Void,
        onError: @escaping (Error) -> Void
    ) async throws {
        logger.info("🌐 Starting background upload (via FilesProvider): \(remotePath)")

        do {
            try await executeWithRetry {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var didResume = false
                    func safeThrow(_ error: Error) {
                        if didResume { return }
                        didResume = true
                        continuation.resume(throwing: error)
                    }
                    func safeResume() {
                        if didResume { return }
                        didResume = true
                        continuation.resume()
                    }

                    provider.copyItem(localFile: localURL, to: remotePath, overwrite: true) { error in
                        if let error = error {
                            onError(error)
                            self.logger.error("🌐 Background upload failed: \(error.localizedDescription)")
                            safeThrow(WebDAVErrorMapper.mapError(error))
                        } else {
                            self.logger.info("🌐 Background upload completed: \(remotePath)")
                            safeResume()
                        }
                    }
                }
            }
        } catch {
            onError(error)
            throw WebDAVErrorMapper.mapError(error)
        }
    }
}
