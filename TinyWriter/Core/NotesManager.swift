import Foundation
import AppKit

/// Manages the sidebar's notes list, folder monitoring, and session state
class NotesManager: ObservableObject {
    @Published var notesInFolder: [URL] = []
    @Published var currentDocumentURL: URL?
    @Published var notesFolder: URL?
    @Published var sessionDocuments: Set<URL> = []  // Track all documents opened/saved this session

    private var folderObserver: Any?
    private var documentObserver: Any?
    private var saveObserver: Any?
    private var folderMonitor: DispatchSourceFileSystemObject?
    private var monitoredFolderDescriptor: Int32 = -1

    init() {
        refresh()

        // Listen for folder changes
        folderObserver = NotificationCenter.default.addObserver(
            forName: .notesFolderChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
            self?.setupFolderMonitor()
        }

        // Listen for current document changes
        documentObserver = NotificationCenter.default.addObserver(
            forName: .currentDocumentChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let url = notification.object as? URL {
                self?.currentDocumentURL = url
                self?.sessionDocuments.insert(url)
            } else {
                self?.currentDocumentURL = nil
            }
            self?.refresh()
        }

        // Listen for document save notifications
        saveObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSDocumentDidSaveNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Track saved document
            if let document = notification.object as? NSDocument,
               let url = document.fileURL {
                self?.sessionDocuments.insert(url)
            }
            // Delay slightly to ensure file system has updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.refresh()
            }
        }

        // Setup folder monitoring
        setupFolderMonitor()
    }

    deinit {
        if let observer = folderObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = documentObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = saveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopFolderMonitor()
    }

    private func setupFolderMonitor() {
        // Stop existing monitor
        stopFolderMonitor()

        guard let folder = notesFolder else { return }

        // Open folder for monitoring
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        monitoredFolderDescriptor = fd

        // Create dispatch source to monitor folder
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.refresh()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        folderMonitor = source
    }

    private func stopFolderMonitor() {
        folderMonitor?.cancel()
        folderMonitor = nil
        if monitoredFolderDescriptor >= 0 {
            // Descriptor will be closed by cancel handler
            monitoredFolderDescriptor = -1
        }
    }

    func refresh() {
        // Note: currentDocumentURL is managed by .currentDocumentChanged notifications
        // from TinyWriterDocumentManager, NOT from NSDocumentController.shared.currentDocument
        // This ensures the sidebar selection stays in sync with the actual active document

        // Get notes folder from UserDefaults
        if let bookmarkData = UserDefaults.standard.data(forKey: "notesFolder") {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                let folderChanged = notesFolder != url
                notesFolder = url
                _ = url.startAccessingSecurityScopedResource()
                loadNotesFromFolder(url)

                // Setup monitor if folder changed or not yet monitoring
                if folderChanged || folderMonitor == nil {
                    setupFolderMonitor()
                }
            }
        }
    }

    private func loadNotesFromFolder(_ folder: URL) {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            // Filter for RTF and text files, sort by modification date (newest first)
            notesInFolder = contents
                .filter { url in
                    let ext = url.pathExtension.lowercased()
                    return ext == "rtf" || ext == "txt" || ext.isEmpty
                }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            notesInFolder = []
        }
    }

    func openDocument(at url: URL) {
        // Post notification to request opening this note
        // The ContentView will handle loading the content
        NotificationCenter.default.post(name: .openNoteRequest, object: url)
        currentDocumentURL = url
    }

    func changeNotesFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Notes Folder"
        panel.message = "Select a folder for your notes"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            _ = url.startAccessingSecurityScopedResource()
            let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "notesFolder")
            notesFolder = url
            NotificationCenter.default.post(name: .notesFolderChanged, object: url)
            loadNotesFromFolder(url)
        }
    }
}
