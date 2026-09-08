import Crypto
import Foundation
import NIOCore
import NIOSSH
import Security

struct SFTPHostKeyValidationOutcome: Sendable {
    let isNewHostKey: Bool
    let fingerprint: String
}

enum SFTPHostKeyValidationError: LocalizedError {
    case changedHostKey(host: String, port: Int)
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .changedHostKey(let host, let port):
            return "SFTP host key mismatch for \(host):\(port). The server identity has changed."
        case .keychainFailure(let status):
            return "SFTP host key could not be saved securely (Keychain status: \(status))."
        }
    }
}

final class SFTPHostKeyStore: @unchecked Sendable {
    static let shared = SFTPHostKeyStore()

    private let service = "tamersavasci.BackupFlow.sftp-host-keys"
    private let lock = NSLock()

    private init() {}

    func validate(fingerprint: String, host: String, port: Int) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let account = accountName(host: host, port: port)
        if let stored = fingerprintForAccount(account) {
            guard stored == fingerprint else {
                throw SFTPHostKeyValidationError.changedHostKey(host: host, port: port)
            }
            return false
        }

        guard let data = fingerprint.data(using: .utf8) else {
            throw SFTPHostKeyValidationError.keychainFailure(errSecParam)
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
            throw SFTPHostKeyValidationError.keychainFailure(status)
        }
        return true
    }

    /// Removes a stored host key so the next connection treats it as a new (unknown) host.
    /// Call this when the user explicitly re-trusts a server after a key change.
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

    /// Replaces the stored fingerprint for a host. Use when the user explicitly trusts a new key.
    func update(fingerprint: String, host: String, port: Int) throws {
        lock.lock()
        defer { lock.unlock() }
        let account = accountName(host: host, port: port)
        guard let data = fingerprint.data(using: .utf8) else {
            throw SFTPHostKeyValidationError.keychainFailure(errSecParam)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                kSecValueData as String: data
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SFTPHostKeyValidationError.keychainFailure(addStatus)
            }
        } else if status != errSecSuccess {
            throw SFTPHostKeyValidationError.keychainFailure(status)
        }
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
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func accountName(host: String, port: Int) -> String {
        "\(host.lowercased()):\(port)"
    }
}

final class SFTPHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let host: String
    private let port: Int
    private let store: SFTPHostKeyStore
    private let lock = NSLock()
    private var storedOutcome: SFTPHostKeyValidationOutcome?

    init(host: String, port: Int, store: SFTPHostKeyStore = .shared) {
        self.host = host
        self.port = port
        self.store = store
    }

    var outcome: SFTPHostKeyValidationOutcome? {
        lock.lock()
        defer { lock.unlock() }
        return storedOutcome
    }

    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        let fingerprint = Self.fingerprint(for: hostKey)
        do {
            let isNew = try store.validate(fingerprint: fingerprint, host: host, port: port)
            lock.lock()
            storedOutcome = SFTPHostKeyValidationOutcome(
                isNewHostKey: isNew,
                fingerprint: fingerprint
            )
            lock.unlock()
            validationCompletePromise.succeed(())
        } catch {
            validationCompletePromise.fail(error)
        }
    }

    private static func fingerprint(for key: NIOSSHPublicKey) -> String {
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        key.write(to: &buffer)
        let digest = SHA256.hash(data: Data(buffer.readableBytesView))
        let encoded = Data(digest).base64EncodedString().replacingOccurrences(of: "=", with: "")
        return "SHA256:\(encoded)"
    }
}
