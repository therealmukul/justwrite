import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var document: JustWriteDocument
    @State private var showSidebar = false
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Main editor
            MarkdownTextView(text: $document.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))

            // Sliding sidebar from left
            if showSidebar {
                SidebarView(showSidebar: $showSidebar, showSettings: $showSettings)
                    .transition(.move(edge: .leading))
            }
        }
        .overlay(alignment: .topLeading) {
            // Sidebar toggle button (visible when sidebar is hidden)
            if !showSidebar {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showSidebar = true } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(12)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showSidebar.toggle()
            }
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var showSidebar: Bool
    @Binding var showSettings: Bool
    @StateObject private var notesManager = NotesManager()

    private let sidebarWidth: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with close button
            HStack {
                Text("Notes")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showSidebar = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Notes list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    // Current document
                    if let currentURL = notesManager.currentDocumentURL {
                        NoteRow(
                            name: currentURL.deletingPathExtension().lastPathComponent,
                            isSelected: true,
                            action: {}
                        )
                    }

                    // Other recent documents
                    ForEach(notesManager.recentDocuments, id: \.self) { url in
                        if url != notesManager.currentDocumentURL {
                            NoteRow(
                                name: url.deletingPathExtension().lastPathComponent,
                                isSelected: false,
                                action: { notesManager.openDocument(at: url) }
                            )
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // Settings section
            if showSettings {
                SettingsPanel()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider()

            // Gear button at bottom
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showSettings.toggle() } }) {
                HStack {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                    Text("Settings")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: showSettings ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            notesManager.refresh()
        }
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(name.isEmpty ? "Untitled" : name)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Notes Manager

class NotesManager: ObservableObject {
    @Published var recentDocuments: [URL] = []
    @Published var currentDocumentURL: URL?

    init() {
        refresh()
    }

    func refresh() {
        // Get current document URL
        if let currentDoc = NSDocumentController.shared.currentDocument {
            currentDocumentURL = currentDoc.fileURL
        }

        // Get recent documents
        recentDocuments = NSDocumentController.shared.recentDocumentURLs
    }

    func openDocument(at url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
    }
}

// MARK: - Settings Panel

struct SettingsPanel: View {
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Font size
            VStack(alignment: .leading, spacing: 6) {
                Text("Font Size")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Slider(value: $fontSize, in: 12...24, step: 1)
                    Text("\(Int(fontSize))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                }
            }

            // Line spacing
            VStack(alignment: .leading, spacing: 6) {
                Text("Line Spacing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Slider(value: $lineSpacing, in: 0...16, step: 1)
                    Text("\(Int(lineSpacing))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                }
            }
        }
        .padding()
    }
}

// MARK: - Markdown Text View (NSViewRepresentable)

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String

    // Optimal line length: ~65 characters at 16px
    private let optimalTextWidth: CGFloat = 550
    private let verticalPadding: CGFloat = 40
    private let minimumHorizontalPadding: CGFloat = 40

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

        // Text container setup - don't track text view width so we can center manually
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: optimalTextWidth,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Auto-resize
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // Set document view
        scrollView.documentView = textView

        // Set delegate
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.optimalTextWidth = optimalTextWidth
        context.coordinator.verticalPadding = verticalPadding
        context.coordinator.minimumHorizontalPadding = minimumHorizontalPadding

        // Set initial text
        textView.string = text

        // Observe frame changes to update centering
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.frameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )

        // Register for first responder
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            context.coordinator.updateTextInsets()
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

        // Update centering
        context.coordinator.updateTextInsets()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: NSTextView?
        var optimalTextWidth: CGFloat = 550
        var verticalPadding: CGFloat = 40
        var minimumHorizontalPadding: CGFloat = 40

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        @objc func frameDidChange(_ notification: Notification) {
            updateTextInsets()
        }

        func updateTextInsets() {
            guard let textView = textView,
                  let scrollView = textView.enclosingScrollView,
                  let textContainer = textView.textContainer else { return }

            let availableWidth = scrollView.frame.width
            let horizontalInset: CGFloat
            let containerWidth: CGFloat

            if availableWidth > optimalTextWidth + (minimumHorizontalPadding * 2) {
                // Center the text by calculating equal margins
                containerWidth = optimalTextWidth
                horizontalInset = (availableWidth - optimalTextWidth) / 2
            } else {
                // Use minimum padding when window is narrow
                containerWidth = max(100, availableWidth - (minimumHorizontalPadding * 2))
                horizontalInset = minimumHorizontalPadding
            }

            textContainer.containerSize = NSSize(
                width: containerWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.textContainerInset = NSSize(width: horizontalInset, height: verticalPadding)
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
