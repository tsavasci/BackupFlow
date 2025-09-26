import SwiftUI

/// Represents the type of backup target (FTP or WebDAV)
enum BackupTarget: String, CaseIterable, Identifiable {
    case ftp = "FTP"
    case webdav = "WebDAV"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .ftp: return "network"
        case .webdav: return "globe"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}
