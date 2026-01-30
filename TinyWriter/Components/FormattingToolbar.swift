import SwiftUI

/// Floating toolbar for text formatting (bold, italic, alignment)
struct FormattingToolbar: View {
    var body: some View {
        HStack(spacing: 2) {
            // Bold & Italic
            FormatButton(label: "B", fontWeight: .bold, action: { applyFormat("bold") })
            FormatButton(label: "I", isItalic: true, action: { applyFormat("italic") })

            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 1, height: 20)
                .padding(.horizontal, 4)

            // Alignment buttons
            FormatButton(systemImage: "text.alignleft", action: { applyFormat("alignLeft") })
            FormatButton(systemImage: "text.aligncenter", action: { applyFormat("alignCenter") })
            FormatButton(systemImage: "text.alignright", action: { applyFormat("alignRight") })
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
