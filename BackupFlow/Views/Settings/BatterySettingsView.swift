import SwiftUI

struct BatterySettingsView: View {
    @StateObject private var batteryManager = BatteryManager.shared
    @State private var tempBatteryLevel: Double = 30.0
    
    var body: some View {
        List {
            // Current Battery Status
            Section("battery.current_status".localized) {
                HStack {
                    Image(systemName: batteryManager.batteryIcon)
                        .foregroundColor(Color(batteryManager.batteryColor))
                        .font(.title2)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("battery.level".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            // Locale-aware percent: "%30" in Turkish, "30%" in English.
                            Text((Double(batteryManager.batteryPercentage) / 100).formatted(.percent))
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(batteryManager.batteryStateDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Status Indicator
                    Circle()
                        .fill(batteryManager.shouldAllowBackup() ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 4)
            }
            
            // Battery Threshold Settings
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("battery.minimum_level".localized)
                            .font(.headline)
                        Spacer()
                        Text((tempBatteryLevel / 100).formatted(.percent))
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    
                    Slider(
                        value: $tempBatteryLevel,
                        in: 1...100,
                        step: 1
                    ) {
                        Text("battery.minimum_level".localized)
                    }
                    .tint(DesignSystem.Colors.primary)
                    .onChange(of: tempBatteryLevel) { _, newValue in
                        batteryManager.setMinimumBatteryLevel(Int(newValue))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.caption)
                            .accessibilityHidden(true)
                        
                        Text("battery.threshold_info".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("battery.threshold_settings".localized)
            } footer: {
                Text("battery.threshold_footer".localized)
                    .font(.caption)
            }
            
            // Backup Conditions
            Section("battery.backup_conditions".localized) {
                ConditionRow(
                    icon: "battery.75",
                    title: "battery.condition.battery_level".localized,
                    subtitle: String(format: "battery.condition.battery_subtitle".localized, batteryManager.minimumBatteryLevel),
                    isActive: batteryManager.batteryPercentage >= batteryManager.minimumBatteryLevel
                )
                
                ConditionRow(
                    icon: "bolt.fill",
                    title: "battery.condition.charging".localized,
                    subtitle: "battery.condition.charging_subtitle".localized,
                    isActive: batteryManager.batteryState == .charging
                )
                
                ConditionRow(
                    icon: "battery.100.bolt",
                    title: "battery.condition.full".localized,
                    subtitle: "battery.condition.full_subtitle".localized,
                    isActive: batteryManager.batteryState == .full
                )
            }
            
            // Help Section
            Section("battery.help".localized) {
                VStack(alignment: .leading, spacing: 12) {
                    BatteryHelpRow(
                        icon: "battery.25",
                        text: "battery.help.1".localized
                    )
                    BatteryHelpRow(
                        icon: "bolt.circle",
                        text: "battery.help.2".localized
                    )
                    BatteryHelpRow(
                        icon: "bell",
                        text: "battery.help.3".localized
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("battery.settings".localized)
        .onAppear {
            tempBatteryLevel = Double(batteryManager.minimumBatteryLevel)
        }
    }
}

struct ConditionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isActive ? .green : .gray)
                .font(.title3)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isActive ? .green : .red)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        // Read as one row; the check/cross state is conveyed via the selected trait
        // instead of the icon names ("Kapat" for the cross).
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

struct BatteryHelpRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.body)
                .frame(width: 20)
                .accessibilityHidden(true)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        BatterySettingsView()
    }
}