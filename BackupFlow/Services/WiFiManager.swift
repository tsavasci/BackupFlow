import Network
import SystemConfiguration.CaptiveNetwork
import NetworkExtension
import Combine

@MainActor
class WiFiManager: ObservableObject {
    static let shared = WiFiManager()
    
    @Published var currentNetworkName: String?
    @Published var isConnectedToWiFi: Bool = false
    @Published var allowedNetworks: [String] = []
    
    private var pathMonitor: NWPathMonitor?
    private var monitorQueue = DispatchQueue(label: "WiFiMonitor")
    
    private init() {
        loadAllowedNetworks()
        startMonitoring()
    }
    
    deinit {
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    // MARK: - Network Monitoring
    
    func startMonitoring() {
        pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
        
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isConnectedToWiFi = path.status == .satisfied
                if path.status == .satisfied {
                    await self.getCurrentNetworkName()
                } else {
                    self.currentNetworkName = nil
                }
            }
        }
        
        pathMonitor?.start(queue: monitorQueue)
    }
    
    func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    // MARK: - Network Name Detection
    
    func getCurrentNetworkName() async {
        // iOS 14+ method using NEHotspotNetwork
        if #available(iOS 14.0, *) {
            let networks = await NEHotspotNetwork.fetchCurrent()
            self.currentNetworkName = networks?.ssid
        } else {
            // Fallback for older iOS versions (if needed)
            self.currentNetworkName = getLegacyNetworkName()
        }
    }
    
    @available(iOS, deprecated: 14.0, message: "Use NEHotspotNetwork.fetchCurrent() instead")
    private func getLegacyNetworkName() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
            return nil
        }
        
        for interface in interfaces {
            guard let networkInfo = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any],
                  let ssid = networkInfo[kCNNetworkInfoKeySSID as String] as? String else {
                continue
            }
            return ssid
        }
        return nil
    }
    
    // MARK: - Allowed Networks Management
    
    func addAllowedNetwork(_ networkName: String) {
        if !allowedNetworks.contains(networkName) {
            allowedNetworks.append(networkName)
            saveAllowedNetworks()
        }
    }
    
    func removeAllowedNetwork(_ networkName: String) {
        allowedNetworks.removeAll { $0 == networkName }
        saveAllowedNetworks()
    }
    
    func isCurrentNetworkAllowed() -> Bool {
        guard let currentNetwork = currentNetworkName else { return false }
        return allowedNetworks.contains(currentNetwork) || allowedNetworks.isEmpty
    }
    
    // MARK: - Persistence
    
    private func loadAllowedNetworks() {
        allowedNetworks = UserDefaults.standard.stringArray(forKey: "allowedWiFiNetworks") ?? []
    }
    
    private func saveAllowedNetworks() {
        UserDefaults.standard.set(allowedNetworks, forKey: "allowedWiFiNetworks")
    }
    
    // MARK: - Helper Methods
    
    func shouldAllowBackup() -> Bool {
        return isConnectedToWiFi && isCurrentNetworkAllowed()
    }
    
    func getReasonForBlockedBackup() -> String? {
        if !isConnectedToWiFi {
            return "wifi.not_connected".localized
        }
        
        if !isCurrentNetworkAllowed() {
            return "wifi.network_not_allowed".localized
        }
        
        return nil
    }
}