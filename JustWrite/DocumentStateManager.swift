import Foundation
import AppKit

/// Manages document state and debounced autosave
class DocumentStateManager: ObservableObject {
    @Published var hasUnsavedChanges: Bool = false

    private var lastSavedText: String = ""
    private var pendingText: String?
    private var debounceTimer: Timer?
    private var currentDocumentURL: URL?

    private let debounceInterval: TimeInterval = 0.5 // 500ms debounce for document saves

    // MARK: - Text Change Handling

    /// Called when text changes in the editor. Handles debouncing.
    /// - Parameters:
    ///   - newText: The new text content
    ///   - documentURL: The current document URL (if saved)
    ///   - commitHandler: Closure called after debounce to commit text to document binding
    func textDidChange(newText: String, documentURL: URL?, commitHandler: @escaping (String) -> Void) {
        pendingText = newText
        currentDocumentURL = documentURL
        hasUnsavedChanges = (newText != lastSavedText)

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
}
