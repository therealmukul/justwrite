import SwiftUI

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let notesFolderChanged = Notification.Name("notesFolderChanged")
    static let openNoteRequest = Notification.Name("openNoteRequest")
    static let newNoteRequest = Notification.Name("newNoteRequest")
    static let currentDocumentChanged = Notification.Name("currentDocumentChanged")
    static let showFormattingToolbar = Notification.Name("showFormattingToolbar")
    static let hideFormattingToolbar = Notification.Name("hideFormattingToolbar")
    static let applyFormatting = Notification.Name("applyFormatting")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hasLaunched = false

    static let notesFolderKey = "notesFolder"

    var notesFolder: URL? {
        get {
            guard let bookmarkData = UserDefaults.standard.data(forKey: Self.notesFolderKey) else { return nil }
            var isStale = false
            return try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
        }
        set {
            if let url = newValue {
                let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: Self.notesFolderKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.notesFolderKey)
            }
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Disable tabs - single document at a time
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable tabbing on all windows
        for window in NSApp.windows {
            window.tabbingMode = .disallowed
        }

        // Check if this is first launch (no notes folder set)
        if notesFolder == nil {
            DispatchQueue.main.async {
                self.promptForNotesFolder()
            }
        } else {
            // Always start with a fresh new note
            DispatchQueue.main.async {
                self.createNewNoteInFolder()
            }
        }

        hasLaunched = true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Force flush any pending changes before termination
        NotificationCenter.default.post(name: Notification.Name("flushPendingChanges"), object: nil)
    }

    func promptForNotesFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose your Notes Folder"
        panel.message = "Select a folder where JustWrite will store your notes"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            // Start accessing security-scoped resource
            _ = url.startAccessingSecurityScopedResource()
            notesFolder = url
            NotificationCenter.default.post(name: .notesFolderChanged, object: url)
            createNewNoteInFolder()
        }
    }

    func createNewNoteInFolder() {
        guard let folder = notesFolder else {
            // No folder set, just create untitled
            NSDocumentController.shared.newDocument(nil)
            return
        }

        // Access the security-scoped resource
        _ = folder.startAccessingSecurityScopedResource()

        // Create a new document in the notes folder
        do {
            try NSDocumentController.shared.openUntitledDocumentAndDisplay(true)
        } catch {
            NSDocumentController.shared.newDocument(nil)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Return false to prevent the default open panel
        // We handle opening in applicationDidFinishLaunching
        return !hasLaunched
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Always create a fresh new note when app is reopened
            createNewNoteInFolder()
            return false
        }
        return true
    }
}

@main
struct JustWriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: JustWriteDocument()) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: 1200, height: 850)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .newNoteRequest, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)
            }
            CommandGroup(after: .windowArrangement) {
                Button("Distraction Free") {
                    toggleDistractionFree()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }

    private func toggleDistractionFree() {
        guard let window = NSApp.keyWindow else { return }
        window.toggleFullScreen(nil)
    }
}
