import UIKit
import Combine
import Foundation

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

    func shouldAllowBackup() -> Bool {
        // batteryLevel is -1 when the state is unknown (e.g. Simulator); don't block on missing data.
        guard batteryState != .unknown, batteryLevel >= 0 else { return true }
        let batteryPercentage = Int(batteryLevel * 100)
        return batteryPercentage >= minimumBatteryLevel ||
               batteryState == .charging ||
               batteryState == .full
    }
    
    func getReasonForBlockedBackup() -> String? {
        if !shouldAllowBackup() {
            return String(format: "battery.low_battery".localized, batteryPercentage, minimumBatteryLevel)
        }
        return nil
    }
    
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
    
    var batteryPercentage: Int {
        max(0, Int(batteryLevel * 100))
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
        // First, handle charging or full states with a single reliable icon
        if batteryState == .full {
            return "battery.100.bolt"
        }
        if batteryState == .charging {
            return "battery.100.bolt"
        }
        
        // If not charging, show the appropriate level
        let percentage = batteryPercentage
        if percentage >= 100 {
            return "battery.100"
        } else if percentage > 75 {
            return "battery.75"
        } else if percentage > 50 {
            return "battery.50"
        } else if percentage > 25 {
            return "battery.25"
        } else if percentage > 5 {
            return "battery.25" // Use 25 for the 5-25 range
        } else {
            return "battery.0"
        }
    }
}
