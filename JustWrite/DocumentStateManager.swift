import Foundation
import AppKit

/// Manages document state, debounced autosave, and crash recovery
class DocumentStateManager: ObservableObject {
    @Published var hasUnsavedChanges: Bool = false

    private var lastSavedText: String = ""
    private var pendingText: String?
    private var debounceTimer: Timer?
    private var currentDocumentURL: URL?

    private let debounceInterval: TimeInterval = 0.5 // 500ms debounce for document saves

    // MARK: - Backup Directory

    private var backupDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("JustWrite")
            .appendingPathComponent("Backups")
    }

    private func backupURL(for documentURL: URL?) -> URL {
        let filename = documentURL?.lastPathComponent ?? "Untitled"
        return backupDirectory.appendingPathComponent(".\(filename).backup")
    }

    // MARK: - Text Change Handling

    /// Called when text changes in the editor. Handles debouncing and backup.
    /// - Parameters:
    ///   - newText: The new text content
    ///   - documentURL: The current document URL (if saved)
    ///   - commitHandler: Closure called after debounce to commit text to document binding
    func textDidChange(newText: String, documentURL: URL?, commitHandler: @escaping (String) -> Void) {
        pendingText = newText
        currentDocumentURL = documentURL
        hasUnsavedChanges = (newText != lastSavedText)

        // Write backup immediately for crash protection
        writeBackup(text: newText, for: documentURL)

        // Debounce the actual document commit
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            guard let self = self, let text = self.pendingText else { return }
            commitHandler(text)
            self.pendingText = nil
        }
    }

    /// Force immediate save of any pending changes. Call before switching notes or creating new.
    /// - Parameter commitHandler: Closure to commit text to document binding
    func flushPendingChanges(commitHandler: @escaping (String) -> Void) {
        debounceTimer?.invalidate()
        debounceTimer = nil

        if let text = pendingText {
            commitHandler(text)
            pendingText = nil
        }
    }

    /// Mark the document as saved. Call after successful save to disk.
    /// - Parameter text: The text that was saved
    func markAsSaved(text: String) {
        lastSavedText = text
        hasUnsavedChanges = false
        pendingText = nil
        clearBackup(for: currentDocumentURL)
    }

    /// Reset state for a new document
    /// - Parameter text: Initial text of the new document
    func resetForNewDocument(text: String) {
        lastSavedText = text
        hasUnsavedChanges = false
        pendingText = nil
        currentDocumentURL = nil
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    /// Update the current document URL (call when document is saved to a new location)
    func setCurrentDocumentURL(_ url: URL?) {
        currentDocumentURL = url
    }

    // MARK: - Backup Management

    private func writeBackup(text: String, for documentURL: URL?) {
        // Create backup directory if needed
        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            return
        }

        let backup = BackupData(
            originalPath: documentURL?.path,
            timestamp: Date(),
            text: text
        )

        let url = backupURL(for: documentURL)

        // Write atomically for safety
        if let data = try? JSONEncoder().encode(backup) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func clearBackup(for documentURL: URL?) {
        let url = backupURL(for: documentURL)
        try? FileManager.default.removeItem(at: url)
    }

    /// Clear all backups (call after successful recovery or discard)
    func clearAllBackups() {
        try? FileManager.default.removeItem(at: backupDirectory)
    }

    // MARK: - Crash Recovery

    /// Check for any crash recovery backups
    /// - Returns: Array of recoverable backups, sorted by timestamp (newest first)
    func checkForRecoveryBackups() -> [BackupData] {
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else {
            return []
        }

        guard let files = try? FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        var backups: [BackupData] = []

        for file in files where file.pathExtension == "backup" {
            if let data = try? Data(contentsOf: file),
               let backup = try? JSONDecoder().decode(BackupData.self, from: data) {
                backups.append(backup)
            }
        }

        // Sort by timestamp, newest first
        return backups.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Backup Data Model

struct BackupData: Codable {
    let originalPath: String?
    let timestamp: Date
    let text: String

    var originalURL: URL? {
        guard let path = originalPath else { return nil }
        return URL(fileURLWithPath: path)
    }

    var displayName: String {
        if let path = originalPath {
            return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        }
        return "Untitled"
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
