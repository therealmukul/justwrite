import SwiftUI
import UniformTypeIdentifiers

// Define markdown UTType if not available
extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
    }
}

struct JustWriteDocument: FileDocument {
    var text: String

    // Support markdown as primary, plus plain text for compatibility
    static var readableContentTypes: [UTType] { [.markdown, .plainText, .text] }
    static var writableContentTypes: [UTType] { [.markdown] }

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }

    // Default to .md extension
    static var defaultFilename: String { "Untitled.md" }
}
