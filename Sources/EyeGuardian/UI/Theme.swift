import SwiftUI

enum Theme {
    static let accent = Color(red: 0.941, green: 0.576, blue: 0.169)
    static let accentDeep = Color(red: 0.659, green: 0.329, blue: 0.043)
    static let cardCorner: CGFloat = 14
    static let sidebarWidth: CGFloat = 220

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, Color(red: 1.0, green: 0.769, blue: 0.420)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
