import SwiftUI

enum Theme {
    static let accent = Color(red: 0.431, green: 0.361, blue: 0.961)
    static let accentDeep = Color(red: 0.239, green: 0.161, blue: 0.62)
    static let cardCorner: CGFloat = 14
    static let sidebarWidth: CGFloat = 220

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, Color(red: 0.55, green: 0.42, blue: 1.0)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
