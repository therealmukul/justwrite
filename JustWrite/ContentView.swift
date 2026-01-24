import SwiftUI
import AppKit

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

struct ContentView: View {
    @Binding var document: JustWriteDocument
    @State private var showSidebar = false
    @State private var showSettings = false
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 6
    @AppStorage("lineLength") private var lineLength: Double = 65
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("fontFamily") private var fontFamily: String = "EB Garamond"

    var body: some View {
        ZStack(alignment: .leading) {
            // Main editor
            MarkdownTextView(text: $document.text, fontSize: fontSize, lineSpacing: lineSpacing, lineLength: lineLength, darkMode: darkMode, fontFamily: fontFamily)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(darkMode ? Color.black : Color(NSColor.textBackgroundColor))

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
        .preferredColorScheme(.light)
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
                    // Current document (if not in folder list)
                    if let currentURL = notesManager.currentDocumentURL,
                       !notesManager.notesInFolder.contains(currentURL) {
                        NoteRow(
                            name: currentURL.deletingPathExtension().lastPathComponent,
                            isSelected: true,
                            darkMode: darkMode,
                            action: {}
                        )
                    }

                    // Notes from folder
                    ForEach(notesManager.notesInFolder, id: \.self) { url in
                        NoteRow(
                            name: url.deletingPathExtension().lastPathComponent,
                            isSelected: url == notesManager.currentDocumentURL,
                            darkMode: darkMode,
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
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let name: String
    let isSelected: Bool
    let darkMode: Bool
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
                        .fill(Color.appAccent(darkMode: darkMode))
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
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("fontFamily") private var fontFamily: String = "EB Garamond"

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
    private var cursorView: NSView?
    private var cursorBlinkTimer: Timer?
    private var isCursorVisible = true

    func setupSmoothCursor(color: NSColor) {
        // Create cursor view
        let cursor = NSView()
        cursor.wantsLayer = true
        cursor.layer?.backgroundColor = color.cgColor
        cursor.layer?.cornerRadius = 1
        addSubview(cursor)
        cursorView = cursor

        // Start blink timer
        startBlinkTimer()

        // Initial position
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition(animated: false)
        }
    }

    private func startBlinkTimer() {
        cursorBlinkTimer?.invalidate()
        isCursorVisible = true
        cursorView?.alphaValue = 1

        cursorBlinkTimer = Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { [weak self] _ in
            guard let self = self, self.window?.firstResponder == self else { return }
            self.isCursorVisible.toggle()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.08
                self.cursorView?.animator().alphaValue = self.isCursorVisible ? 1 : 0
            }
        }
    }

    private func resetBlink() {
        isCursorVisible = true
        cursorView?.alphaValue = 1
        startBlinkTimer()
    }

    func updateCursorColor(_ color: NSColor) {
        cursorView?.layer?.backgroundColor = color.cgColor
        insertionPointColor = color
    }

    func updateCursorPosition(animated: Bool = true) {
        guard let cursorView = cursorView else { return }

        // Hide cursor if there's a selection
        if selectedRange().length > 0 {
            cursorView.isHidden = true
            return
        }

        cursorView.isHidden = false

        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        let insertionPoint = selectedRange().location

        // Calculate cursor height based on font metrics
        let cursorHeight: CGFloat
        if let font = font {
            cursorHeight = font.ascender + abs(font.descender)
        } else {
            cursorHeight = 16
        }

        // Get cursor rect
        var cursorRect: NSRect

        if layoutManager.numberOfGlyphs == 0 || string.isEmpty {
            // Empty document - position at start
            cursorRect = NSRect(x: textContainerInset.width, y: textContainerInset.height, width: 2, height: cursorHeight)
        } else {
            // Get the insertion point rect from the layout manager
            let glyphIndex: Int
            if insertionPoint >= layoutManager.numberOfGlyphs {
                glyphIndex = max(0, layoutManager.numberOfGlyphs - 1)
            } else {
                glyphIndex = layoutManager.glyphIndexForCharacter(at: insertionPoint)
            }

            // Get the baseline location for this glyph
            let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)

            // Baseline Y = lineFragmentRect.minY + glyphLocation.y
            // Cursor should go from (baseline - descender) to (baseline + ascender)
            // In flipped coords: top of cursor = baseline - ascender
            let baselineY = lineFragmentRect.minY + glyphLocation.y
            let cursorY = baselineY - (font?.ascender ?? cursorHeight)

            if insertionPoint >= string.count && !string.isEmpty {
                // At end of text - position after last character
                let lastCharIndex = max(0, layoutManager.numberOfGlyphs - 1)
                let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: lastCharIndex, length: 1), in: textContainer)
                cursorRect = NSRect(
                    x: glyphRect.maxX + textContainerInset.width,
                    y: cursorY + textContainerInset.height,
                    width: 2,
                    height: cursorHeight
                )
            } else {
                // Normal position - at start of current glyph
                let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
                cursorRect = NSRect(
                    x: glyphRect.minX + textContainerInset.width,
                    y: cursorY + textContainerInset.height,
                    width: 2,
                    height: cursorHeight
                )
            }
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.08
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                cursorView.animator().frame = cursorRect
            }
        } else {
            cursorView.frame = cursorRect
        }
    }

    // Override to hide default cursor
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        // Don't draw - we use our custom cursor
    }

    override var selectedRanges: [NSValue] {
        didSet {
            updateCursorPosition(animated: true)
            resetBlink()
        }
    }

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        updateCursorPosition(animated: true)
        resetBlink()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        updateCursorPosition(animated: true)
        resetBlink()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        updateCursorPosition(animated: true)
        resetBlink()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            cursorView?.isHidden = false
            updateCursorPosition(animated: false)
            startBlinkTimer()
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        cursorBlinkTimer?.invalidate()
        cursorView?.isHidden = true
        return result
    }

    override func layout() {
        super.layout()
        updateCursorPosition(animated: false)
    }

    deinit {
        cursorBlinkTimer?.invalidate()
    }
}

// MARK: - Markdown Text View (NSViewRepresentable)

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
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

        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        // Configure text view for writing
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true

        // Apply dark mode colors
        let backgroundColor = darkMode ? NSColor.black : NSColor.textBackgroundColor
        let textColor = darkMode ? NSColor.white : NSColor.textColor
        scrollView.backgroundColor = backgroundColor
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.insertionPointColor = textColor

        // Typography for comfortable writing
        textView.font = getFont(size: CGFloat(fontSize))
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

        // Setup smooth cursor after view is configured
        textView.setupSmoothCursor(color: textColor)

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

        // Only update if text changed externally
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        // Update font (size or family)
        let newFont = getFont(size: CGFloat(fontSize))
        let currentFontName = textView.font?.fontName ?? ""
        let newFontName = newFont.fontName
        if textView.font?.pointSize != CGFloat(fontSize) || currentFontName != newFontName {
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

        // Update dark mode colors
        let backgroundColor = darkMode ? NSColor.black : NSColor.textBackgroundColor
        let textColor = darkMode ? NSColor.white : NSColor.textColor

        // Always update cursor color to ensure it's correct
        textView.updateCursorColor(textColor)

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

        private func getBoldFont(size: CGFloat) -> NSFont {
            let fontFamily = parent.fontFamily
            if fontFamily == "System" || fontFamily == "SF Pro" {
                return NSFont.systemFont(ofSize: size, weight: .bold)
            } else if fontFamily == "New York" {
                if let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif)?.withSymbolicTraits(.bold) {
                    return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
                }
                return NSFont.systemFont(ofSize: size, weight: .bold)
            } else if fontFamily == "EB Garamond" {
                // EB Garamond is a variable font, use font manager for bold
                for name in ["EBGaramond", "EB Garamond", "EBGaramond-Regular"] {
                    if let baseFont = NSFont(name: name, size: size) {
                        return NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                    }
                }
                return NSFont.systemFont(ofSize: size, weight: .bold)
            } else {
                // Try bold variant
                let boldName = fontFamily + "-Bold"
                if let font = NSFont(name: boldName, size: size) {
                    return font
                }
                // Try using font manager to get bold
                if let baseFont = NSFont(name: fontFamily, size: size) {
                    return NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                }
                return NSFont.systemFont(ofSize: size, weight: .bold)
            }
        }

        private func getItalicFont(size: CGFloat) -> NSFont {
            let fontFamily = parent.fontFamily
            if fontFamily == "System" || fontFamily == "SF Pro" {
                let systemFont = NSFont.systemFont(ofSize: size, weight: .regular)
                return NSFontManager.shared.convert(systemFont, toHaveTrait: .italicFontMask)
            } else if fontFamily == "New York" {
                if let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif)?.withSymbolicTraits(.italic) {
                    return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size)
                }
                return NSFont.systemFont(ofSize: size)
            } else if fontFamily == "EB Garamond" {
                // Try EB Garamond Italic variant
                for name in ["EBGaramond-Italic", "EB Garamond Italic"] {
                    if let font = NSFont(name: name, size: size) {
                        return font
                    }
                }
                // Fallback: get regular and convert to italic
                for name in ["EBGaramond", "EB Garamond", "EBGaramond-Regular"] {
                    if let baseFont = NSFont(name: name, size: size) {
                        return NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                    }
                }
                return NSFont.systemFont(ofSize: size)
            } else {
                if let baseFont = NSFont(name: fontFamily, size: size) {
                    return NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                }
                return NSFont.systemFont(ofSize: size)
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
            let textColor = parent.darkMode ? NSColor.white : NSColor.textColor

            // Reset to default style
            let defaultFont = getFont(size: baseFontSize)
            textView.textStorage?.addAttribute(.font, value: defaultFont, range: fullRange)
            textView.textStorage?.addAttribute(.foregroundColor, value: textColor, range: fullRange)

            // Apply line spacing
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = CGFloat(parent.lineSpacing)
            textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

            // Headings (scale relative to base font size)
            highlightPattern(#"^# .+$"#, in: textView, font: getBoldFont(size: baseFontSize * 1.5))
            highlightPattern(#"^## .+$"#, in: textView, font: getBoldFont(size: baseFontSize * 1.25))
            highlightPattern(#"^### .+$"#, in: textView, font: getBoldFont(size: baseFontSize * 1.125))

            // Bold
            highlightPattern(#"\*\*[^*]+\*\*"#, in: textView, font: getBoldFont(size: baseFontSize))

            // Italic
            highlightPattern(#"_[^_]+_"#, in: textView, font: getItalicFont(size: baseFontSize))
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
