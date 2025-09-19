import SwiftUI

struct WiFiSettingsView: View {
    @StateObject private var wifiManager = WiFiManager.shared
    @State private var showingAddNetworkAlert = false
    @State private var newNetworkName = ""
    @State private var showingRemoveAlert = false
    @State private var networkToRemove: String?
    
    var body: some View {
        List {
            // Current Network Status
            Section("wifi.current_network".localized) {
                HStack {
                    Image(systemName: wifiManager.isConnectedToWiFi ? "wifi" : "wifi.slash")
                        .foregroundColor(wifiManager.isConnectedToWiFi ? .green : .red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("wifi.status".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(currentNetworkStatus)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if let currentNetwork = wifiManager.currentNetworkName {
                        Button(action: {
                            wifiManager.addAllowedNetwork(currentNetwork)
                        }) {
                            if wifiManager.allowedNetworks.contains(currentNetwork) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Allowed Networks List
            Section {
                if wifiManager.allowedNetworks.isEmpty {
                    Text("wifi.no_allowed_networks".localized)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(wifiManager.allowedNetworks, id: \.self) { network in
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.blue)
                            
                            Text(network)
                            
                            Spacer()
                            
                            if network == wifiManager.currentNetworkName {
                                Text("wifi.current".localized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                networkToRemove = network
                                showingRemoveAlert = true
                            } label: {
                                Label("wifi.remove".localized, systemImage: "trash")
                            }
                        }
                    }
                }
                
                // Add Network Button
                Button(action: {
                    showingAddNetworkAlert = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("wifi.add_network".localized)
                    }
                }
            } header: {
                Text("wifi.allowed_networks".localized)
            } footer: {
                Text("wifi.allowed_networks_footer".localized)
                    .font(.caption)
            }
            
            // Help Section
            Section("wifi.help".localized) {
                VStack(alignment: .leading, spacing: 8) {
                    HelpRow(icon: "wifi", text: "wifi.help_1".localized)
                    HelpRow(icon: "shield.checkered", text: "wifi.help_2".localized)
                    HelpRow(icon: "plus.circle", text: "wifi.help_3".localized)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("wifi.settings".localized)
        .alert("wifi.add_network".localized, isPresented: $showingAddNetworkAlert) {
            TextField("wifi.network_name".localized, text: $newNetworkName)
            Button("alert.cancel".localized, role: .cancel) {
                newNetworkName = ""
            }
            Button("wifi.add".localized) {
                if !newNetworkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    wifiManager.addAllowedNetwork(newNetworkName.trimmingCharacters(in: .whitespacesAndNewlines))
                    newNetworkName = ""
                }
            }
        } message: {
            Text("wifi.add_network_message".localized)
        }
        .alert("wifi.remove_network".localized, isPresented: $showingRemoveAlert) {
            Button("alert.cancel".localized, role: .cancel) {}
            Button("wifi.remove".localized, role: .destructive) {
                if let network = networkToRemove {
                    wifiManager.removeAllowedNetwork(network)
                    networkToRemove = nil
                }
            }
        } message: {
            Text("wifi.remove_network_message".localized)
        }
        .onAppear {
            // Refresh current network info when view appears
            Task {
                await wifiManager.getCurrentNetworkName()
            }
        }
    }
    
    private var currentNetworkStatus: String {
        if !wifiManager.isConnectedToWiFi {
            return "wifi.not_connected_status".localized
        }
        
        guard let networkName = wifiManager.currentNetworkName else {
            return "wifi.unknown_network".localized
        }
        
        return networkName
    }
}

struct HelpRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.body)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationView {
        WiFiSettingsView()
    }
}