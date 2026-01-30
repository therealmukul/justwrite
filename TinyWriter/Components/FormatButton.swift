import SwiftUI

/// A reusable button for formatting actions in the toolbar
struct FormatButton: View {
    var label: String? = nil
    var systemImage: String? = nil
    var fontWeight: Font.Weight = .semibold
    var isItalic: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .medium))
                } else if let label = label {
                    Text(label)
                        .font(.system(size: 13, weight: fontWeight))
                        .italic(isItalic)
                }
            }
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
