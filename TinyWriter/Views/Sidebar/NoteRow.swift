import SwiftUI
import AppKit

/// A single row in the notes list sidebar
struct NoteRow: View {
    let name: String
    let url: URL?
    let isSelected: Bool
    let darkMode: Bool
    let action: () -> Void

    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 6
    @AppStorage("fontFamily") private var fontFamily: String = "EB Garamond"
    @AppStorage("lineLength") private var lineLength: Double = 65

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(name.isEmpty ? "Untitled" : name)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appAccent(darkMode: darkMode))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .contextMenu {
            if let url = url {
                Button {
                    renameNote(url: url)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button {
                    exportAsPDF(url: url)
                } label: {
                    Label("Export as PDF", systemImage: "doc.richtext")
                }

                Divider()

                Button(role: .destructive) {
                    deleteNote(url: url)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        // Force arrow cursor for note rows (prevents I-beam from text view)
        .onHover { isHovered in
            if isHovered {
                NSCursor.arrow.set()
            }
        }
    }

    private func renameNote(url: URL) {
        let currentName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        // Create input alert
        let alert = NSAlert()
        alert.messageText = "Rename Note"
        alert.informativeText = "Enter a new name for \"\(currentName)\":"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        // Add text field for input
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = currentName
        textField.placeholderString = "New name"
        alert.accessoryView = textField

        // Make text field first responder and select all text
        alert.window.initialFirstResponder = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

            // Validate new name
            if newName.isEmpty {
                showRenameError(message: "Name cannot be empty")
                return
            }

            if newName.contains(":") || newName.contains("/") {
                showRenameError(message: "Name cannot contain ':' or '/'")
                return
            }

            // Skip if name hasn't changed
            if newName == currentName {
                return
            }

            // Construct new URL
            let newURL = url.deletingLastPathComponent()
                .appendingPathComponent(newName)
                .appendingPathExtension(fileExtension)

            // Check if file already exists
            if FileManager.default.fileExists(atPath: newURL.path) {
                showRenameError(message: "A note named \"\(newName)\" already exists")
                return
            }

            do {
                // Check if this is the currently open document
                let isCurrentDocument = NSDocumentController.shared.currentDocument?.fileURL == url

                // Perform the rename
                try FileManager.default.moveItem(at: url, to: newURL)

                // If we renamed the current document, update it
                if isCurrentDocument {
                    // Open the renamed document
                    if let documentManager = NSDocumentController.shared as? TinyWriterDocumentManager {
                        documentManager.openTinyWriterDocument(at: newURL)
                    }
                }

                // Post notification to refresh the notes list
                NotificationCenter.default.post(name: .notesFolderChanged, object: nil)
            } catch {
                showRenameError(message: error.localizedDescription)
            }
        }
    }

    private func showRenameError(message: String) {
        let errorAlert = NSAlert()
        errorAlert.messageText = "Could not rename note"
        errorAlert.informativeText = message
        errorAlert.alertStyle = .critical
        errorAlert.runModal()
    }

    private func deleteNote(url: URL) {
        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Delete \"\(url.deletingPathExtension().lastPathComponent)\"?"
        alert.informativeText = "This will move the note to the Trash."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                // Check if this is the currently open document
                let isCurrentDocument = NSDocumentController.shared.currentDocument?.fileURL == url

                try FileManager.default.trashItem(at: url, resultingItemURL: nil)

                // If we deleted the current document, clear the editor
                if isCurrentDocument {
                    NotificationCenter.default.post(name: .newNoteRequest, object: nil)
                }

                // Post notification to refresh the notes list
                NotificationCenter.default.post(name: .notesFolderChanged, object: nil)
            } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Could not delete note"
                errorAlert.informativeText = error.localizedDescription
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        }
    }

    private func exportAsPDF(url: URL) {
        PDFExportService.exportAsPDF(
            url: url,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            lineLength: lineLength,
            fontFamily: fontFamily
        )
    }
}
