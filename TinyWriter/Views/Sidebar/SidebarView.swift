import SwiftUI
import AppKit

/// The collapsible sidebar showing notes list and settings
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
                    .contentShape(Rectangle()) // Make entire area clickable
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
        // Force arrow cursor in sidebar (prevents I-beam from text view bleeding through)
        .onHover { isHovered in
            if isHovered {
                NSCursor.arrow.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
