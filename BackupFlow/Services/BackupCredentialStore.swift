import Foundation
import Security

final class BackupCredentialStore {
    static let shared = BackupCredentialStore()

    private let service = "tamersavasci.BackupFlow.backup-credentials"
    private let prefix = "keychain:"

    private init() {}

    func isReference(_ value: String) -> Bool {
        value.hasPrefix(prefix)
    }

    func reference(for taskID: UUID) -> String {
        "\(prefix)\(taskID.uuidString)"
    }

    func savePassword(_ password: String, for taskID: UUID) {
        saveSecret(password, account: accountName(for: taskID, suffix: ""))
    }

    func password(for taskID: UUID) -> String? {
        secret(account: accountName(for: taskID, suffix: ""))
    }

    func deletePassword(for taskID: UUID) {
        deleteSecret(account: accountName(for: taskID, suffix: ""))
    }

    func savePrivateKey(_ key: String, for taskID: UUID) {
        saveSecret(key, account: accountName(for: taskID, suffix: "-ssh-key"))
    }

    func privateKey(for taskID: UUID) -> String? {
        secret(account: accountName(for: taskID, suffix: "-ssh-key"))
    }

    func deletePrivateKey(for taskID: UUID) {
        deleteSecret(account: accountName(for: taskID, suffix: "-ssh-key"))
    }

    func savePassphrase(_ passphrase: String, for taskID: UUID) {
        saveSecret(passphrase, account: accountName(for: taskID, suffix: "-ssh-passphrase"))
    }

    func passphrase(for taskID: UUID) -> String? {
        secret(account: accountName(for: taskID, suffix: "-ssh-passphrase"))
    }

    func deletePassphrase(for taskID: UUID) {
        deleteSecret(account: accountName(for: taskID, suffix: "-ssh-passphrase"))
    }

    private func saveSecret(_ value: String, account: String) {
        deleteSecret(account: account)
        guard let data = value.data(using: .utf8), !value.isEmpty else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func secret(account: String) -> String? {
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

    private func deleteSecret(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func accountName(for taskID: UUID, suffix: String) -> String {
        "backup-task-\(taskID.uuidString)\(suffix)"
    }
}
