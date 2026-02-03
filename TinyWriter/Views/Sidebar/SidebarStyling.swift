import SwiftUI

/// Configuration values for the liquid glass sidebar styling
/// Extracted for testability and consistency
enum SidebarStyling {
    // MARK: - Layout
    static let sidebarWidth: CGFloat = 240
    static let cornerRadius: CGFloat = 20
    static let verticalPadding: CGFloat = 12
    static let leadingPadding: CGFloat = 12

    // MARK: - Shadow Configuration
    static let primaryShadowRadius: CGFloat = 20
    static let primaryShadowYOffset: CGFloat = 10
    static let secondaryShadowRadius: CGFloat = 8
    static let secondaryShadowYOffset: CGFloat = 4

    /// Primary shadow opacity - stronger in dark mode for visibility
    static func primaryShadowOpacity(darkMode: Bool) -> Double {
        darkMode ? 0.4 : 0.15
    }

    /// Secondary shadow opacity - stronger in dark mode for visibility
    static func secondaryShadowOpacity(darkMode: Bool) -> Double {
        darkMode ? 0.25 : 0.08
    }

    // MARK: - Border Configuration
    static let borderLineWidth: CGFloat = 0.5

    /// Border gradient start opacity (top-left, brighter)
    static func borderStartOpacity(darkMode: Bool) -> Double {
        darkMode ? 0.2 : 0.3
    }

    /// Border gradient end opacity (bottom-right, dimmer)
    static func borderEndOpacity(darkMode: Bool) -> Double {
        darkMode ? 0.05 : 0.1
    }

    // MARK: - Shadow Rendering Flag
    /// Shadow must be applied OUTSIDE clipShape to be visible
    /// This flag documents this requirement for testing
    static let shadowAppliedOutsideClip = true
}
