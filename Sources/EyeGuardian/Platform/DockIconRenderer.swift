import AppKit

enum DockIconRenderer {
    private struct Key: Hashable {
        let percent: Int
        let style: RingStyle
        let palette: RingPalette
        let thickness: RingThickness
        let dark: Bool
    }

    private static var cache: [Key: NSImage] = [:]

    static func image(fatigue: Int, style: RingStyle, palette: RingPalette,
                      thickness: RingThickness, dark: Bool) -> NSImage {
        let percent = min(max(fatigue, 0), 100)
        let key = Key(percent: percent, style: style, palette: palette, thickness: thickness, dark: dark)
        if let cached = cache[key] {
            return cached
        }
        let image = render(percent, key: key)
        cache[key] = image
        return image
    }

    private static func render(_ percent: Int, key: Key) -> NSImage {
        let side: CGFloat = 512
        let look = IconArtwork.Look(fatigue: CGFloat(percent) / 100, compact: false,
                                    style: key.style, palette: key.palette,
                                    thickness: key.thickness, dark: key.dark)
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            IconArtwork.draw(in: rect, look: look)
            return true
        }
    }
}
