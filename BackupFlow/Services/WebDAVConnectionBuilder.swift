import Foundation

struct WebDAVConnectionInfo {
    let url: URL
    let scheme: String
    let host: String
    let port: Int
    let path: String
}

enum WebDAVConnectionBuilder {
    static func build(host: String, port: Int) throws -> WebDAVConnectionInfo {
        var cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        var webdavPath = "/"

        if cleanHost.hasPrefix("http:/") && !cleanHost.hasPrefix("http://") {
            cleanHost = cleanHost.replacingOccurrences(of: "http:/", with: "http://")
        }
        if cleanHost.hasPrefix("https:/") && !cleanHost.hasPrefix("https://") {
            cleanHost = cleanHost.replacingOccurrences(of: "https:/", with: "https://")
        }
        cleanHost = cleanHost.replacingOccurrences(of: "://http://", with: "://")
        cleanHost = cleanHost.replacingOccurrences(of: "://https://", with: "://")

        var schemeFromInput: String?
        if let schemeRange = cleanHost.range(of: "://") {
            schemeFromInput = String(cleanHost[..<schemeRange.lowerBound]).lowercased()
            cleanHost = String(cleanHost[schemeRange.upperBound...])
        }

        if let pathRange = cleanHost.range(of: "/") {
            webdavPath = String(cleanHost[pathRange.lowerBound...])
            cleanHost = String(cleanHost[..<pathRange.lowerBound])
        }

        cleanHost = cleanHost.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !cleanHost.isEmpty && cleanHost != "http:" && cleanHost != "https:" else {
            throw NSError(
                domain: "WebDAVError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Geçersiz sunucu adresi. Lütfen 'http://192.168.1.1' veya '192.168.1.1' formatında girin."]
            )
        }

        let useHTTPS = (port == 443 || port == 8443 || port == 4433 || port == 4430 || port == 5006)
        let scheme = schemeFromInput ?? (useHTTPS ? "https" : "http")

        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = cleanHost
        if (scheme == "http" && port != 80) || (scheme == "https" && port != 443) {
            urlComponents.port = port
        }

        var cleanWebDAVPath = webdavPath
        while cleanWebDAVPath.hasPrefix("/") {
            cleanWebDAVPath = String(cleanWebDAVPath.dropFirst())
        }
        if !cleanWebDAVPath.isEmpty {
            urlComponents.path = "/" + cleanWebDAVPath
        } else {
            urlComponents.path = "/"
        }
        if !urlComponents.path.hasSuffix("/") {
            urlComponents.path += "/"
        }

        guard let url = urlComponents.url else {
            throw NSError(
                domain: "WebDAVError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL created. Please check the server address."]
            )
        }

        return WebDAVConnectionInfo(url: url, scheme: scheme, host: cleanHost, port: port, path: urlComponents.path)
    }
}
