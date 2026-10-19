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

    /// Sanitizes a relative path to prevent directory traversal attacks (e.g. "../", "//", "./").
    static func sanitize(relativePath: String) -> String {
        let components = relativePath.components(separatedBy: "/")
        var cleanComponents: [String] = []
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "." || trimmed == ".." {
                continue
            }
            cleanComponents.append(trimmed)
        }
        return cleanComponents.joined(separator: "/")
    }

    /// Safely joins a remote base path and a relative path, neutralizing directory traversal.
    static func safeRemotePath(basePath: String, relativePath: String) -> String {
        let cleanRelative = sanitize(relativePath: relativePath)
        if basePath.isEmpty { return cleanRelative }
        if basePath == "/" { return "/\(cleanRelative)" }
        return basePath.hasSuffix("/") ? basePath + cleanRelative : "\(basePath)/\(cleanRelative)"
    }

    static func isReserved(relativePath: String) -> Bool {
        let normalized = sanitize(relativePath: relativePath)
        return normalized == manifestName
            || normalized == directoryName
            || normalized.hasPrefix("\(directoryName)/")
    }

    static func destinationPath(basePath: String, runIdentifier: String, relativePath: String) -> String {
        let cleanRelative = sanitize(relativePath: relativePath)
        let cleanRunId = runIdentifier.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let suffix = "\(directoryName)/\(cleanRunId)/\(cleanRelative)"
        if basePath.isEmpty { return suffix }
        if basePath == "/" { return "/\(suffix)" }
        return basePath.hasSuffix("/") ? basePath + suffix : "\(basePath)/\(suffix)"
    }
}
