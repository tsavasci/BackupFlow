import Foundation

enum FTPError: Error, LocalizedError {
    case invalidURL
    case connectionFailed
    case authenticationFailed
    case fileOperationFailed
    case invalidResponse
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz FTP sunucu adresi"
        case .connectionFailed:
            return "FTP sunucusuna bağlanılamadı"
        case .authenticationFailed:
            return "Kimlik doğrulama başarısız. Kullanıcı adı ve şifrenizi kontrol edin"
        case .fileOperationFailed:
            return "Dosya işlemi başarısız oldu"
        case .invalidResponse:
            return "Geçersiz sunucu yanıtı"
        case .unknown(let error):
            return "Beklenmeyen bir hata oluştu: \(error.localizedDescription)"
        }
    }
}
