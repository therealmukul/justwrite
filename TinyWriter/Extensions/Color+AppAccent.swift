import SwiftUI

// Custom accent colors for the app
extension Color {
    // Light mode: #800020 (deep burgundy)
    static let appAccentLight = Color(red: 0x80 / 255.0, green: 0x00 / 255.0, blue: 0x20 / 255.0)
    // Dark mode: #C94C66 (rose-burgundy)
    static let appAccentDark = Color(red: 0xC9 / 255.0, green: 0x4C / 255.0, blue: 0x66 / 255.0)

    static func appAccent(darkMode: Bool) -> Color {
        darkMode ? .appAccentDark : .appAccentLight
    }
}
