import Crypto
import Foundation

enum BackupChecksum {
    static func sha256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 256 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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
