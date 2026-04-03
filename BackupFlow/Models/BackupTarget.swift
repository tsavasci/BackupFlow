import SwiftUI

/// Represents the type of backup target (FTP or WebDAV)
enum BackupTarget: String, CaseIterable, Identifiable {
    case ftp = "FTP"
    case sftp = "SFTP"
    case webdav = "WebDAV"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .ftp: return "network"
        case .sftp: return "lock.shield"
        case .webdav: return "globe"
        }
    }
    
    var displayName: String {
        switch self {
        case .ftp: return "backup.protocol.ftp".localized
        case .sftp: return "backup.protocol.sftp".localized
        case .webdav: return "backup.protocol.webdav".localized
        }
    }
}
