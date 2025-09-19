import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Photos

enum PhotoLibraryPermission {
    case notDetermined
    case authorized
    case denied
    
    var isGranted: Bool {
        return self == .authorized
    }
}

enum ConnectionStatus: Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var isTesting: Bool {
        if case .testing = self { return true }
        return false
    }
    
    var message: String? {
        switch self {
        case .idle, .testing:
            return nil
        case .success(let message):
            return message
        case .failure(let error):
            return error
        }
    }
}

enum FrequencyType: String, CaseIterable, Identifiable {
    case manual = "Manuel"
    case daily = "Günlük"
    case weekly = "Haftalık"
    
    var id: String { self.rawValue }
}

struct TimePicker: View {
    @Binding var time: ScheduleTime

    var body: some View {
        VStack(alignment: .leading) {
            Text("Saat Seçiniz")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Picker("Saat", selection: $time.hour) {
                    ForEach(0..<24, id: \ .self) { hour in
                        Text(String(format: "%02d", hour)).tag(hour)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                .clipped()

                Text(":")
                    .font(.title2)
                    .padding(.horizontal, -10)

                Picker("Dakika", selection: $time.minute) {
                    ForEach(0..<60, id: \ .self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                .clipped()
            }
            .frame(height: 100)
        }
        .padding(.vertical, 8)
    }
}

struct DayPicker: View {
    @Binding var selectedDay: Int // 1: Sunday, 2: Monday, ..., 7: Saturday
    
    private let days = [
        (1, "Pazar"), (2, "Pazartesi"), (3, "Salı"), 
        (4, "Çarşamba"), (5, "Perşembe"), (6, "Cuma"), (7, "Cumartesi")
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Gün Seçiniz")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Gün", selection: $selectedDay) {
                ForEach(days, id: \.0) { day, name in
                    Text(name).tag(day)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 100)
            .clipped()
        }
        .padding(.vertical, 8)
    }
}
    
struct BackupView: View {
    // Varsayılan FTP sunucu ayarları
    private static let defaultFTPHost = "192.168.1.1"
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedURL: URL?
    @State private var isPhotoLibrarySelected = false
    @State private var ftpHost = Self.defaultFTPHost
    @State private var ftpPort = "21"
    @State private var ftpUsername = ""
    @State private var ftpPassword = ""
    @State private var isAnonymous = false
    @State private var destinationPath = "/"
    
    @State private var frequencyType: FrequencyType = .manual
    @State private var selectedTime = ScheduleTime(hour: 0, minute: 0)
    @State private var selectedDay = 1 // 1: Sunday, 2: Monday, ..., 7: Saturday
    
    @State private var showingDocumentPicker = false
    @State private var showingSaveAlert = false
    @State private var showingPhotoLibraryDeniedAlert = false
    @State private var saveAlertMessage = ""
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .idle

    var body: some View {
        Form {
            Section(header: Text("Kaynak Seçimi")) {
                VStack(alignment: .leading, spacing: 16) {
                    // Photo Library Option
                    Button(action: {
                        isPhotoLibrarySelected = true
                        selectedURL = nil
                        requestPhotoLibraryAccess()
                    }) {
                        HStack {
                            Image(systemName: isPhotoLibrarySelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isPhotoLibrarySelected ? .blue : .gray)
                            Text("Fotoğraf Galerisini Yedekle")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Or Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("veya")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.vertical, 4)
                    
                    // Folder Selection Option
                    HStack {
                        Image(systemName: !isPhotoLibrarySelected && selectedURL != nil ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(!isPhotoLibrarySelected && selectedURL != nil ? .blue : .gray)
                        
                        Button {
                            isPhotoLibrarySelected = false
                            showingDocumentPicker = true
                        } label: {
                            if let url = selectedURL {
                                Text(url.lastPathComponent)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Klasör Seç...")
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                
                Toggle("Anonim Giriş", isOn: $isAnonymous)
                
                if !isAnonymous {
                    TextField("Kullanıcı Adı", text: $ftpUsername)
                        .textContentType(.username)
                    
                    SecureField("Şifre", text: $ftpPassword)
                        .textContentType(.password)
                }
                
                TextField("FTP Sunucu", text: $ftpHost)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("Port", text: $ftpPort)
                    .keyboardType(.numberPad)
                
                TextField("Hedef Klasör", text: $destinationPath)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Bağlantıyı Test Et") {
                    Task {
                        await testConnection()
                    }
                }
                .disabled(isTestingConnection)
                
                if isTestingConnection {
                    ProgressView()
                }
                
                if let message = connectionStatus.message, !message.isEmpty {
                    HStack {
                        Image(systemName: connectionStatus.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(connectionStatus.isSuccess ? .green : .red)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(connectionStatus.isSuccess ? .green : .red)
                    }
                    .transition(.opacity)
                }
            }
            
            Section(header: Text("Zamanlama")) {
                Picker("Sıklık", selection: $frequencyType) {
                    ForEach(FrequencyType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                if frequencyType == .daily || frequencyType == .weekly {
                    TimePicker(time: $selectedTime)
                }
                
                if frequencyType == .weekly {
                    DayPicker(selectedDay: $selectedDay)
                }
            }
            
            Section {
                Button(action: {
                    Task {
                        await saveTask()
                    }
                }) {
                    HStack {
                        Spacer()
                        Text("Görevi Kaydet")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Yeni Yedekleme")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("İptal", role: .cancel) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(url: $selectedURL) {
                showingDocumentPicker = false
            }
        }
        .alert("Bilgi", isPresented: $showingSaveAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
        }
        .alert("Fotoğraf Galerisi Erişimi", isPresented: $showingPhotoLibraryDeniedAlert) {
            Button("Ayarlar") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Fotoğraf galerisine erişim izni vermeniz gerekiyor. Ayarlar'a gidip izin verebilirsiniz.")
        }
    }
    
    private func testConnection() async {
        guard !ftpHost.isEmpty else {
            connectionStatus = .failure("Lütfen FTP sunucu adresini girin")
            return
        }
        
        isTestingConnection = true
        connectionStatus = .idle
        
        do {
            let ftpService = FTPService.shared
            let port = Int(ftpPort) ?? 21
            
            try await ftpService.connect(
                host: ftpHost,
                port: port,
                username: isAnonymous ? nil : ftpUsername,
                password: isAnonymous ? nil : ftpPassword
            )
            
            connectionStatus = .success("Bağlantı başarılı")
        } catch let error as FTPError {
            connectionStatus = .failure(error.localizedDescription)
        } catch {
            connectionStatus = .failure("Bağlantı testi başarısız")
        }
        
        isTestingConnection = false
    }
    
    private func requestPhotoLibraryAccess() {
        let photoLibraryManager = PhotoLibraryManager.shared
        if photoLibraryManager.authorizationStatus == .notDetermined {
            photoLibraryManager.requestAuthorization { granted in
                if !granted {
                    DispatchQueue.main.async {
                        self.showingPhotoLibraryDeniedAlert = true
                    }
                }
            }
        } else if photoLibraryManager.authorizationStatus != .authorized && photoLibraryManager.authorizationStatus != .limited {
            showingPhotoLibraryDeniedAlert = true
        }
    }
    
    private func saveTask() async {
        // Check if either folder or photo library is selected
        guard isPhotoLibrarySelected || selectedURL != nil else {
            saveAlertMessage = "Lütfen bir kaynak seçin"
            showingSaveAlert = true
            return
        }
        
        // If photo library is selected, check permission
        if isPhotoLibrarySelected {
            let status = PHPhotoLibrary.authorizationStatus()
            guard status == .authorized || status == .limited else {
                saveAlertMessage = "Fotoğraf galerisine erişim izni verilmedi"
                showingSaveAlert = true
                return
            }
        }
        
        // Check folder access if a folder is selected
        if !isPhotoLibrarySelected, let sourceURL = selectedURL {
            guard sourceURL.startAccessingSecurityScopedResource() else {
                saveAlertMessage = "Klasöre erişim izni alınamadı. Lütfen tekrar deneyin."
                showingSaveAlert = true
                return
            }
            
            // We need to verify the URL is accessible
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)
            
            // Stop accessing the resource
            sourceURL.stopAccessingSecurityScopedResource()
            
            // Check if the path exists and is a directory
            guard exists && isDirectory.boolValue else {
                saveAlertMessage = "Geçersiz klasör yolu. Lütfen tekrar deneyin."
                showingSaveAlert = true
                return
            }
        }
        
        guard !ftpHost.isEmpty else {
            saveAlertMessage = "Lütfen FTP sunucu adresini girin"
            showingSaveAlert = true
            return
        }
        
        let port = Int(ftpPort) ?? 21
        
        // Create and save the backup task
        // Create the appropriate frequency based on the selected type
        let frequency: BackupFrequency = {
            switch frequencyType {
            case .manual:
                return .manual
            case .daily:
                return .daily(time: selectedTime)
            case .weekly:
                return .weekly(day: selectedDay, time: selectedTime)
            }
        }()
        
        // Determine source path and display name based on selection
        let sourcePath = isPhotoLibrarySelected ? "PHOTOS_LIBRARY" : (selectedURL?.path ?? "")
        let displayName = isPhotoLibrarySelected ? "Fotoğraf Galerisi" : (selectedURL?.lastPathComponent ?? "")
        
        let task = BackupTask(
            sourcePath: sourcePath,
            ftpHost: ftpHost,
            ftpPort: port,
            ftpUsername: isAnonymous ? "" : ftpUsername,
            ftpPassword: isAnonymous ? "" : ftpPassword,
            isAnonymous: isAnonymous,
            displayName: displayName,
            isEnabled: true,
            frequency: frequency
        )
        
        modelContext.insert(task)
        
        do {
            try modelContext.save()
            print("✅ BackupFlow: Görev başarıyla kaydedildi - \(displayName)")
            saveAlertMessage = "Görev başarıyla kaydedildi"
            
            // Schedule the backup if frequency is set
            if task.frequency != .manual {
                do {
                    try await BackupScheduler.shared.scheduleBackup(task: task)
                    saveAlertMessage += " ve planlandı"
                } catch {
                    saveAlertMessage += ", ancak planlama sırasında hata oluştu: \(error.localizedDescription)"
                }
            }
            
            // Reset form
            selectedURL = nil
            ftpHost = Self.defaultFTPHost
            ftpPort = "21"
            ftpUsername = ""
            ftpPassword = ""
            isAnonymous = false
            
            showingSaveAlert = true
        } catch {
            saveAlertMessage = "Görev kaydedilirken hata oluştu: \(error.localizedDescription)"
            showingSaveAlert = true
        }
    }
}
