import Foundation
import Network

final class FTPNetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "FTPNetworkMonitor")

    var onUpdate: ((NWPath.Status) -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.onUpdate?(path.status)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    static func statusString(_ status: NWPath.Status) -> String {
        switch status {
        case .satisfied:
            return "satisfied"
        case .unsatisfied:
            return "unsatisfied"
        case .requiresConnection:
            return "requiresConnection"
        @unknown default:
            return "unknown"
        }
    }
}
