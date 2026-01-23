import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var document: JustWriteDocument
    @State private var isDistractionFree = false
    @FocusState private var isFocused: Bool

    var body: some View {
        MarkdownTextView(text: $document.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Markdown Text View (NSViewRepresentable)

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor

        // Configure text view for writing
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.insertionPointColor = NSColor.textColor

        // Typography for comfortable writing
        textView.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        textView.defaultParagraphStyle = paragraphStyle

        // Generous margins for focused writing
        textView.textContainerInset = NSSize(width: 60, height: 40)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Auto-resize
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // Set delegate
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        // Set initial text
        textView.string = text

        // Configure scroll view document
        scrollView.documentView = textView

        // Register for first responder to handle formatting commands
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text changed externally
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: NSTextView?

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyMarkdownHighlighting(to: textView)
        }

        // MARK: - Formatting Actions

        @objc func toggleBold() {
            insertMarkdown(prefix: "**", suffix: "**")
        }

        @objc func toggleItalic() {
            insertMarkdown(prefix: "_", suffix: "_")
        }

        @objc func makeHeading1() {
            insertLinePrefix("# ")
        }

        @objc func makeHeading2() {
            insertLinePrefix("## ")
        }

        private func insertMarkdown(prefix: String, suffix: String) {
            guard let textView = textView else { return }

            let selectedRange = textView.selectedRange()
            let selectedText = (textView.string as NSString).substring(with: selectedRange)

            let replacement = "\(prefix)\(selectedText)\(suffix)"
            textView.insertText(replacement, replacementRange: selectedRange)

            // Position cursor inside if no selection
            if selectedRange.length == 0 {
                let newPosition = selectedRange.location + prefix.count
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            }
        }

        private func insertLinePrefix(_ prefix: String) {
            guard let textView = textView else { return }

            let string = textView.string as NSString
            let selectedRange = textView.selectedRange()

            // Find start of current line
            let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let lineStart = lineRange.location

            // Insert prefix at line start
            textView.insertText(prefix, replacementRange: NSRange(location: lineStart, length: 0))
        }

        // MARK: - Markdown Highlighting

        private func applyMarkdownHighlighting(to textView: NSTextView) {
            let string = textView.string
            let fullRange = NSRange(location: 0, length: (string as NSString).length)

            // Reset to default style
            let defaultFont = NSFont.systemFont(ofSize: 16, weight: .regular)
            textView.textStorage?.addAttribute(.font, value: defaultFont, range: fullRange)
            textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)

            // Headings
            highlightPattern(#"^# .+$"#, in: textView, font: .systemFont(ofSize: 24, weight: .bold))
            highlightPattern(#"^## .+$"#, in: textView, font: .systemFont(ofSize: 20, weight: .bold))
            highlightPattern(#"^### .+$"#, in: textView, font: .systemFont(ofSize: 18, weight: .semibold))

            // Bold
            highlightPattern(#"\*\*[^*]+\*\*"#, in: textView, font: .systemFont(ofSize: 16, weight: .bold))

            // Italic
            let italicFont = NSFontManager.shared.convert(defaultFont, toHaveTrait: .italicFontMask)
            highlightPattern(#"_[^_]+_"#, in: textView, font: italicFont)
        }

        private func highlightPattern(_ pattern: String, in textView: NSTextView, font: NSFont) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return }
            let string = textView.string
            let range = NSRange(location: 0, length: (string as NSString).length)

            regex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    textView.textStorage?.addAttribute(.font, value: font, range: matchRange)
                }
            }
        }
    }
}

#Preview {
    ContentView(document: .constant(JustWriteDocument(text: "# Welcome to JustWrite\n\nStart writing...")))
}
