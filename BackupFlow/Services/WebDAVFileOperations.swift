import Foundation
import FilesProvider
import OSLog

@MainActor
struct WebDAVFileOperations {
    let provider: WebDAVFileProvider

    func createDirectory(at path: String) async throws {
        let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard !pathComponents.isEmpty else { return }

        let directoryName = pathComponents.last!
        let parentPath = "/" + pathComponents.dropLast().joined(separator: "/")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false
            func safeThrow(_ error: Error) {
                if didResume { return }
                didResume = true
                continuation.resume(throwing: error)
            }
            func safeResume() {
                if didResume { return }
                didResume = true
                continuation.resume()
            }

            provider.create(folder: directoryName, at: parentPath) { error in
                if let error = error {
                    if (error as NSError).code != 516 {
                        safeThrow(WebDAVErrorMapper.mapError(error))
                        return
                    }
                    safeResume()
                } else {
                    safeResume()
                }
            }
        }
    }

    func listDirectory(at path: String) async throws -> [FileObject] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FileObject], Error>) in
            var didResume = false
            func safeThrow(_ error: Error) {
                if didResume { return }
                didResume = true
                continuation.resume(throwing: error)
            }
            func safeResume(_ value: [FileObject]) {
                if didResume { return }
                didResume = true
                continuation.resume(returning: value)
            }

            provider.contentsOfDirectory(path: path) { files, error in
                if let error = error {
                    safeThrow(WebDAVErrorMapper.mapError(error))
                } else {
                    safeResume(files)
                }
            }
        }
    }

    func deleteFile(at path: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false
            func safeThrow(_ error: Error) {
                if didResume { return }
                didResume = true
                continuation.resume(throwing: error)
            }
            func safeResume() {
                if didResume { return }
                didResume = true
                continuation.resume()
            }

            provider.removeItem(path: path) { error in
                if let error = error {
                    safeThrow(WebDAVErrorMapper.mapError(error))
                } else {
                    safeResume()
                }
            }
        }
    }

    func ensureDirectoryExists(at path: String, logger: Logger? = nil) async throws {
        let provider = provider
        let exists = await withCheckedContinuation { continuation in
            provider.attributesOfItem(path: path) { _, error in
                if error == nil {
                    logger?.info("Directory already exists: \(path)")
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }

        if !exists {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var components = path.components(separatedBy: "/").filter { !$0.isEmpty }
                var currentPath = ""

                func createNextDirectory() {
                    guard !components.isEmpty else {
                        logger?.info("All directories created successfully")
                        continuation.resume()
                        return
                    }

                    let component = components.removeFirst()
                    currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"

                    provider.attributesOfItem(path: currentPath) { _, error in
                        if error == nil {
                            logger?.info("Directory already exists: \(currentPath)")
                            createNextDirectory()
                        } else {
                            logger?.info("Creating directory: \(currentPath)")
                            let parentPath = (currentPath as NSString).deletingLastPathComponent
                            let folderName = (currentPath as NSString).lastPathComponent

                            provider.create(folder: folderName, at: parentPath, completionHandler: { error in
                                if let error = error {
                                    logger?.error("Could not create directory: \(currentPath) - \(error.localizedDescription)")
                                    continuation.resume(throwing: error)
                                } else {
                                    logger?.info("Directory created successfully: \(currentPath)")
                                    createNextDirectory()
                                }
                            })
                        }
                    }
                }

                createNextDirectory()
            }
        }
    }
}
