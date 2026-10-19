import CryptoKit
import Foundation
import Security

enum WebDAVCertificateError: LocalizedError {
    case changedCertificate(host: String, port: Int)
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .changedCertificate(let host, let port):
            return "WebDAV TLS certificate mismatch for \(host):\(port). The server certificate has changed."
        case .keychainFailure(let status):
            return "WebDAV certificate fingerprint could not be saved securely (Keychain status: \(status))."
        }
    }
}

final class WebDAVCertificateStore: @unchecked Sendable {
    static let shared = WebDAVCertificateStore()

    private let service = "tamersavasci.BackupFlow.webdav-certificates"
    private let lock = NSLock()

    private init() {}

    /// Validates a leaf certificate fingerprint for a given host and port.
    /// - Returns: `true` if this is a newly trusted certificate, `false` if it matches an existing trust.
    /// - Throws: `WebDAVCertificateError.changedCertificate` if the fingerprint differs from the stored trust.
    func validate(fingerprint: String, host: String, port: Int) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let account = accountName(host: host, port: port)
        if let stored = fingerprintForAccount(account) {
            guard stored == fingerprint else {
                throw WebDAVCertificateError.changedCertificate(host: host, port: port)
            }
            return false
        }

        guard let data = fingerprint.data(using: .utf8) else {
            throw WebDAVCertificateError.keychainFailure(errSecParam)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WebDAVCertificateError.keychainFailure(status)
        }
        return true
    }

    /// Removes a stored certificate fingerprint for the host and port.
    func delete(host: String, port: Int) {
        lock.lock()
        defer { lock.unlock() }
        let account = accountName(host: host, port: port)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Fetches the stored certificate fingerprint for the host and port.
    func storedFingerprint(host: String, port: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return fingerprintForAccount(accountName(host: host, port: port))
    }

    private func accountName(host: String, port: Int) -> String {
        return "\(host.lowercased()):\(port)"
    }

    private func fingerprintForAccount(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let fingerprint = String(data: data, encoding: .utf8) else {
            return nil
        }
        return fingerprint
    }
}
