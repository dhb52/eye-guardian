import SwiftUI

enum Theme {
    static let accent = Color(red: 0.941, green: 0.576, blue: 0.169)
    static let accentDeep = Color(red: 0.659, green: 0.329, blue: 0.043)
    static let cardCorner: CGFloat = 14
    static let sidebarWidth: CGFloat = 220
    static let selection = Color(nsColor: .controlAccentColor)
    static let settingsSidebarWidth: CGFloat = 216
    static let settingsCardCorner: CGFloat = 12

    /// Content surface behind the grouped cards.
    static let page = Color(nsColor: .controlBackgroundColor)
    /// Surface of a grouped card sitting on `page`.
    static let group = Color(nsColor: .windowBackgroundColor)
    static let hairline = Color(nsColor: .separatorColor)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, Color(red: 1.0, green: 0.769, blue: 0.420)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
