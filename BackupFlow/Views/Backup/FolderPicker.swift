import SwiftUI
import UniformTypeIdentifiers
import os.log

struct FolderPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.presentationMode) private var presentationMode
    private let logger = Logger(subsystem: "com.example.BackupFlow", category: "FolderPicker")
    
    private var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if os(iOS)
        return [.minimalBookmark]
        #else
        return [.withSecurityScope]
        #endif
    }
    
    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(iOS)
        return []
        #else
        return [.withSecurityScope]
        #endif
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder],
            asCopy: false
        )
        documentPicker.allowsMultipleSelection = false
        documentPicker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        documentPicker.delegate = context.coordinator
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {
        var parent: FolderPicker
        
        init(_ parent: FolderPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.logger.error("No URL was selected")
                return
            }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                parent.logger.error("Failed to start accessing security scoped resource")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                // Create a bookmark for the selected URL
                // iOS uyumlu bookmark seçenekleri
                let bookmarkData = try url.bookmarkData(
                    options: parent.bookmarkCreationOptions,
                    includingResourceValuesForKeys: [.isDirectoryKey, .fileSizeKey],
                    relativeTo: nil
                )
                
                // Verify we can resolve the bookmark
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: parent.bookmarkResolutionOptions,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                guard !isStale else {
                    parent.logger.error("Bookmark is stale")
                    return
                }
                
                // Save the bookmark to UserDefaults with path as key
                let pathKey = resolvedURL.path
                UserDefaults.standard.set(bookmarkData, forKey: "bookmark_\(pathKey)")
                
                // Also save general bookmark
                UserDefaults.standard.set(bookmarkData, forKey: "selectedFolderBookmark")
                
                // Update the selected URL
                parent.selectedURL = resolvedURL
                
                parent.logger.info("Successfully saved bookmark for: \(resolvedURL.path)")
                parent.logger.info("Bookmark key: bookmark_\(pathKey)")
            } catch {
                parent.logger.error("Error creating or resolving bookmark: \(error.localizedDescription)")
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Helper extension to resolve bookmarks
extension URL {
    static func resolveBookmark(_ bookmarkData: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: {
                    #if os(iOS)
                    return []
                    #else
                    return [.withSecurityScope]
                    #endif
                }(),
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                debugLog("Bookmark is stale")
                return nil
            }
            
            return url
        } catch {
            debugLog("Error resolving bookmark: \(error)")
            return nil
        }
    }
}

// Helper function to resolve the saved bookmark
func resolveBookmark() -> URL? {
    guard let bookmarkData = UserDefaults.standard.data(forKey: "selectedFolderBookmark") else {
        return nil
    }
    
    return URL.resolveBookmark(bookmarkData)
}
