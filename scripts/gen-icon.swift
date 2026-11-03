import AppKit

@main
enum GenIcon {
    /// Brand state: part-filled arc so the static icon shows both fill and track.
    static let brandFatigue: CGFloat = 0.35

    static let entries: [(name: String, pixels: Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]

    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let iconset = arguments.count > 0 ? arguments[0] : "build/AppIcon.iconset"
        let preview = arguments.count > 1 ? arguments[1] : nil

        let directory = URL(fileURLWithPath: iconset)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var cache: [Int: Data] = [:]
        for entry in entries {
            let data: Data
            if let cached = cache[entry.pixels] {
                data = cached
            } else {
                let look = IconArtwork.Look(fatigue: brandFatigue,
                                            compact: entry.pixels <= 32,
                                            showsNumber: false,
                                            style: .solid,
                                            palette: .spectrum,
                                            thickness: .regular,
                                            dark: true)
                guard let rendered = IconArtwork.png(pixels: entry.pixels, look: look) else {
                    FileHandle.standardError.write(Data("failed to render \(entry.pixels)px icon\n".utf8))
                    exit(1)
                }
                cache[entry.pixels] = rendered
                data = rendered
            }
            try data.write(to: directory.appendingPathComponent("\(entry.name).png"))
        }

        if let preview, let data = cache[1024] {
            try? data.write(to: URL(fileURLWithPath: preview))
        }
        print("wrote \(directory.path)")
    }
}
