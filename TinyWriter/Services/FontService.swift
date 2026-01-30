import AppKit

/// Unified font service for consistent font resolution across the app
struct FontService {

    /// Returns the appropriate font for the given family and size
    /// - Parameters:
    ///   - family: Font family name (e.g., "EB Garamond", "System", "SF Pro")
    ///   - size: Font size in points
    ///   - weight: Font weight (default: .regular)
    /// - Returns: The resolved NSFont, falling back to system font if needed
    static func getFont(family: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if family == "System" || family == "SF Pro" {
            return NSFont.systemFont(ofSize: size, weight: weight)
        } else if family == "New York" {
            // New York is a serif system font
            if let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) {
                return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
            }
            return NSFont.systemFont(ofSize: size, weight: weight)
        } else if family == "EB Garamond" {
            // EB Garamond bundled font - variable font
            // Try various names the font might be registered under
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
            // Try to get the font by name
            if let font = NSFont(name: family, size: size) {
                return font
            }
            // Fallback to system font
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }
}
