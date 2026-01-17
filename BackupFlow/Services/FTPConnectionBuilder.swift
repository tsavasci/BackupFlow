import Foundation

struct FTPConnectionInfo {
    let host: String
    let port: Int
    let displayHost: String
}

enum FTPConnectionBuilder {
    static func build(host: String, port: Int) throws -> FTPConnectionInfo {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            throw FTPError.invalidURL
        }

        guard port > 0 && port < 65536 else {
            throw FTPError.invalidURL
        }

        let displayHost = {
            if let url = URL(string: trimmedHost),
               let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                return comps.host ?? trimmedHost
            }
            return trimmedHost
        }()

        let cleanHostForValidation = trimmedHost.replacingOccurrences(of: "ftp://", with: "")
            .replacingOccurrences(of: "://", with: "")
            .replacingOccurrences(of: "@", with: "")
        var urlValidate = URLComponents()
        urlValidate.scheme = "ftp"
        urlValidate.host = cleanHostForValidation
        urlValidate.port = port
        guard urlValidate.url != nil else {
            throw FTPError.invalidURL
        }

        return FTPConnectionInfo(host: trimmedHost, port: port, displayHost: displayHost)
    }
}
