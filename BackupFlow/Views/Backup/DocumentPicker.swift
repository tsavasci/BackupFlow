import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var url: URL?
    var onDismiss: () -> Void = {}
    
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
        documentPicker.delegate = context.coordinator
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedURL = urls.first else { return }
            
            let path = selectedURL.path
            print("📁 Selected path: \(path)")
            
            // Start accessing security scoped resource
            let isScoped = selectedURL.startAccessingSecurityScopedResource()
            print("🔑 Security scoped access started: \(isScoped)")
            
            defer {
                if isScoped {
                    selectedURL.stopAccessingSecurityScopedResource()
                    print("🔒 Security scoped access stopped")
                }
            }
            
            // Save bookmark before updating the URL
            do {
                // For iOS, use minimal bookmark; macOS uses security-scoped bookmark
                let bookmark = try selectedURL.bookmarkData(
                    options: parent.bookmarkCreationOptions,
                    includingResourceValuesForKeys: [.isDirectoryKey, .nameKey],
                    relativeTo: nil
                )
                
                // Save general bookmark
                UserDefaults.standard.set(bookmark, forKey: "selectedFolderBookmark")
                print("💾 General bookmark saved")
                
                // Generate key from path for saving bookmark
                let bookmarkKey = "folder_bookmark_\(path.replacingOccurrences(of: "/", with: "_"))"
                
                UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
                UserDefaults.standard.set(path, forKey: "folder_bookmark_path_\(bookmarkKey)")
                
                print("💾 Bookmark saved for path: \(path)")
                print("🔑 Bookmark key: \(bookmarkKey)")
                
                // Test bookmark resolution immediately
                do {
                    var isStale = false
                    let resolvedURL = try URL(
                        resolvingBookmarkData: bookmark,
                        options: parent.bookmarkResolutionOptions,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    
                    print("✅ Bookmark resolution test successful: \(resolvedURL.path)")
                    print("� Resolved URL: \(resolvedURL)")
                    
                    // Also save using FileAccessManager
                    do {
                        try FileAccessManager.shared.saveBookmark(for: selectedURL, key: path)
                        print("💾 Bookmark also saved via FileAccessManager")
                    } catch {
                        print("⚠️ FileAccessManager bookmark save failed: \(error)")
                    }
                    
                } catch {
                    print("❌ Bookmark resolution test failed: \(error)")
                }
                
                // Store the URL
                parent.url = selectedURL
                
            } catch {
                print("❌ Failed to create bookmark: \(error)")
                // Still store the URL even if bookmark creation fails
                parent.url = selectedURL
            }
            
            parent.onDismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onDismiss()
        }
    }
}
