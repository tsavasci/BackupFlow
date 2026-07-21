import Foundation

enum BackupArchive {
    static let directoryName = ".backupflow_archive"
    static let manifestName = ".backupflow_manifest.json"

    static func makeRunIdentifier(date: Date = Date(), uuid: UUID = UUID()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(formatter.string(from: date))-\(uuid.uuidString.prefix(8).lowercased())"
    }

    static func isReserved(relativePath: String) -> Bool {
        let normalized = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalized == manifestName
            || normalized == directoryName
            || normalized.hasPrefix("\(directoryName)/")
    }

    static func destinationPath(basePath: String, runIdentifier: String, relativePath: String) -> String {
        let relative = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = "\(directoryName)/\(runIdentifier)/\(relative)"
        if basePath.isEmpty { return suffix }
        if basePath == "/" { return "/\(suffix)" }
        return basePath.hasSuffix("/") ? basePath + suffix : "\(basePath)/\(suffix)"
    }
}
