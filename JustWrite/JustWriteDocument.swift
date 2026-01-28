import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct JustWriteDocument: FileDocument {
    var attributedText: NSAttributedString

    // Support RTF as primary, with RTF and plain text for reading
    static var readableContentTypes: [UTType] { [.rtf, .plainText, .text] }
    static var writableContentTypes: [UTType] { [.rtf] }

    init(text: String = "") {
        // Create attributed string with default attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.textColor
        ]
        self.attributedText = NSAttributedString(string: text, attributes: attributes)
    }

    init(attributedText: NSAttributedString) {
        self.attributedText = attributedText
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Try to read as RTF first
        if let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
            self.attributedText = attributed
        } else {
            // Fall back to plain text
            let text = String(decoding: data, as: UTF8.self)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.textColor
            ]
            self.attributedText = NSAttributedString(string: text, attributes: attributes)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let range = NSRange(location: 0, length: attributedText.length)
        guard let data = attributedText.rtf(from: range, documentAttributes: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }

    // Plain text accessor for compatibility
    var text: String {
        get {
            attributedText.string
        }
        set {
            // Create attributed string with default formatting
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.textColor
            ]
            attributedText = NSAttributedString(string: newValue, attributes: attributes)
        }
    }
}
