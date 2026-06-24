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
        let account = accountName(for: taskID)
        deletePassword(for: taskID)

        guard let data = password.data(using: .utf8), !password.isEmpty else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    func password(for taskID: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountName(for: taskID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }

        return String(data: data, encoding: .utf8)
    }

    func deletePassword(for taskID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountName(for: taskID)
        ]

        SecItemDelete(query as CFDictionary)
    }

    private func accountName(for taskID: UUID) -> String {
        "backup-task-\(taskID.uuidString)"
    }
}
