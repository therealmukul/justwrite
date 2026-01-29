import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Manages document lifecycle for TinyWriter.
/// Subclasses NSDocumentController to provide proper document handling
/// while maintaining a single-window UI.
class TinyWriterDocumentManager: NSDocumentController, ObservableObject {

    // MARK: - Published State

    /// The currently active document displayed in the editor
    @Published var activeDocument: TinyWriterDocument?

    /// URL of the notes folder
    @Published var notesFolder: URL?

    /// URL of the last edited document (for launch behavior)
    var lastEditedURL: URL? {
        get {
            guard let bookmarkData = UserDefaults.standard.data(forKey: "lastEditedDocumentURL") else { return nil }
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else { return nil }
            return url
        }
        set {
            if let url = newValue {
                let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: "lastEditedDocumentURL")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastEditedDocumentURL")
            }
        }
    }

    // MARK: - Private State

    /// Cache of open documents by URL
    private var openDocuments: [URL: TinyWriterDocument] = [:]

    /// Tracks untitled documents that haven't been saved to disk yet
    private var untitledDocuments: Set<TinyWriterDocument> = []

    /// Observer for untitled document first edit notification
    private var untitledDocumentObserver: Any?

    // MARK: - Initialization

    override init() {
        super.init()
        loadNotesFolder()
        setupUntitledDocumentObserver()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadNotesFolder()
        setupUntitledDocumentObserver()
    }

    deinit {
        if let observer = untitledDocumentObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Sets up observer for when untitled documents get their first content
    private func setupUntitledDocumentObserver() {
        untitledDocumentObserver = NotificationCenter.default.addObserver(
            forName: .untitledDocumentBecameDirty,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let document = notification.object as? TinyWriterDocument,
                  self.untitledDocuments.contains(document),
                  let folder = self.notesFolder else { return }

            self.assignURLAndSave(document: document, in: folder)
        }
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
    func openTinyWriterDocument(at url: URL, completion: ((TinyWriterDocument?) -> Void)? = nil) {
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

            guard let justWriteDoc = document as? TinyWriterDocument else {
                print("Document is not a TinyWriterDocument")
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
    /// The document starts as an in-memory untitled document.
    /// A file is only created on disk when the user types something.
    func createNewTinyWriterDocument(completion: ((TinyWriterDocument?) -> Void)? = nil) {
        // Check if current document is untitled and empty - discard it
        if let current = activeDocument,
           current.fileURL == nil,
           current.attributedText.length == 0 {
            // Remove empty untitled document
            untitledDocuments.remove(current)
            removeDocument(current)
        } else {
            // Save current document first (only if it has content)
            saveCurrentDocumentIfNeeded()
        }

        guard notesFolder != nil else {
            // No notes folder - create untitled document (existing behavior)
            createUntitledTinyWriterDocument(completion: completion)
            return
        }

        // Create in-memory document without file (deferred file creation)
        let newDocument = TinyWriterDocument()
        addDocument(newDocument)

        // Track as untitled document
        untitledDocuments.insert(newDocument)

        switchToDocument(newDocument)
        completion?(newDocument)
    }

    /// Creates an untitled document (when no notes folder is set).
    private func createUntitledTinyWriterDocument(completion: ((TinyWriterDocument?) -> Void)? = nil) {
        let newDocument = TinyWriterDocument()
        addDocument(newDocument)
        untitledDocuments.insert(newDocument)
        switchToDocument(newDocument)
        completion?(newDocument)
    }

    /// Assigns a URL to an untitled document and saves it to disk.
    /// Called when user types in an untitled document for the first time.
    private func assignURLAndSave(document: TinyWriterDocument, in folder: URL) {
        // Generate unique filename
        let filename = generateUniqueFilename(in: folder)
        let fileURL = folder.appendingPathComponent(filename)

        // Move from untitled set to URL cache
        untitledDocuments.remove(document)
        openDocuments[fileURL] = document

        // Save to the new location
        document.save(to: fileURL, ofType: UTType.rtf.identifier, for: .saveAsOperation) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Error saving new document: \(error)")
                return
            }

            DispatchQueue.main.async {
                // Update window title
                NSApp.keyWindow?.title = fileURL.deletingPathExtension().lastPathComponent
                self.lastEditedURL = fileURL

                // Notify that the current document now has a URL (for sidebar selection)
                NotificationCenter.default.post(name: .currentDocumentChanged, object: fileURL)

                // Notify that a new document was created (for sidebar refresh)
                NotificationCenter.default.post(name: .notesFolderChanged, object: nil)
            }
        }
    }

    // MARK: - Document Switching

    /// Switches to the given document, making it the active document.
    private func switchToDocument(_ document: TinyWriterDocument) {
        DispatchQueue.main.async {
            self.activeDocument = document

            // Update window title and track last edited
            if let url = document.fileURL {
                NSApp.keyWindow?.title = url.deletingPathExtension().lastPathComponent
                self.lastEditedURL = url
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

        // Skip untitled documents with no content
        if current.fileURL == nil && current.attributedText.length == 0 {
            return
        }

        // For untitled documents WITH content, trigger first save
        if current.fileURL == nil, current.attributedText.length > 0, let folder = notesFolder {
            assignURLAndSave(document: current, in: folder)
            return
        }

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
        // Save documents that have URLs
        for document in openDocuments.values {
            guard document.hasUnautosavedChanges else { continue }

            document.autosave(withImplicitCancellability: false) { error in
                if let error = error {
                    print("Autosave error: \(error.localizedDescription)")
                }
            }
        }

        // Save untitled documents that have content
        guard let folder = notesFolder else { return }
        for document in untitledDocuments {
            if document.attributedText.length > 0 {
                assignURLAndSave(document: document, in: folder)
            }
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
        return ["TinyWriterDocument"]
    }

    override var defaultType: String? {
        return UTType.rtf.identifier
    }

    override func documentClass(forType typeName: String) -> AnyClass? {
        return TinyWriterDocument.self
    }

    /// Override to prevent NSDocumentController from creating windows.
    override func openUntitledDocumentAndDisplay(_ displayDocument: Bool) throws -> NSDocument {
        let document = TinyWriterDocument()
        addDocument(document)
        switchToDocument(document)
        return document
    }
}
