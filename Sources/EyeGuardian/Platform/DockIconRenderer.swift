import AppKit

enum DockIconRenderer {
    private struct Key: Hashable {
        let percent: Int
        let style: RingStyle
        let palette: RingPalette
        let thickness: RingThickness
        let dark: Bool
    }

    private static var cachedKey: Key?
    private static var cachedImage: NSImage?

    static func image(fatigue: Int, style: RingStyle, palette: RingPalette,
                      thickness: RingThickness, dark: Bool) -> NSImage {
        let percent = min(max(fatigue, 0), 100)
        let key = Key(percent: percent, style: style, palette: palette, thickness: thickness, dark: dark)
        if key == cachedKey, let cachedImage {
            return cachedImage
        }
        let image = render(percent, key: key)
        cachedKey = key
        cachedImage = image
        return image
    }

    private static func render(_ percent: Int, key: Key) -> NSImage {
        let look = IconArtwork.Look(fatigue: CGFloat(percent) / 100, compact: false,
                                    style: key.style, palette: key.palette,
                                    thickness: key.thickness, dark: key.dark)
        return IconArtwork.image(points: 512, scale: 1, look: look)
    }
}
