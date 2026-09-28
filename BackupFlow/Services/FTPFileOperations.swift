import Foundation
import FilesProvider
import OSLog

struct FTPFileOperations {
    let provider: FTPFileProvider
    let logger: Logger
    let isVerboseLoggingEnabled: Bool
    let isCancelled: () -> Bool
    let mapError: (Error) -> FTPError

    func createDirectory(at path: String) async throws {
        if isCancelled() {
            logger.info("İşlem iptal edildiği için dizin oluşturma iptal edildi")
            throw FTPError.fileOperationFailed
        }

        if let exists = try? await directoryExists(path), exists == true {
            logger.info("Dizin zaten mevcut: \(path)")
            return
        }

        logger.info("Dizin oluşturuluyor: \(path)")

        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        var currentPath = ""

        for component in components {
            currentPath += "/" + component

            if let exists = try? await directoryExists(currentPath), exists == true {
                logger.debug("Ara dizin zaten mevcut: \(currentPath)")
                continue
            }

            logger.debug("Ara dizin oluşturuluyor: \(currentPath)")

            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let parentPath = (currentPath as NSString).deletingLastPathComponent
                    let folderName = (currentPath as NSString).lastPathComponent
                    let parent = parentPath.isEmpty ? "/" : parentPath
                    provider.create(folder: folderName, at: parent) { (error: Error?) in
                        if let error = error {
                            logger.warning("Dizin oluşturulurken hata: \(error.localizedDescription). Yine de devam ediliyor...")
                            continuation.resume()
                        } else {
                            logger.debug("Dizin başarıyla oluşturuldu: \(currentPath)")
                            continuation.resume()
                        }
                    }
                }
            } catch {
                logger.error("Dizin oluşturulurken beklenmeyen hata: \(error.localizedDescription)")
            }
        }

        switch try? await directoryExists(path) {
        case .some(true):
            logger.info("Dizin başarıyla oluşturuldu: \(path)")
        case .some(false):
            logger.error("Dizin oluşturulamadı: \(path)")
            throw FTPError.fileOperationFailed
        default:
            // Many FTP servers can't report attributes for a directory (nil = unknown).
            // That isn't a failure: a real problem surfaces when uploading into it.
            logger.debug("Dizin durumu doğrulanamadı, devam ediliyor: \(path)")
        }
    }

    func directoryExists(_ path: String) async throws -> Bool? {
        guard !path.isEmpty else {
            logger.debug("Kök dizin kontrol ediliyor: Her zaman mevcut kabul ediliyor")
            return true
        }

        logger.debug("Dizin kontrol ediliyor: \(path)")

        return try await withCheckedThrowingContinuation { continuation in
            provider.attributesOfItem(path: path) { file, error in
                if let error = error as? URLError, error.code == .fileDoesNotExist {
                    logger.debug("Dizin bulunamadı: \(path)")
                    continuation.resume(returning: false)
                } else if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && (nsError.code == NSURLErrorNoPermissionsToReadFile || nsError.code == NSURLErrorCannotCreateFile) {
                        logger.warning("Dizin mevcut kabul ediliyor: \(path) - \(error.localizedDescription)")
                        continuation.resume(returning: true)
                    } else {
                        if isVerboseLoggingEnabled {
                            logger.warning("Dizin kontrolü sırasında hata: \(error.localizedDescription)")
                        }
                        continuation.resume(returning: nil)
                    }
                } else if let file = file {
                    logger.debug("Dizin kontrolü: \(path) - \(file.isDirectory == true ? "Dizin olarak mevcut" : "Dosya olarak mevcut")")
                    continuation.resume(returning: file.isDirectory)
                } else {
                    if isVerboseLoggingEnabled {
                        logger.warning("Dosya bilgisi alınamadı: \(path)")
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func listDirectory(at path: String) async throws -> [FileObject] {
        return try await withCheckedThrowingContinuation { continuation in
            provider.contentsOfDirectory(path: path) { files, error in
                if let error = error {
                    continuation.resume(throwing: mapError(error))
                } else {
                    continuation.resume(returning: files)
                }
            }
        }
    }
}

