import AppKit

enum StatusBarIconRenderer {
    private struct Key: Hashable {
        let percent: Int
        let points: Int
        let style: RingStyle
        let palette: RingPalette
        let thickness: RingThickness
        let dark: Bool
        let template: Bool
    }

    private static var cache: [Key: NSImage] = [:]
    private static var order: [Key] = []
    /// Covers the Settings thumbnails (2 styles × 2 palettes × 3 thicknesses) plus a
    /// live preview. Evicted entries redraw on demand — a 52 px render is cheap.
    private static let cacheLimit = 32

    static func image(fatigue: Int, points: Int, style: RingStyle,
                      palette: RingPalette, thickness: RingThickness,
                      dark: Bool, template: Bool = true) -> NSImage {
        let percent = min(max(fatigue, 0), 100)
        let key = Key(percent: percent, points: points, style: style,
                      palette: palette, thickness: thickness, dark: dark, template: template)
        if let cached = cache[key] {
            return cached
        }
        let image = render(percent, key: key)
        cache[key] = image
        order.append(key)
        if order.count > cacheLimit {
            cache[order.removeFirst()] = nil
        }
        return image
    }

    private static func render(_ percent: Int, key: Key) -> NSImage {
        let side = CGFloat(AppSettings.clampIconSize(key.points))
        let look = IconArtwork.Look(
            fatigue: CGFloat(percent) / 100,
            compact: false,
            style: key.style,
            palette: key.palette,
            thickness: key.thickness,
            dark: key.dark,
            surface: .menuBar
        )
        let image = IconArtwork.image(points: side, scale: 2, look: look)
        image.isTemplate = key.template && key.palette == .monochrome
        return image
    }
}
