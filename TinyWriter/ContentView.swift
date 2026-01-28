import SwiftUI
import AppKit
import QuartzCore


// Custom accent colors
extension Color {
    // Light mode: #800020 (deep burgundy)
    static let appAccentLight = Color(red: 0x80 / 255.0, green: 0x00 / 255.0, blue: 0x20 / 255.0)
    // Dark mode: #C94C66 (rose-burgundy)
    static let appAccentDark = Color(red: 0xC9 / 255.0, green: 0x4C / 255.0, blue: 0x66 / 255.0)

    static func appAccent(darkMode: Bool) -> Color {
        darkMode ? .appAccentDark : .appAccentLight
    }
}

// MARK: - Formatting Toolbar

struct FormattingToolbar: View {
    var body: some View {
        HStack(spacing: 2) {
            // Bold & Italic only
            FormatButton(label: "B", fontWeight: .bold, action: { applyFormat("bold") })
            FormatButton(label: "I", isItalic: true, action: { applyFormat("italic") })
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        }
    }

    private func applyFormat(_ format: String) {
        NotificationCenter.default.post(
            name: .applyFormatting,
            object: nil,
            userInfo: ["format": format]
        )
        // Hide toolbar after applying format
        NotificationCenter.default.post(name: .hideFormattingToolbar, object: nil)
    }
}

struct FormatButton: View {
    let label: String
    var fontWeight: Font.Weight = .semibold
    var isItalic: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: fontWeight))
                .italic(isItalic)
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}


struct ContentView: View {
    @EnvironmentObject var documentManager: TinyWriterDocumentManager
    @State private var showSidebar = false
    @State private var showSettings = false
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 6
    @AppStorage("lineLength") private var lineLength: Double = 65
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("fontFamily") private var fontFamily: String = "EB Garamond"
    @AppStorage("showWordCount") private var showWordCount: Bool = true

    // Formatting toolbar state
    @State private var showFormattingToolbar = false
    @State private var toolbarPosition: CGPoint = .zero

    // Binding to active document's attributed text
    private var attributedTextBinding: Binding<NSAttributedString> {
        Binding(
            get: { documentManager.activeDocument?.attributedText ?? NSAttributedString() },
            set: { newValue in
                documentManager.activeDocument?.attributedText = newValue
            }
        )
    }

    // Word count calculation
    private var wordCount: Int {
        let text = (documentManager.activeDocument?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return 0 }
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private var characterCount: Int {
        documentManager.activeDocument?.text.count ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Main editor
                RichTextView(attributedText: attributedTextBinding, fontSize: fontSize, lineSpacing: lineSpacing, lineLength: lineLength, darkMode: darkMode, fontFamily: fontFamily)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(darkMode ? Color.black : Color(NSColor.textBackgroundColor))

                // Sliding sidebar from left
                if showSidebar {
                    SidebarView(showSidebar: $showSidebar, showSettings: $showSettings)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                // Floating formatting toolbar
                if showFormattingToolbar {
                    FormattingToolbar()
                        .position(x: toolbarPosition.x, y: toolbarPosition.y - 50)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showFormattingToolbar)) { notification in
                if let userInfo = notification.userInfo,
                   let rect = userInfo["selectionRect"] as? NSRect {
                    withAnimation(.easeOut(duration: 0.15)) {
                        // Convert from AppKit window coordinates (origin bottom-left)
                        // to SwiftUI coordinates (origin top-left)
                        let windowHeight = NSApp.keyWindow?.frame.height ?? geometry.size.height
                        let swiftUIY = windowHeight - rect.maxY
                        toolbarPosition = CGPoint(x: rect.midX, y: swiftUIY)
                        showFormattingToolbar = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .hideFormattingToolbar)) { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    showFormattingToolbar = false
                }
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
        .overlay(alignment: .bottomTrailing) {
            // Word counter
            if showWordCount {
                HStack(spacing: 12) {
                    Label("\(wordCount)", systemImage: "text.word.spacing")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                    Label("\(characterCount)", systemImage: "character.cursor.ibeam")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(darkMode ? .white.opacity(0.5) : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(darkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                }
                .padding(16)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.bouncy) {
                showSidebar.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNoteRequest)) { notification in
            guard let url = notification.object as? URL else { return }
            documentManager.openTinyWriterDocument(at: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newNoteRequest)) { _ in
            documentManager.createNewTinyWriterDocument()
        }
        .onChange(of: documentManager.activeDocument?.hasUnautosavedChanges) { _, hasChanges in
            // Update window title to show unsaved indicator
            guard let window = NSApp.keyWindow else { return }
            guard let hasChanges = hasChanges else { return }
            var baseTitle = window.title
            if baseTitle.hasSuffix(" \u{2022}") {
                baseTitle = String(baseTitle.dropLast(2))
            }
            window.title = hasChanges ? "\(baseTitle) \u{2022}" : baseTitle
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var showSidebar: Bool
    @Binding var showSettings: Bool
    @StateObject private var notesManager = NotesManager()
    @AppStorage("darkMode") private var darkMode: Bool = false

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
                    // Session documents not in folder (e.g., newly created files saved elsewhere)
                    let sessionDocsOutsideFolder = notesManager.sessionDocuments.filter { url in
                        !notesManager.notesInFolder.contains(url) && FileManager.default.fileExists(atPath: url.path)
                    }.sorted { $0.lastPathComponent < $1.lastPathComponent }

                    ForEach(sessionDocsOutsideFolder, id: \.self) { url in
                        NoteRow(
                            name: url.deletingPathExtension().lastPathComponent,
                            url: url,
                            isSelected: url == notesManager.currentDocumentURL,
                            darkMode: darkMode,
                            action: { notesManager.openDocument(at: url) }
                        )
                    }

                    // Divider if we have both session docs and folder notes
                    if !sessionDocsOutsideFolder.isEmpty && !notesManager.notesInFolder.isEmpty {
                        Divider()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }

                    // Notes from folder
                    ForEach(notesManager.notesInFolder, id: \.self) { url in
                        NoteRow(
                            name: url.deletingPathExtension().lastPathComponent,
                            url: url,
                            isSelected: url == notesManager.currentDocumentURL,
                            darkMode: darkMode,
                            action: { notesManager.openDocument(at: url) }
                        )
                    }

                    // Empty state
                    if notesManager.notesInFolder.isEmpty && notesManager.sessionDocuments.isEmpty {
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
            // Liquid Glass sidebar background with rounded corners
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.vertical, 8)
        .padding(.leading, 8)
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
        // Listen for document saves
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NSDocumentDidSaveNotification"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                notesManager.refresh()
            }
        }
        // Periodic refresh while sidebar is visible
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            notesManager.refresh()
        }
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let name: String
    let url: URL?
    let isSelected: Bool
    let darkMode: Bool
    let action: () -> Void

    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 6
    @AppStorage("fontFamily") private var fontFamily: String = "EB Garamond"

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
        // Read the note content
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + ".pdf"
        savePanel.title = "Export as PDF"

        if savePanel.runModal() == .OK, let saveURL = savePanel.url {
            createPDF(content: content, saveURL: saveURL)
        }
    }

    private func getFont(size: CGFloat) -> NSFont {
        if fontFamily == "System" || fontFamily == "SF Pro" {
            return NSFont.systemFont(ofSize: size)
        } else if fontFamily == "EB Garamond" {
            for name in ["EBGaramond", "EB Garamond", "EBGaramond-Regular"] {
                if let font = NSFont(name: name, size: size) {
                    return font
                }
            }
        } else if let font = NSFont(name: fontFamily, size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size)
    }

    @AppStorage("lineLength") private var lineLength: Double = 65

    private func createPDF(content: String, saveURL: URL) {
        // PDF page settings
        let pageWidth: CGFloat = 612  // US Letter width in points
        let pageHeight: CGFloat = 792 // US Letter height in points
        let marginY: CGFloat = 72     // 1 inch top/bottom margins

        // Scale font size for PDF (screen fonts render smaller than print)
        // Use 0.65 scale factor to match visual appearance
        let pdfFontSize = CGFloat(fontSize) * 0.65
        let pdfLineSpacing = CGFloat(lineSpacing) * 0.65

        // Calculate text width based on line length setting
        // Average character width is approximately 0.5 * fontSize for most fonts
        let optimalTextWidth = CGFloat(lineLength) * pdfFontSize * 0.5
        let maxTextWidth = pageWidth - 72  // At least 0.5 inch margins on each side
        let textWidth = min(optimalTextWidth, maxTextWidth)
        let textHeight = pageHeight - (marginY * 2)

        // Center text horizontally on page
        let marginX = (pageWidth - textWidth) / 2

        // Create attributed string with formatting
        let font = getFont(size: pdfFontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = pdfLineSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: content, attributes: attributes)

        // Create PDF context
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let context = CGContext(saveURL as CFURL, mediaBox: &mediaBox, nil) else { return }

        // Calculate text layout
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        var currentRange = CFRange(location: 0, length: 0)

        while currentRange.location < attributedString.length {
            // Start new page
            context.beginPage(mediaBox: &mediaBox)

            // Create text frame for this page
            let framePath = CGPath(rect: CGRect(x: marginX, y: marginY, width: textWidth, height: textHeight), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, framePath, nil)

            // Draw the text
            context.textMatrix = .identity
            CTFrameDraw(frame, context)

            // Get the range that was drawn
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentRange.location += visibleRange.length

            context.endPage()
        }

        context.closePDF()
    }
}

// MARK: - Notes Manager

class NotesManager: ObservableObject {
    @Published var notesInFolder: [URL] = []
    @Published var currentDocumentURL: URL?
    @Published var notesFolder: URL?
    @Published var sessionDocuments: Set<URL> = []  // Track all documents opened/saved this session

    private var folderObserver: Any?
    private var documentObserver: Any?
    private var saveObserver: Any?
    private var folderMonitor: DispatchSourceFileSystemObject?
    private var monitoredFolderDescriptor: Int32 = -1

    init() {
        refresh()

        // Listen for folder changes
        folderObserver = NotificationCenter.default.addObserver(
            forName: .notesFolderChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
            self?.setupFolderMonitor()
        }

        // Listen for current document changes
        documentObserver = NotificationCenter.default.addObserver(
            forName: .currentDocumentChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let url = notification.object as? URL {
                self?.currentDocumentURL = url
                self?.sessionDocuments.insert(url)
            } else {
                self?.currentDocumentURL = nil
            }
            self?.refresh()
        }

        // Listen for document save notifications
        saveObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSDocumentDidSaveNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Track saved document
            if let document = notification.object as? NSDocument,
               let url = document.fileURL {
                self?.sessionDocuments.insert(url)
            }
            // Delay slightly to ensure file system has updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.refresh()
            }
        }

        // Setup folder monitoring
        setupFolderMonitor()
    }

    deinit {
        if let observer = folderObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = documentObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = saveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopFolderMonitor()
    }

    private func setupFolderMonitor() {
        // Stop existing monitor
        stopFolderMonitor()

        guard let folder = notesFolder else { return }

        // Open folder for monitoring
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        monitoredFolderDescriptor = fd

        // Create dispatch source to monitor folder
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.refresh()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        folderMonitor = source
    }

    private func stopFolderMonitor() {
        folderMonitor?.cancel()
        folderMonitor = nil
        if monitoredFolderDescriptor >= 0 {
            // Descriptor will be closed by cancel handler
            monitoredFolderDescriptor = -1
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
                let folderChanged = notesFolder != url
                notesFolder = url
                _ = url.startAccessingSecurityScopedResource()
                loadNotesFromFolder(url)

                // Setup monitor if folder changed or not yet monitoring
                if folderChanged || folderMonitor == nil {
                    setupFolderMonitor()
                }
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

            // Filter for RTF and text files, sort by modification date (newest first)
            notesInFolder = contents
                .filter { url in
                    let ext = url.pathExtension.lowercased()
                    return ext == "rtf" || ext == "txt" || ext.isEmpty
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
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("fontFamily") private var fontFamily: String = "EB Garamond"
    @AppStorage("showWordCount") private var showWordCount: Bool = true
    @AppStorage("launchBehavior") private var launchBehavior: LaunchBehavior = .lastEdited

    private let availableFonts = [
        "EB Garamond",
        "System",
        "Helvetica Neue",
        "Arial",
        "Avenir",
        "SF Pro",
        "New York",
        "Georgia",
        "Times New Roman",
        "Palatino",
        "Charter",
        "Courier New",
        "Menlo"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Dark mode toggle
            HStack {
                Text("Dark Mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Toggle("", isOn: $darkMode)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            // Word count toggle
            HStack {
                Text("Word Count")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Toggle("", isOn: $showWordCount)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            // Launch behavior
            VStack(alignment: .leading, spacing: 6) {
                Text("On Launch")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("", selection: $launchBehavior) {
                    ForEach(LaunchBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Divider()

            // Font family
            VStack(alignment: .leading, spacing: 6) {
                Text("Font")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("", selection: $fontFamily) {
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Divider()

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
                    Button {
                        notesManager.changeNotesFolder()
                    } label: {
                        Text("Change")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
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
                        .tint(Color.appAccent(darkMode: darkMode))
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
                        .tint(Color.appAccent(darkMode: darkMode))
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
                        .tint(Color.appAccent(darkMode: darkMode))
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

// MARK: - Smooth Cursor Text View

class SmoothCursorTextView: NSTextView {
    private var cursorLayer: CALayer?
    private var blinkTimer: Timer?
    private var cursorColor: NSColor = .black  // Safe default, will be updated
    var baseFontSize: CGFloat = 16  // Set from coordinator, used for fixed cursor height
    private var moveCursorObserver: Any?

    // MARK: - Cursor Setup

    func setupCursor(color: NSColor) {
        cursorColor = color
        insertionPointColor = color

        wantsLayer = true

        // Create cursor layer
        let cursor = CALayer()
        cursor.backgroundColor = color.cgColor
        cursor.cornerRadius = 1.5
        cursor.frame = CGRect(x: 0, y: 0, width: 2.5, height: 20)

        layer?.addSublayer(cursor)
        cursorLayer = cursor

        // Start blinking
        startBlinking()

        // Position after a brief delay to ensure layout is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateCursorPosition(animated: false)
        }
    }

    // MARK: - Cursor Color

    func updateCursorColor(_ color: NSColor) {
        cursorColor = color
        insertionPointColor = color
        cursorLayer?.backgroundColor = color.cgColor
    }

    // MARK: - Cursor Blinking

    private func startBlinking() {
        blinkTimer?.invalidate()
        cursorLayer?.opacity = 1

        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let cursor = self.cursorLayer else { return }
            guard self.window?.firstResponder == self else { return }

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = cursor.opacity
            fade.toValue = cursor.opacity > 0.5 ? 0.0 : 1.0
            fade.duration = 0.15
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false
            cursor.add(fade, forKey: "blink")
            cursor.opacity = cursor.opacity > 0.5 ? 0.0 : 1.0
        }
    }

    private func resetBlink() {
        cursorLayer?.removeAnimation(forKey: "blink")
        cursorLayer?.opacity = 1
        startBlinking()
    }

    // MARK: - Cursor Positioning

    func updateCursorPosition(animated: Bool) {
        guard let cursor = cursorLayer else { return }
        guard let window = window else { return }

        // Hide if there's a selection
        if selectedRange().length > 0 {
            cursor.isHidden = true
            return
        }
        cursor.isHidden = false

        let insertionPoint = selectedRange().location

        // Fixed cursor height based on base font size from settings
        let baseFont = NSFont.systemFont(ofSize: baseFontSize)
        let cursorHeight = baseFont.ascender + abs(baseFont.descender)

        // Get cursor position using firstRect - simple and reliable
        let charRange = NSRange(location: insertionPoint, length: 0)
        var actualRange = NSRange()
        let screenRect = firstRect(forCharacterRange: charRange, actualRange: &actualRange)
        let windowRect = window.convertFromScreen(screenRect)
        let viewRect = convert(windowRect, from: nil)

        let newFrame = CGRect(
            x: viewRect.origin.x,
            y: viewRect.origin.y,
            width: 2.5,
            height: cursorHeight
        )

        // Validate frame
        guard !newFrame.origin.x.isNaN && !newFrame.origin.y.isNaN else { return }

        if animated {
            // Liquid glass spring animation using CASpringAnimation
            let oldFrame = cursor.frame

            // Calculate movement distance
            let dx = abs(newFrame.origin.x - oldFrame.origin.x)
            let dy = abs(newFrame.origin.y - oldFrame.origin.y)
            let dh = abs(newFrame.height - oldFrame.height)

            // Only animate if there's meaningful movement
            if dx > 0.5 || dy > 0.5 || dh > 0.5 {
                // Determine if this is a small movement (typing) or large jump (clicking/navigation)
                let isSmallMovement = dx < 20 && dy < 5

                // Position animation with spring physics
                let positionAnimation = CASpringAnimation(keyPath: "position")
                positionAnimation.fromValue = NSValue(point: NSPoint(
                    x: oldFrame.origin.x + oldFrame.width / 2,
                    y: oldFrame.origin.y + oldFrame.height / 2
                ))
                positionAnimation.toValue = NSValue(point: NSPoint(
                    x: newFrame.origin.x + newFrame.width / 2,
                    y: newFrame.origin.y + newFrame.height / 2
                ))

                if isSmallMovement {
                    // Fast, snappy animation for typing - minimal lag
                    positionAnimation.damping = 30
                    positionAnimation.stiffness = 800
                    positionAnimation.mass = 0.3
                } else {
                    // Smooth liquid animation for larger movements
                    positionAnimation.damping = 30
                    positionAnimation.stiffness = 800
                    positionAnimation.mass = 0.3
                }
                positionAnimation.initialVelocity = 0
                positionAnimation.duration = positionAnimation.settlingDuration

                // Height animation for smooth heading transitions
                let boundsAnimation = CASpringAnimation(keyPath: "bounds.size.height")
                boundsAnimation.fromValue = oldFrame.height
                boundsAnimation.toValue = newFrame.height
                boundsAnimation.damping = 25
                boundsAnimation.stiffness = 500
                boundsAnimation.mass = 0.4
                boundsAnimation.duration = boundsAnimation.settlingDuration

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                cursor.frame = newFrame
                CATransaction.commit()

                cursor.add(positionAnimation, forKey: "liquidPosition")
                cursor.add(boundsAnimation, forKey: "liquidBounds")
            } else {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                cursor.frame = newFrame
                CATransaction.commit()
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            cursor.frame = newFrame
            CATransaction.commit()
        }
    }

    // MARK: - Hide Default Cursor

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        // Don't draw default cursor
    }

    override func setNeedsDisplay(_ rect: NSRect) {
        // Prevent cursor rect from triggering redraws
        var newRect = rect
        if rect.width <= 5 {
            newRect = .zero
        }
        super.setNeedsDisplay(newRect)
    }

    // MARK: - Event Handling

    override var selectedRanges: [NSValue] {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.updateCursorPosition(animated: true)
                self?.resetBlink()
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        // Handle Cmd+B for bold
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "b" {
            toggleBold()
            return
        }

        // Handle Cmd+I for italic
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "i" {
            toggleItalic()
            return
        }

        super.keyDown(with: event)
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    // MARK: - Rich Text Formatting

    func toggleBold() {
        guard let textStorage = textStorage else { return }
        let range = selectedRange()

        if range.length == 0 {
            // No selection - toggle typing attributes for future text
            var typingAttributes = self.typingAttributes
            if let currentFont = typingAttributes[.font] as? NSFont {
                let fontManager = NSFontManager.shared
                let traits = fontManager.traits(of: currentFont)
                let newFont: NSFont
                if traits.contains(.boldFontMask) {
                    newFont = fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
                }
                typingAttributes[.font] = newFont
                self.typingAttributes = typingAttributes
            }
            return
        }

        // Has selection - toggle bold on selected text
        let fontManager = NSFontManager.shared
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            guard let currentFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: currentFont)
            let newFont: NSFont
            if traits.contains(.boldFontMask) {
                newFont = fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
            } else {
                newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
            }
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()

        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    func toggleItalic() {
        guard let textStorage = textStorage else { return }
        let range = selectedRange()

        if range.length == 0 {
            // No selection - toggle typing attributes for future text
            var typingAttributes = self.typingAttributes
            if let currentFont = typingAttributes[.font] as? NSFont {
                let fontManager = NSFontManager.shared
                let traits = fontManager.traits(of: currentFont)
                let newFont: NSFont
                if traits.contains(.italicFontMask) {
                    newFont = fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
                }
                typingAttributes[.font] = newFont
                self.typingAttributes = typingAttributes
            }
            return
        }

        // Has selection - toggle italic on selected text
        let fontManager = NSFontManager.shared
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            guard let currentFont = value as? NSFont else { return }
            let traits = fontManager.traits(of: currentFont)
            let newFont: NSFont
            if traits.contains(.italicFontMask) {
                newFont = fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
            } else {
                newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
            }
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()

        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func mouseDown(with event: NSEvent) {
        NotificationCenter.default.post(name: .hideFormattingToolbar, object: nil)
        super.mouseDown(with: event)
        // Update cursor after selection is set
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        updateCursorPosition(animated: true)
        resetBlink()
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        updateCursorPosition(animated: false)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            cursorLayer?.isHidden = false
            updateCursorPosition(animated: false)
            resetBlink()
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        blinkTimer?.invalidate()
        cursorLayer?.isHidden = true
        return result
    }

    // MARK: - Paste/Cut/Delete Operations

    override func paste(_ sender: Any?) {
        super.paste(sender)
        // Update cursor position after paste
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func pasteAsPlainText(_ sender: Any?) {
        super.pasteAsPlainText(sender)
        // Update cursor position after paste
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func cut(_ sender: Any?) {
        super.cut(sender)
        // Update cursor position after cut
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func delete(_ sender: Any?) {
        super.delete(sender)
        // Update cursor position after delete
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func deleteBackward(_ sender: Any?) {
        super.deleteBackward(sender)
        // Update cursor position after delete
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func deleteForward(_ sender: Any?) {
        super.deleteForward(sender)
        // Update cursor position after delete
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: true)
            self?.resetBlink()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && cursorLayer == nil {
            // Determine correct color based on appearance
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let color = isDark ? NSColor.white : NSColor.black
            setupCursor(color: color)
        }

        // Set up observer for moving cursor to end
        if window != nil && moveCursorObserver == nil {
            moveCursorObserver = NotificationCenter.default.addObserver(
                forName: .moveCursorToEnd,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.moveCursorToEnd()
            }
        }
    }

    /// Moves the cursor to the end of the document
    func moveCursorToEnd() {
        let endPosition = string.count
        setSelectedRange(NSRange(location: endPosition, length: 0))
        scrollRangeToVisible(NSRange(location: endPosition, length: 0))
        updateCursorPosition(animated: false)
        resetBlink()
    }

    override func layout() {
        super.layout()
        updateCursorPosition(animated: false)
    }

    deinit {
        blinkTimer?.invalidate()
        if let observer = moveCursorObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Right Click Formatting

    // Override right-click to show formatting toolbar instead of context menu
    override func rightMouseDown(with event: NSEvent) {
        let range = selectedRange()
        guard range.length > 0 else {
            // No selection, hide toolbar and do nothing
            NotificationCenter.default.post(name: .hideFormattingToolbar, object: nil)
            return
        }

        // Get the rect of the selection for positioning
        guard let layoutManager = layoutManager, let textContainer = textContainer else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let selectionRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Convert to view coordinates
        var rectInView = selectionRect
        rectInView.origin.x += textContainerInset.width
        rectInView.origin.y += textContainerInset.height

        // Convert to window coordinates
        let rectInWindow = convert(rectInView, to: nil)

        NotificationCenter.default.post(
            name: .showFormattingToolbar,
            object: nil,
            userInfo: ["selectionRect": rectInWindow]
        )
    }

    // Return nil to prevent default context menu
    override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }

}

// MARK: - Rich Text View (NSViewRepresentable)

struct RichTextView: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var fontSize: Double
    var lineSpacing: Double
    var lineLength: Double
    var darkMode: Bool
    var fontFamily: String

    // Helper to get the appropriate font
    private func getFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if fontFamily == "System" || fontFamily == "SF Pro" {
            return NSFont.systemFont(ofSize: size, weight: weight)
        } else if fontFamily == "New York" {
            // New York is a serif system font
            if let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) {
                return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
            }
            return NSFont.systemFont(ofSize: size, weight: weight)
        } else if fontFamily == "EB Garamond" {
            // EB Garamond bundled font - variable font
            if let font = NSFont(name: "EBGaramond", size: size) {
                return font
            }
            // Try alternate names
            if let font = NSFont(name: "EB Garamond", size: size) {
                return font
            }
            if let font = NSFont(name: "EBGaramond-Regular", size: size) {
                return font
            }
            // Fallback to system serif
            if let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) {
                return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
            }
            return NSFont.systemFont(ofSize: size, weight: weight)
        } else {
            // Try to get the font by name
            if let font = NSFont(name: fontFamily, size: size) {
                return font
            }
            // Fallback to system font
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }

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
        let textView = SmoothCursorTextView()

        // ===========================================
        // GPU-ACCELERATED RENDERING SETUP
        // ===========================================

        // Enable layer-backing for GPU compositing
        scrollView.wantsLayer = true
        textView.wantsLayer = true

        // Configure scroll view layer for GPU acceleration
        if let scrollLayer = scrollView.layer {
            scrollLayer.drawsAsynchronously = true
            scrollLayer.shouldRasterize = false
            scrollLayer.allowsEdgeAntialiasing = true
        }

        // Configure text view layer for optimal rendering
        if let textLayer = textView.layer {
            textLayer.drawsAsynchronously = true
            textLayer.shouldRasterize = false
            textLayer.allowsEdgeAntialiasing = true
        }

        // Optimize layer redraw policy - only redraw on resize, not scroll
        scrollView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        textView.layerContentsRedrawPolicy = .onSetNeedsDisplay

        // Enable responsive scrolling (renders ahead for smooth scrolling)
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        if let clipLayer = scrollView.contentView.layer {
            clipLayer.drawsAsynchronously = true
        }

        // ===========================================
        // SCROLL VIEW CONFIGURATION
        // ===========================================

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        // Native bouncy scroll - this is the Apple way
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none
        scrollView.usesPredominantAxisScrolling = true

        // Hide scrollers completely for distraction-free writing
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false

        // Content insets to allow bounce even with short content
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 20, left: 0, bottom: 100, right: 0)

        // ===========================================
        // TEXT VIEW CONFIGURATION
        // ===========================================

        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true

        // Enable layout manager GPU optimizations
        if let layoutManager = textView.layoutManager {
            layoutManager.allowsNonContiguousLayout = true
            layoutManager.backgroundLayoutEnabled = true
        }

        // Apply dark mode colors
        let backgroundColor = darkMode ? NSColor.black : NSColor.textBackgroundColor
        let textColor = darkMode ? NSColor.white : NSColor.textColor
        scrollView.backgroundColor = backgroundColor
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.insertionPointColor = textColor

        // Setup smooth cursor with correct color
        textView.setupCursor(color: textColor)

        // Typography for comfortable writing
        textView.font = getFont(size: CGFloat(fontSize))
        textView.baseFontSize = CGFloat(fontSize)
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

        // Set initial attributed text
        textView.textStorage?.setAttributedString(attributedText)

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
        guard let textView = scrollView.documentView as? SmoothCursorTextView else { return }

        // Update coordinator's parent reference so it has current values
        context.coordinator.parent = self

        // Only update if text changed externally (compare plain string for efficiency)
        if textView.string != attributedText.string {
            let selectedRanges = textView.selectedRanges
            textView.textStorage?.setAttributedString(attributedText)
            textView.selectedRanges = selectedRanges
        }

        // Update font (size or family)
        let newFont = getFont(size: CGFloat(fontSize))
        let currentFontName = textView.font?.fontName ?? ""
        let newFontName = newFont.fontName
        if textView.font?.pointSize != CGFloat(fontSize) || currentFontName != newFontName {
            textView.font = newFont
            textView.baseFontSize = CGFloat(fontSize)
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

        // Update dark mode colors
        let backgroundColor = darkMode ? NSColor.black : NSColor.textBackgroundColor
        let textColor = darkMode ? NSColor.white : NSColor.textColor

        // Always update cursor color - use explicit colors for CALayer compatibility
        let cursorColor = darkMode ? NSColor.white : NSColor.black
        textView.updateCursorColor(cursorColor)

        if scrollView.backgroundColor != backgroundColor {
            scrollView.backgroundColor = backgroundColor
            textView.backgroundColor = backgroundColor
            textView.textColor = textColor
            // Update all existing text with new color
            if let textStorage = textView.textStorage, textStorage.length > 0 {
                textStorage.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: textStorage.length))
            }
        }

        // Update centering
        context.coordinator.updateTextInsets()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextView
        weak var textView: NSTextView?
        var verticalPadding: CGFloat = 40
        var minimumHorizontalPadding: CGFloat = 40
        private var formattingObserver: Any?

        var optimalTextWidth: CGFloat {
            parent.optimalTextWidth
        }

        init(_ parent: RichTextView) {
            self.parent = parent
            super.init()

            // Listen for formatting toolbar actions
            formattingObserver = NotificationCenter.default.addObserver(
                forName: .applyFormatting,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let format = notification.userInfo?["format"] as? String,
                      let textView = self?.textView,
                      let textStorage = textView.textStorage else { return }

                let range = textView.selectedRange()
                guard range.length > 0 else { return }

                let fontManager = NSFontManager.shared

                // Apply formatting to selected range
                textStorage.beginEditing()
                textStorage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
                    guard let currentFont = value as? NSFont else { return }

                    let newFont: NSFont
                    switch format {
                    case "bold":
                        // Toggle bold
                        let traits = fontManager.traits(of: currentFont)
                        if traits.contains(.boldFontMask) {
                            newFont = fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                        } else {
                            newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
                        }
                    case "italic":
                        // Toggle italic
                        let traits = fontManager.traits(of: currentFont)
                        if traits.contains(.italicFontMask) {
                            newFont = fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                        } else {
                            newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
                        }
                    default:
                        return
                    }

                    textStorage.addAttribute(.font, value: newFont, range: attrRange)
                }
                textStorage.endEditing()
            }
        }

        deinit {
            if let observer = formattingObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        private func getFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
            let fontFamily = parent.fontFamily
            if fontFamily == "System" || fontFamily == "SF Pro" {
                return NSFont.systemFont(ofSize: size, weight: weight)
            } else if fontFamily == "New York" {
                if let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) {
                    return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
                }
                return NSFont.systemFont(ofSize: size, weight: weight)
            } else if fontFamily == "EB Garamond" {
                // Try various EB Garamond font names
                for name in ["EBGaramond", "EB Garamond", "EBGaramond-Regular"] {
                    if let font = NSFont(name: name, size: size) {
                        return font
                    }
                }
                // Fallback to system serif
                if let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) {
                    return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
                }
                return NSFont.systemFont(ofSize: size, weight: weight)
            } else {
                if let font = NSFont(name: fontFamily, size: size) {
                    return font
                }
                return NSFont.systemFont(ofSize: size, weight: weight)
            }
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
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage else { return }

            // Commit the attributed text to the document binding
            // NSDocument's autosave will handle the actual file saving
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.attributedText = NSAttributedString(attributedString: textStorage)
            }
        }

    }
}

#Preview {
    ContentView()
        .environmentObject(TinyWriterDocumentManager())
}
