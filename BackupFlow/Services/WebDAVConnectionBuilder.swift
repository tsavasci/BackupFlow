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
                userInfo: [NSLocalizedDescriptionKey: "error.webdav.invalid_server_address".localized]
            )
        }

        // Default to secure HTTPS unless explicitly specified as http in URL or standard HTTP port 80
        let isExplicitHttp = (schemeFromInput == "http") || (schemeFromInput == nil && port == 80)
        let scheme = schemeFromInput ?? (isExplicitHttp ? "http" : "https")

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
                userInfo: [NSLocalizedDescriptionKey: "error.webdav.invalid_url_created".localized]
            )
        }

        return WebDAVConnectionInfo(url: url, scheme: scheme, host: cleanHost, port: port, path: urlComponents.path)
    }
}
