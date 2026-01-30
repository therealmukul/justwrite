import SwiftUI

// MARK: - Launch Behavior Setting

enum LaunchBehavior: String, CaseIterable {
    case lastEdited = "lastEdited"
    case newNote = "newNote"

    var displayName: String {
        switch self {
        case .lastEdited: return "Pick up where I left off"
        case .newNote: return "Create new note"
        }
    }

    static var current: LaunchBehavior {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "launchBehavior"),
                  let behavior = LaunchBehavior(rawValue: raw) else {
                return .lastEdited  // Default
            }
            return behavior
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "launchBehavior")
        }
    }
}

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let notesFolderChanged = Notification.Name("notesFolderChanged")
    static let openNoteRequest = Notification.Name("openNoteRequest")
    static let newNoteRequest = Notification.Name("newNoteRequest")
    static let currentDocumentChanged = Notification.Name("currentDocumentChanged")
    static let showFormattingToolbar = Notification.Name("showFormattingToolbar")
    static let hideFormattingToolbar = Notification.Name("hideFormattingToolbar")
    static let applyFormatting = Notification.Name("applyFormatting")
    static let moveCursorToEnd = Notification.Name("moveCursorToEnd")
    static let untitledDocumentBecameDirty = Notification.Name("untitledDocumentBecameDirty")
    static let formattingDidChange = Notification.Name("formattingDidChange")
    static let grammarCheckingChanged = Notification.Name("grammarCheckingChanged")
    static let spellCheckingChanged = Notification.Name("spellCheckingChanged")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Our custom document manager - must be created early to become the shared controller
    let documentManager = TinyWriterDocumentManager()

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
        if documentManager.notesFolder == nil {
            DispatchQueue.main.async {
                self.promptForNotesFolder()
            }
        } else {
            DispatchQueue.main.async {
                self.openBasedOnLaunchBehavior()
            }
        }
    }

    /// Opens a document based on user's launch behavior preference
    private func openBasedOnLaunchBehavior() {
        switch LaunchBehavior.current {
        case .lastEdited:
            // Try to open last edited document
            if let lastURL = documentManager.lastEditedURL,
               FileManager.default.fileExists(atPath: lastURL.path) {
                documentManager.openTinyWriterDocument(at: lastURL) { _ in
                    // Position cursor at end after document loads
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .moveCursorToEnd, object: nil)
                    }
                }
            } else {
                // Fall back to creating new note
                documentManager.createNewTinyWriterDocument()
            }
        case .newNote:
            documentManager.createNewTinyWriterDocument()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save all open documents before termination
        documentManager.saveAllDocuments()
    }

    func promptForNotesFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose your Notes Folder"
        panel.message = "Select a folder where TinyWriter will store your notes"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            documentManager.setNotesFolder(url)
            NotificationCenter.default.post(name: .notesFolderChanged, object: url)
            documentManager.createNewTinyWriterDocument()
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Return false to prevent the default open panel
        // We handle opening in applicationDidFinishLaunching
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows - need to show one
            return showOrCreateWindow()
        }
        return true
    }

    /// Shows an existing window or creates a new one when the dock icon is clicked
    /// Returns true if the system should handle window creation, false if we handled it
    func showOrCreateWindow() -> Bool {
        // Look for our app's main content windows (not system panels, popovers, etc.)
        // SwiftUI WindowGroup windows have specific characteristics
        let appWindows = NSApp.windows.filter { window in
            // Must be able to become main window
            guard window.canBecomeMain else { return false }
            // Must be a regular window (level 0), not a panel or overlay
            guard window.level == .normal else { return false }
            // Must have a content view (empty windows don't count)
            guard window.contentView != nil else { return false }
            // Filter out small windows (likely popovers/tooltips)
            guard window.frame.width > 200 && window.frame.height > 200 else { return false }
            return true
        }

        if let existingWindow = appWindows.first {
            // Found an existing window - show it
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            } else {
                existingWindow.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            return false  // We handled it
        }

        // No existing window - activate app and let system create new WindowGroup instance
        NSApp.activate(ignoringOtherApps: true)

        // Create a new document for the new window
        DispatchQueue.main.async {
            self.documentManager.createNewTinyWriterDocument()
        }

        // Return true so the system creates a new window from WindowGroup
        return true
    }
}

@main
struct TinyWriterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("fontSize") private var fontSize: Double = 16

    private let minFontSize: Double = 12
    private let maxFontSize: Double = 24

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(appDelegate.documentManager)
        }
        .defaultSize(width: 1200, height: 850)
        .commands {
            // Remove the default New menu item and replace with our own
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    appDelegate.documentManager.createNewTinyWriterDocument()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            // Add Save command
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    appDelegate.documentManager.saveCurrentDocumentIfNeeded()
                }
                .keyboardShortcut("s", modifiers: .command)
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

            // Font size controls
            CommandGroup(after: .textFormatting) {
                Button("Increase Font Size") {
                    increaseFontSize()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    decreaseFontSize()
                }
                .keyboardShortcut("-", modifiers: .command)
            }
        }
    }

    private func toggleDistractionFree() {
        guard let window = NSApp.keyWindow else { return }
        window.toggleFullScreen(nil)
    }

    private func increaseFontSize() {
        fontSize = min(fontSize + 1, maxFontSize)
    }

    private func decreaseFontSize() {
        fontSize = max(fontSize - 1, minFontSize)
    }
}
