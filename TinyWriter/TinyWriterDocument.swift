import SwiftUI
import UniformTypeIdentifiers
import AppKit

class TinyWriterDocument: NSDocument, ObservableObject {
    /// Internal storage for attributed text
    private var _attributedText: NSAttributedString = NSAttributedString()

    /// Flag to suppress dirty marking during document loading
    private var isLoading = false

    /// The document's attributed text content.
    /// Setting this property marks the document as dirty (needing save).
    var attributedText: NSAttributedString {
        get { _attributedText }
        set {
            let oldValue = _attributedText
            _attributedText = newValue
            // Publish the change for SwiftUI
            objectWillChange.send()
            // Don't mark dirty during loading - the document is being populated from disk
            guard !isLoading else { return }
            // Mark document as having unsaved changes when content or formatting changes
            // Compare both string content AND attributes for formatting changes
            if !oldValue.isEqual(to: newValue) {
                updateChangeCount(.changeDone)
            }
        }
    }

    // MARK: - NSDocument Configuration

    override class var autosavesInPlace: Bool { true }
    override class var autosavesDrafts: Bool { true }

    // MARK: - Initialization

    override init() {
        super.init()
        // Initialize with empty attributed string with default attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.textColor
        ]
        self.attributedText = NSAttributedString(string: "", attributes: attributes)
    }

    convenience init(text: String) {
        self.init()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.textColor
        ]
        self.attributedText = NSAttributedString(string: text, attributes: attributes)
    }

    // MARK: - NSDocument Reading

    override func read(from data: Data, ofType typeName: String) throws {
        // Try to read as RTF first
        if let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
            DispatchQueue.main.async {
                // Suppress dirty marking while loading
                self.isLoading = true
                self.attributedText = attributed
                self.isLoading = false
            }
        } else {
            // Fall back to plain text
            let text = String(decoding: data, as: UTF8.self)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.textColor
            ]
            DispatchQueue.main.async {
                // Suppress dirty marking while loading
                self.isLoading = true
                self.attributedText = NSAttributedString(string: text, attributes: attributes)
                self.isLoading = false
            }
        }
    }

    // MARK: - NSDocument Writing

    override func data(ofType typeName: String) throws -> Data {
        let range = NSRange(location: 0, length: attributedText.length)
        guard let data = attributedText.rtf(from: range, documentAttributes: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    // MARK: - Window Controllers

    override func makeWindowControllers() {
        // Empty - we manage the single window via WindowGroup
        // This prevents NSDocument from creating its own windows
    }

    // MARK: - Readable/Writable Types

    override class var readableTypes: [String] {
        return [UTType.rtf.identifier, UTType.plainText.identifier, UTType.text.identifier]
    }

    override class var writableTypes: [String] {
        return [UTType.rtf.identifier]
    }

    override class func isNativeType(_ type: String) -> Bool {
        return type == UTType.rtf.identifier
    }

    // MARK: - Plain Text Accessor (for compatibility)

    var text: String {
        get {
            attributedText.string
        }
        set {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.textColor
            ]
            attributedText = NSAttributedString(string: newValue, attributes: attributes)
        }
    }
}
