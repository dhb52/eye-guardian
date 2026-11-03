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
        let image = NSImage(size: NSSize(width: side, height: side),
                            flipped: false) { rect in
            IconArtwork.draw(in: rect, look: look)
            return true
        }
        image.isTemplate = key.template && key.palette == .monochrome
        return image
    }
}
