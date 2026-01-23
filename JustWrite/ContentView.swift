import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var document: JustWriteDocument
    @State private var showSidebar = false
    @State private var showSettings = false
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 6
    @AppStorage("lineLength") private var lineLength: Double = 65

    var body: some View {
        ZStack(alignment: .leading) {
            // Main editor
            MarkdownTextView(text: $document.text, fontSize: fontSize, lineSpacing: lineSpacing, lineLength: lineLength)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))

            // Sliding sidebar from left
            if showSidebar {
                SidebarView(showSidebar: $showSidebar, showSettings: $showSettings)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            // Sidebar toggle button with Liquid Glass (visible when sidebar is hidden)
            if !showSidebar {
                Button(action: { withAnimation(.bouncy) { showSidebar = true } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .padding(12)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.bouncy) {
                showSidebar.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNoteRequest)) { notification in
            guard let url = notification.object as? URL else { return }
            loadNote(from: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newNoteRequest)) { _ in
            createNewNote()
        }
    }

    private func createNewNote() {
        // Just clear the editor - don't touch any files
        // User will manually save with Cmd+S when ready
        document.text = ""

        // Clear the document's file URL so Cmd+S triggers save dialog
        if let currentDoc = NSDocumentController.shared.currentDocument {
            currentDoc.fileURL = nil
        }

        // Update window title
        NSApp.keyWindow?.title = "Untitled"

        // Notify that current document changed (now untitled)
        NotificationCenter.default.post(name: .currentDocumentChanged, object: nil)
    }

    private func loadNote(from url: URL) {
        guard let currentDoc = NSDocumentController.shared.currentDocument else { return }

        do {
            // Set the file URL first
            currentDoc.fileURL = url

            // Use revert to properly load the file and update modification tracking
            // This prevents "file changed by another application" warnings
            try currentDoc.revert(toContentsOf: url, ofType: url.pathExtension == "md" ? "net.daringfireball.markdown" : "public.plain-text")

            // Update window title
            NSApp.keyWindow?.title = url.deletingPathExtension().lastPathComponent

            // Notify that current document changed
            NotificationCenter.default.post(name: .currentDocumentChanged, object: url)
        } catch {
            // Fallback: just read the content directly
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                document.text = content
                NSApp.keyWindow?.title = url.deletingPathExtension().lastPathComponent
                NotificationCenter.default.post(name: .currentDocumentChanged, object: url)
            }
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var showSidebar: Bool
    @Binding var showSettings: Bool
    @StateObject private var notesManager = NotesManager()

    private let sidebarWidth: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with close button
            HStack {
                Text("Notes")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: { withAnimation(.bouncy) { showSidebar = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Notes list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    // Current document (if not in folder list)
                    if let currentURL = notesManager.currentDocumentURL,
                       !notesManager.notesInFolder.contains(currentURL) {
                        NoteRow(
                            name: currentURL.deletingPathExtension().lastPathComponent,
                            isSelected: true,
                            action: {}
                        )
                    }

                    // Notes from folder
                    ForEach(notesManager.notesInFolder, id: \.self) { url in
                        NoteRow(
                            name: url.deletingPathExtension().lastPathComponent,
                            isSelected: url == notesManager.currentDocumentURL,
                            action: { notesManager.openDocument(at: url) }
                        )
                    }

                    // Empty state
                    if notesManager.notesInFolder.isEmpty && notesManager.currentDocumentURL == nil {
                        Text("No notes yet")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // Settings section
            if showSettings {
                SettingsPanel(notesManager: notesManager)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Gear button at bottom with Liquid Glass
            GlassEffectContainer {
                Button(action: { withAnimation(.bouncy) { showSettings.toggle() } }) {
                    HStack {
                        Image(systemName: "gear")
                            .font(.system(size: 14, weight: .medium))
                        Text("Settings")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: showSettings ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity)
        .background {
            // Liquid Glass sidebar background
            Rectangle()
                .fill(.ultraThinMaterial)
        }
        .onAppear {
            notesManager.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .notesFolderChanged)) { _ in
            notesManager.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .currentDocumentChanged)) { notification in
            notesManager.currentDocumentURL = notification.object as? URL
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
                        .fill(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Notes Manager

class NotesManager: ObservableObject {
    @Published var notesInFolder: [URL] = []
    @Published var currentDocumentURL: URL?
    @Published var notesFolder: URL?

    private var folderObserver: Any?
    private var documentObserver: Any?

    init() {
        refresh()

        // Listen for folder changes
        folderObserver = NotificationCenter.default.addObserver(
            forName: .notesFolderChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }

        // Listen for current document changes
        documentObserver = NotificationCenter.default.addObserver(
            forName: .currentDocumentChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.currentDocumentURL = notification.object as? URL
        }
    }

    deinit {
        if let observer = folderObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = documentObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func refresh() {
        // Get current document URL
        if let currentDoc = NSDocumentController.shared.currentDocument {
            currentDocumentURL = currentDoc.fileURL
        }

        // Get notes folder from UserDefaults
        if let bookmarkData = UserDefaults.standard.data(forKey: "notesFolder") {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                notesFolder = url
                _ = url.startAccessingSecurityScopedResource()
                loadNotesFromFolder(url)
            }
        }
    }

    private func loadNotesFromFolder(_ folder: URL) {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            // Filter for text files and sort by modification date (newest first)
            notesInFolder = contents
                .filter { url in
                    let ext = url.pathExtension.lowercased()
                    return ext == "txt" || ext == "md" || ext == "markdown" || ext.isEmpty
                }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            notesInFolder = []
        }
    }

    func openDocument(at url: URL) {
        // Post notification to request opening this note
        // The ContentView will handle loading the content
        NotificationCenter.default.post(name: .openNoteRequest, object: url)
        currentDocumentURL = url
        UserDefaults.standard.set(url.path, forKey: "lastOpenedDocument")
    }

    func changeNotesFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Notes Folder"
        panel.message = "Select a folder for your notes"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            _ = url.startAccessingSecurityScopedResource()
            let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "notesFolder")
            notesFolder = url
            NotificationCenter.default.post(name: .notesFolderChanged, object: url)
            loadNotesFromFolder(url)
        }
    }
}

// MARK: - Settings Panel

struct SettingsPanel: View {
    @ObservedObject var notesManager: NotesManager
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 6
    @AppStorage("lineLength") private var lineLength: Double = 65

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Notes folder
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes Folder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Text(notesManager.notesFolder?.lastPathComponent ?? "Not set")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Button("Change") {
                        notesManager.changeNotesFolder()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
            }

            Divider()

            // Font size
            VStack(alignment: .leading, spacing: 6) {
                Text("Font Size")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Slider(value: $fontSize, in: 12...24, step: 1)
                        .tint(.accentColor)
                    Text("\(Int(fontSize))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                }
            }

            // Line spacing
            VStack(alignment: .leading, spacing: 6) {
                Text("Line Spacing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Slider(value: $lineSpacing, in: 0...16, step: 1)
                        .tint(.accentColor)
                    Text("\(Int(lineSpacing))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                }
            }

            // Line length
            VStack(alignment: .leading, spacing: 6) {
                Text("Line Length")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Slider(value: $lineLength, in: 40...80, step: 1)
                        .tint(.accentColor)
                    Text("\(Int(lineLength))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Markdown Text View (NSViewRepresentable)

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    var lineSpacing: Double
    var lineLength: Double

    // Calculate text width based on line length and font size
    // Average character width is approximately 0.55 * fontSize for system font
    private var optimalTextWidth: CGFloat {
        CGFloat(lineLength) * CGFloat(fontSize) * 0.55
    }
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
        textView.font = NSFont.systemFont(ofSize: CGFloat(fontSize), weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(lineSpacing)
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

        // Update coordinator's parent reference so it has current values
        context.coordinator.parent = self

        // Only update if text changed externally
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        // Update font size
        let newFont = NSFont.systemFont(ofSize: CGFloat(fontSize), weight: .regular)
        if textView.font?.pointSize != CGFloat(fontSize) {
            textView.font = newFont
            // Update all existing text with new font
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.addAttribute(.font, value: newFont, range: NSRange(location: 0, length: textStorage.length))
            }
        }

        // Update line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(lineSpacing)
        if textView.defaultParagraphStyle?.lineSpacing != CGFloat(lineSpacing) {
            textView.defaultParagraphStyle = paragraphStyle
            // Update all existing text with new line spacing
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: textStorage.length))
            }
        }

        // Update centering
        context.coordinator.updateTextInsets()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: NSTextView?
        var verticalPadding: CGFloat = 40
        var minimumHorizontalPadding: CGFloat = 40

        var optimalTextWidth: CGFloat {
            parent.optimalTextWidth
        }

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

            let baseFontSize = CGFloat(parent.fontSize)

            // Reset to default style
            let defaultFont = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
            textView.textStorage?.addAttribute(.font, value: defaultFont, range: fullRange)
            textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)

            // Apply line spacing
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = CGFloat(parent.lineSpacing)
            textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

            // Headings (scale relative to base font size)
            highlightPattern(#"^# .+$"#, in: textView, font: .systemFont(ofSize: baseFontSize * 1.5, weight: .bold))
            highlightPattern(#"^## .+$"#, in: textView, font: .systemFont(ofSize: baseFontSize * 1.25, weight: .bold))
            highlightPattern(#"^### .+$"#, in: textView, font: .systemFont(ofSize: baseFontSize * 1.125, weight: .semibold))

            // Bold
            highlightPattern(#"\*\*[^*]+\*\*"#, in: textView, font: .systemFont(ofSize: baseFontSize, weight: .bold))

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
