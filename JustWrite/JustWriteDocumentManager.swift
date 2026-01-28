import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// Manages document lifecycle for JustWrite.
/// Subclasses NSDocumentController to provide proper document handling
/// while maintaining a single-window UI.
class JustWriteDocumentManager: NSDocumentController, ObservableObject {

    // MARK: - Published State

    /// The currently active document displayed in the editor
    @Published var activeDocument: JustWriteDocument?

    /// URL of the notes folder
    @Published var notesFolder: URL?

    // MARK: - Private State

    /// Cache of open documents by URL
    private var openDocuments: [URL: JustWriteDocument] = [:]

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    override init() {
        super.init()
        loadNotesFolder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadNotesFolder()
    }

    // MARK: - Notes Folder Management

    private func loadNotesFolder() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "notesFolder") else { return }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else { return }
        _ = url.startAccessingSecurityScopedResource()
        notesFolder = url
    }

    func setNotesFolder(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmarkData, forKey: "notesFolder")
        notesFolder = url
    }

    // MARK: - Document Opening

    /// Opens a document at the given URL, switching to it as the active document.
    /// If the document is already open, switches to the cached instance.
    func openJustWriteDocument(at url: URL, completion: ((JustWriteDocument?) -> Void)? = nil) {
        // Save current document if it has unsaved changes
        saveCurrentDocumentIfNeeded()

        // Check if already cached
        if let cached = openDocuments[url] {
            switchToDocument(cached)
            completion?(cached)
            return
        }

        // Open via NSDocumentController
        super.openDocument(withContentsOf: url, display: false) { [weak self] document, wasAlreadyOpen, error in
            guard let self = self else { return }

            if let error = error {
                print("Error opening document: \(error)")
                DispatchQueue.main.async {
                    completion?(nil)
                }
                return
            }

            guard let justWriteDoc = document as? JustWriteDocument else {
                print("Document is not a JustWriteDocument")
                DispatchQueue.main.async {
                    completion?(nil)
                }
                return
            }

            // Cache and switch to the document
            DispatchQueue.main.async {
                self.openDocuments[url] = justWriteDoc
                self.switchToDocument(justWriteDoc)
                completion?(justWriteDoc)
            }
        }
    }

    // MARK: - Document Creation

    /// Creates a new document in the notes folder.
    func createNewJustWriteDocument(completion: ((JustWriteDocument?) -> Void)? = nil) {
        // Save current document first
        saveCurrentDocumentIfNeeded()

        guard let folder = notesFolder else {
            // No notes folder - create untitled document
            createUntitledJustWriteDocument(completion: completion)
            return
        }

        // Generate unique filename
        let filename = generateUniqueFilename(in: folder)
        let fileURL = folder.appendingPathComponent(filename)

        // Create new document
        let newDocument = JustWriteDocument()
        addDocument(newDocument)

        // Save to the new location
        newDocument.save(to: fileURL, ofType: UTType.rtf.identifier, for: .saveAsOperation) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Error saving new document: \(error)")
                DispatchQueue.main.async {
                    completion?(nil)
                }
                return
            }

            DispatchQueue.main.async {
                self.openDocuments[fileURL] = newDocument
                self.switchToDocument(newDocument)
                completion?(newDocument)

                // Notify that a new document was created
                NotificationCenter.default.post(name: .notesFolderChanged, object: nil)
            }
        }
    }

    /// Creates an untitled document (when no notes folder is set).
    private func createUntitledJustWriteDocument(completion: ((JustWriteDocument?) -> Void)? = nil) {
        let newDocument = JustWriteDocument()
        addDocument(newDocument)
        switchToDocument(newDocument)
        completion?(newDocument)
    }

    // MARK: - Document Switching

    /// Switches to the given document, making it the active document.
    private func switchToDocument(_ document: JustWriteDocument) {
        DispatchQueue.main.async {
            self.activeDocument = document

            // Update window title
            if let url = document.fileURL {
                NSApp.keyWindow?.title = url.deletingPathExtension().lastPathComponent
            } else {
                NSApp.keyWindow?.title = "Untitled"
            }

            // Post notification for other components
            NotificationCenter.default.post(name: .currentDocumentChanged, object: document.fileURL)
        }
    }

    // MARK: - Document Saving

    /// Triggers an autosave for the current document if it has unsaved changes.
    /// This is non-blocking - NSDocument's autosave mechanism handles persistence.
    func saveCurrentDocumentIfNeeded() {
        guard let current = activeDocument else { return }
        guard current.hasUnautosavedChanges else { return }

        // Trigger autosave - this is non-blocking and handled by NSDocument
        current.autosave(withImplicitCancellability: false) { error in
            if let error = error {
                print("Autosave error: \(error.localizedDescription)")
            }
        }
    }

    /// Triggers saves for all open documents with unsaved changes.
    /// Non-blocking - relies on NSDocument's autosave mechanism.
    func saveAllDocuments() {
        for document in openDocuments.values {
            guard document.hasUnautosavedChanges else { continue }

            document.autosave(withImplicitCancellability: false) { error in
                if let error = error {
                    print("Autosave error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Document Closing

    /// Closes a document and removes it from the cache.
    func closeJustWriteDocument(_ document: JustWriteDocument) {
        // Save if needed
        if document.hasUnautosavedChanges {
            document.save(nil)
        }

        // Remove from cache
        if let url = document.fileURL {
            openDocuments.removeValue(forKey: url)
        }

        // Close the document
        document.close()

        // If this was the active document, clear it
        if activeDocument === document {
            activeDocument = nil
        }
    }

    // MARK: - Helper Methods

    /// Generates a unique filename for a new document.
    private func generateUniqueFilename(in folder: URL) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH.mm.ss"
        let timestamp = formatter.string(from: Date())

        var filename = "\(timestamp).rtf"
        var fileURL = folder.appendingPathComponent(filename)

        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            filename = "\(timestamp) (\(counter)).rtf"
            fileURL = folder.appendingPathComponent(filename)
            counter += 1
        }

        return filename
    }

    // MARK: - NSDocumentController Overrides

    /// Override to return our custom document class.
    override var documentClassNames: [String] {
        return ["JustWriteDocument"]
    }

    override var defaultType: String? {
        return UTType.rtf.identifier
    }

    override func documentClass(forType typeName: String) -> AnyClass? {
        return JustWriteDocument.self
    }

    /// Override to prevent NSDocumentController from creating windows.
    override func openUntitledDocumentAndDisplay(_ displayDocument: Bool) throws -> NSDocument {
        let document = JustWriteDocument()
        addDocument(document)
        switchToDocument(document)
        return document
    }
}
