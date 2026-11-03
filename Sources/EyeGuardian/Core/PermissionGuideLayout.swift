import CoreGraphics

enum PermissionGuideLayout {
    static let panelSize = CGSize(width: 560, height: 124)
    static let anchorGap: CGFloat = 6
    static let fallbackBottomMargin: CGFloat = 28
    static let edgeInset: CGFloat = 8

    static func frame(settingsWindow: CGRect?, visibleFrame: CGRect) -> CGRect {
        let size = panelSize
        guard let settings = settingsWindow, settings.width > 0, settings.height > 0 else {
            return CGRect(x: visibleFrame.midX - size.width / 2,
                          y: visibleFrame.minY + fallbackBottomMargin,
                          width: size.width,
                          height: size.height)
        }

        let minX = visibleFrame.minX + edgeInset
        let maxX = max(minX, visibleFrame.maxX - size.width - edgeInset)
        let minY = visibleFrame.minY + edgeInset
        let maxY = max(minY, visibleFrame.maxY - size.height - edgeInset)

        let x = min(max(settings.midX - size.width / 2, minX), maxX)
        let y = min(max(settings.minY - anchorGap - size.height, minY), maxY)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
