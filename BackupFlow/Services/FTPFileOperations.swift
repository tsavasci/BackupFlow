import Foundation
import FilesProvider
import OSLog

struct FTPFileOperations {
    let provider: FTPFileProvider
    let logger: Logger
    let isVerboseLoggingEnabled: Bool
    let isCancelled: () -> Bool
    let mapError: (Error) -> FTPError
    var isDirectoryEnsured: ((String) -> Bool)? = nil
    var markDirectoryEnsured: ((String) -> Void)? = nil

    func createDirectory(at path: String) async throws {
        if isCancelled() {
            logger.info("İşlem iptal edildiği için dizin oluşturma iptal edildi")
            throw FTPError.fileOperationFailed
        }

        if isDirectoryEnsured?(path) == true {
            return
        }

        logger.info("Dizin oluşturuluyor: \(path)")

        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        var currentPath = ""

        for component in components {
            if isCancelled() {
                throw FTPError.fileOperationFailed
            }
            currentPath += "/" + component

            if isDirectoryEnsured?(currentPath) == true {
                continue
            }

            logger.debug("Ara dizin oluşturuluyor: \(currentPath)")

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let parentPath = (currentPath as NSString).deletingLastPathComponent
                let folderName = (currentPath as NSString).lastPathComponent
                let parent = parentPath.isEmpty ? "/" : parentPath
                provider.create(folder: folderName, at: parent) { (error: Error?) in
                    if let error = error {
                        // FTP servers return 550 / -3000 (cannotCreateFile) when the directory already exists.
                        logger.debug("Dizin zaten mevcut veya MKD yanıtı: \(currentPath) (\(error.localizedDescription))")
                    } else {
                        logger.debug("Dizin başarıyla oluşturuldu: \(currentPath)")
                    }
                    markDirectoryEnsured?(currentPath)
                    continuation.resume()
                }
            }
        }

        markDirectoryEnsured?(path)
        logger.info("Dizin hazır: \(path)")
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

