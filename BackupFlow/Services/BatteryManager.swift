import UIKit
import Combine

@MainActor
class BatteryManager: ObservableObject {
    static let shared = BatteryManager()
    
    @Published var batteryLevel: Float = 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var minimumBatteryLevel: Int = 30 // Default 30%
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBatteryMonitoring()
        loadSettings()
    }
    
    // MARK: - Battery Monitoring Setup
    
    private func setupBatteryMonitoring() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        // Initial values
        batteryLevel = device.batteryLevel
        batteryState = device.batteryState
        
        // Listen for battery level changes
        NotificationCenter.default
            .publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.batteryLevel = device.batteryLevel
                }
            }
            .store(in: &cancellables)
        
        // Listen for battery state changes
        NotificationCenter.default
            .publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.batteryState = device.batteryState
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Battery Level Checks
    
    func shouldAllowBackup() -> Bool {
        // Allow backup if:
        // 1. Battery level is above minimum threshold, OR
        // 2. Device is charging, OR
        // 3. Device is plugged in
        
        let batteryPercentage = Int(batteryLevel * 100)
        
        return batteryPercentage >= minimumBatteryLevel || 
               batteryState == .charging || 
               batteryState == .full
    }
    
    func getReasonForBlockedBackup() -> String? {
        if !shouldAllowBackup() {
            let batteryPercentage = Int(batteryLevel * 100)
            return String(format: "battery.low_battery".localized, batteryPercentage, minimumBatteryLevel)
        }
        return nil
    }
    
    // MARK: - Settings Management
    
    func setMinimumBatteryLevel(_ level: Int) {
        minimumBatteryLevel = max(1, min(100, level))
        saveSettings()
    }
    
    private func loadSettings() {
        minimumBatteryLevel = UserDefaults.standard.object(forKey: "minimumBatteryLevel") as? Int ?? 30
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(minimumBatteryLevel, forKey: "minimumBatteryLevel")
    }
    
    // MARK: - Helper Properties
    
    var batteryPercentage: Int {
        Int(batteryLevel * 100)
    }
    
    var batteryStateDescription: String {
        switch batteryState {
        case .unknown:
            return "battery.state.unknown".localized
        case .unplugged:
            return "battery.state.unplugged".localized
        case .charging:
            return "battery.state.charging".localized
        case .full:
            return "battery.state.full".localized
        @unknown default:
            return "battery.state.unknown".localized
        }
    }
    
    var batteryColor: UIColor {
        if batteryState == .charging || batteryState == .full {
            return .systemGreen
        }
        
        let percentage = batteryPercentage
        if percentage >= 50 {
            return .systemGreen
        } else if percentage >= 20 {
            return .systemOrange
        } else {
            return .systemRed
        }
    }
    
    var batteryIcon: String {
        let percentage = batteryPercentage
        let chargingSuffix = (batteryState == .charging) ? ".bolt" : ""
        
        if percentage >= 100 {
            return "battery.100\(chargingSuffix)"
        } else if percentage >= 75 {
            return "battery.75\(chargingSuffix)"
        } else if percentage >= 50 {
            return "battery.50\(chargingSuffix)"
        } else if percentage >= 25 {
            return "battery.25\(chargingSuffix)"
        } else {
            return "battery.0\(chargingSuffix)"
        }
    }
}