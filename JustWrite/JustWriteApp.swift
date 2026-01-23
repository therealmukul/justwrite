import SwiftUI

@main
struct JustWriteApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: JustWriteDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
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
