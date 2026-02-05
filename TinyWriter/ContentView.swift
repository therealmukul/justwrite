import SwiftUI
import AppKit
import QuartzCore

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
                        .zIndex(1)
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

#Preview {
    ContentView()
        .environmentObject(TinyWriterDocumentManager())
}
