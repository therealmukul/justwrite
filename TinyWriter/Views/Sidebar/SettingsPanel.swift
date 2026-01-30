import SwiftUI

/// Settings panel displayed at the bottom of the sidebar
struct SettingsPanel: View {
    @ObservedObject var notesManager: NotesManager
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("lineSpacing") private var lineSpacing: Double = 6
    @AppStorage("lineLength") private var lineLength: Double = 65
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("fontFamily") private var fontFamily: String = "EB Garamond"
    @AppStorage("showWordCount") private var showWordCount: Bool = true
    @AppStorage("launchBehavior") private var launchBehavior: LaunchBehavior = .lastEdited
    @AppStorage("spellCheckingEnabled") private var spellCheckingEnabled: Bool = true
    @AppStorage("grammarCheckingEnabled") private var grammarCheckingEnabled: Bool = true

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

            // Spell checking toggle
            HStack {
                Text("Spell Checking")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Toggle("", isOn: $spellCheckingEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: spellCheckingEnabled) { _, _ in
                        NotificationCenter.default.post(name: .spellCheckingChanged, object: nil)
                    }
            }

            // Grammar checking toggle
            HStack {
                Text("Grammar Checking")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Toggle("", isOn: $grammarCheckingEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: grammarCheckingEnabled) { _, _ in
                        NotificationCenter.default.post(name: .grammarCheckingChanged, object: nil)
                    }
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
