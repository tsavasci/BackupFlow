import Foundation

/// Persists completed relative file paths for an interrupted FTP/SFTP backup so
/// a subsequent `BGProcessingTask` or `BGContinuedProcessingTask` run can resume
/// without re-uploading already-transferred items.
actor ResumeCheckpointStore {
    private let defaults: UserDefaults
    private let keyPrefix: String

    init(keyPrefix: String, defaults: UserDefaults = .standard) {
        self.keyPrefix = keyPrefix
        self.defaults = defaults
    }

    static func makeID(
        scheme: String,
        host: String,
        port: Int,
        username: String,
        source: String,
        destination: String
    ) -> String {
        "\(scheme)|\(host.lowercased())|\(port)|\(username)|\(source)|\(destination)"
    }

    private func storageKey(for id: String) -> String {
        let encoded = Data(id.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return keyPrefix + encoded
    }

    func load(id: String) -> Set<String> {
        let key = storageKey(for: id)
        guard let list = defaults.array(forKey: key) as? [String] else {
            return []
        }
        return Set(list)
    }

    func mark(id: String, item: String) {
        let normalized = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        var values = load(id: id)
        values.insert(normalized)
        defaults.set(Array(values), forKey: storageKey(for: id))
    }

    func clear(id: String) {
        defaults.removeObject(forKey: storageKey(for: id))
    }
}
