import SwiftUI

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var isAddingTab = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        for window in NSApp.windows {
            window.tabbingMode = .preferred
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillBeAdded(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc func windowWillBeAdded(_ notification: Notification) {
        guard !isAddingTab,
              let newWindow = notification.object as? NSWindow,
              newWindow.tabbingMode != .disallowed else { return }

        newWindow.tabbingMode = .preferred

        // Find an existing document window to add this as a tab
        let documentWindows = NSApp.windows.filter {
            $0 != newWindow &&
            $0.isVisible &&
            $0.tabbingMode == .preferred &&
            $0.tabbedWindows?.contains(newWindow) != true &&
            String(describing: type(of: $0)) == String(describing: type(of: newWindow))
        }

        if let targetWindow = documentWindows.first {
            isAddingTab = true
            targetWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
            isAddingTab = false
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct JustWriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: JustWriteDocument()) { file in
            ContentView(document: file.$document)
                .background(WindowAccessor())
        }
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)
            }
            CommandGroup(after: .windowArrangement) {
                Button("Distraction Free") {
                    toggleDistractionFree()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }

    private func toggleDistractionFree() {
        guard let window = NSApp.keyWindow else { return }
        window.toggleFullScreen(nil)
    }
}

// MARK: - Window Accessor

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.tabbingMode = .preferred
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.tabbingMode = .preferred
        }
    }
}
