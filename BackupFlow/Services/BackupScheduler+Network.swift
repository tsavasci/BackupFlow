
import AVFoundation
@preconcurrency import BackgroundTasks
import Combine
import Foundation
import Network
import Photos
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

import UIKit

/// The type of network connection.
enum NetworkType {
    case wifi
    case cellular
    case ethernet
    case unknown

    var description: String {
        switch self {
        case .wifi: return "network.type.wifi".localized
        case .cellular: return "network.type.cellular".localized
        case .ethernet: return "network.type.ethernet".localized
        case .unknown: return "network.type.unknown".localized
        }
    }

    /// Whether this connection type can reach the internet.
    var isOnline: Bool {
        self != .unknown
    }
}

/// A thread-safe, sendable class to manage a `CheckedContinuation`.
/// This ensures that the continuation is resumed exactly once.
private final class ResumptionManager: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NetworkType, Never>?

    init(_ continuation: CheckedContinuation<NetworkType, Never>) {
        self.continuation = continuation
    }

    /// Attempts to resume the continuation.
    /// - Parameter type: The `NetworkType` to resume with.
    /// - Returns: `true` if the continuation was resumed, `false` otherwise.
    func resume(with type: NetworkType) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let c = continuation {
            continuation = nil
            c.resume(returning: type)
            return true
        }
        return false
    }
}

extension BackupScheduler {
    // MARK: - Network Detection Helpers

    /// Network türünü tespit eder
    func getCurrentNetworkType() async -> NetworkType {
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "NetworkMonitor")
            let resumptionManager = ResumptionManager(continuation)

            monitor.pathUpdateHandler = { path in
                let networkType: NetworkType
                if path.usesInterfaceType(.wifi) {
                    networkType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    networkType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    networkType = .ethernet
                } else {
                    networkType = .unknown
                }

                Task { @MainActor in
                    if resumptionManager.resume(with: networkType) {
                        monitor.cancel()
                    }
                }
            }

            monitor.start(queue: queue)

            // Timeout after 5 seconds (fallback)
            queue.asyncAfter(deadline: .now() + 5) {
                Task { @MainActor in
                    if resumptionManager.resume(with: .unknown) {
                        monitor.cancel()
                    }
                }
            }
        }
    }
}
