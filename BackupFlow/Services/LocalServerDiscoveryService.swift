import Foundation
import Network
import Observation

/// Discovers local NAS and file servers on the LAN via Bonjour (mDNS / DNS-SD) using `NWBrowser`.
@MainActor
@Observable
final class LocalServerDiscoveryService {
    struct DiscoveredServer: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let serviceType: String
        let domain: String
        let target: BackupTarget
        let defaultPort: Int
        let usesHTTPS: Bool
    }

    static let supportedServiceTypes = [
        "_sftp-ssh._tcp",
        "_webdavs._tcp",
        "_webdav._tcp",
        "_ftp._tcp"
    ]

    private(set) var discoveredServers: [DiscoveredServer] = []
    private(set) var isScanning = false
    private(set) var lastErrorMessage: String?

    private var browsers: [String: NWBrowser] = [:]
    private var resultsByType: [String: [DiscoveredServer]] = [:]

    nonisolated static func targetInfo(for serviceType: String) -> (target: BackupTarget, defaultPort: Int, usesHTTPS: Bool) {
        switch serviceType {
        case "_ftp._tcp":
            return (.ftp, 21, false)
        case "_sftp-ssh._tcp":
            return (.sftp, 22, false)
        case "_webdavs._tcp":
            return (.webdav, 443, true)
        case "_webdav._tcp":
            return (.webdav, 80, false)
        default:
            return (.ftp, 21, false)
        }
    }

    func startDiscovery() {
        stopDiscovery()
        isScanning = true
        lastErrorMessage = nil

        for serviceType in Self.supportedServiceTypes {
            let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: "local.")
            let parameters = NWParameters()
            parameters.includePeerToPeer = true
            let browser = NWBrowser(for: descriptor, using: parameters)

            browser.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if case .failed(let error) = state {
                        self.lastErrorMessage = error.localizedDescription
                    }
                }
            }

            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let info = Self.targetInfo(for: serviceType)
                    var mapped: [DiscoveredServer] = []
                    for result in results {
                        if case .service(let name, let type, let domain, _) = result.endpoint {
                            let id = "\(type)|\(name)|\(domain)"
                            mapped.append(
                                DiscoveredServer(
                                    id: id,
                                    name: name,
                                    serviceType: serviceType,
                                    domain: domain,
                                    target: info.target,
                                    defaultPort: info.defaultPort,
                                    usesHTTPS: info.usesHTTPS
                                )
                            )
                        }
                    }
                    self.resultsByType[serviceType] = mapped
                    self.rebuildDiscoveredList()
                }
            }

            browsers[serviceType] = browser
            browser.start(queue: .main)
        }
    }

    func stopDiscovery() {
        for browser in browsers.values {
            browser.cancel()
        }
        browsers.removeAll()
        resultsByType.removeAll()
        isScanning = false
    }

    /// Resolves a Bonjour service endpoint to a host/IP and port with a short timeout.
    /// Falls back to `<name>.local` and the protocol default port if direct resolution times out.
    func resolve(_ server: DiscoveredServer) async -> (host: String, port: Int) {
        let fallbackHost = Self.fallbackHostName(for: server.name)
        let fallback = (host: fallbackHost, port: server.defaultPort)

        let endpoint = NWEndpoint.service(
            name: server.name,
            type: server.serviceType,
            domain: server.domain,
            interface: nil
        )
        let connection = NWConnection(to: endpoint, using: .tcp)

        nonisolated final class ResumeGate: @unchecked Sendable {
            private let lock = NSLock()
            private var resumed = false

            func tryClaim() -> Bool {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return false }
                resumed = true
                return true
            }
        }

        return await withCheckedContinuation { continuation in
            let gate = ResumeGate()

            @Sendable func finish(with value: (host: String, port: Int)) {
                guard gate.tryClaim() else { return }
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if case .hostPort(let host, let port)? = connection.currentPath?.remoteEndpoint {
                        let rawHost = "\(host)"
                            .split(separator: "%", maxSplits: 1)
                            .first
                            .map(String.init) ?? fallbackHost
                        finish(with: (host: rawHost, port: Int(port.rawValue)))
                    } else {
                        finish(with: fallback)
                    }
                case .failed, .cancelled:
                    finish(with: fallback)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.5) {
                finish(with: fallback)
            }
        }
    }

    nonisolated static func fallbackHostName(for serviceName: String) -> String {
        let cleaned = serviceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
        if cleaned.isEmpty { return "nas.local" }
        return cleaned.hasSuffix(".local") ? cleaned : "\(cleaned).local"
    }

    private func rebuildDiscoveredList() {
        discoveredServers = resultsByType.values
            .flatMap { $0 }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.serviceType < rhs.serviceType
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }
}
