import Crypto
import Darwin
import Foundation

enum BackupChecksum {
    nonisolated static func sha256(of fileURL: URL) throws -> String {
        let fd = Darwin.open(fileURL.path, O_RDONLY)
        guard fd >= 0 else {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: [NSFilePathErrorKey: fileURL.path]
            )
        }
        defer { Darwin.close(fd) }

        // Reuse a single fixed buffer so hashing multi-GB files stays at ~256 KB
        // without accumulating autoreleased NSData chunks.
        let chunkSize = 256 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var hasher = SHA256()

        while true {
            let bytesRead = buffer.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(fd, rawBuffer.baseAddress, chunkSize)
            }
            if bytesRead > 0 {
                buffer.withUnsafeBytes { rawBuffer in
                    let slice = UnsafeRawBufferPointer(rebasing: rawBuffer.prefix(bytesRead))
                    hasher.update(bufferPointer: slice)
                }
            } else if bytesRead == 0 {
                break
            } else {
                if errno == EINTR { continue }
                throw NSError(
                    domain: NSPOSIXErrorDomain,
                    code: Int(errno),
                    userInfo: [NSFilePathErrorKey: fileURL.path]
                )
            }
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Async(of fileURL: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            try sha256(of: fileURL)
        }.value
    }
}

enum BackupIntegrityError: LocalizedError {
    case checksumMismatch(path: String)

    var errorDescription: String? {
        switch self {
        case .checksumMismatch(let path):
            return "Upload verification failed for \(path): SHA-256 checksum mismatch."
        }
    }
}
