import AppKit

enum StatusBarIconRenderer {
    private struct Key: Hashable {
        let percent: Int
        let size: StatusIconSize
    }

    private static var cache: [Key: NSImage] = [:]

    static func image(fatigue: Int, size: StatusIconSize) -> NSImage {
        let percent = min(max(fatigue, 0), 100)
        let key = Key(percent: percent, size: size)
        if let cached = cache[key] {
            return cached
        }
        let image = render(percent, size: size)
        cache[key] = image
        return image
    }

    private static func render(_ percent: Int, size: StatusIconSize) -> NSImage {
        let scale = CGFloat(size.points) / 18
        let side = CGFloat(size.points)
        let fatigue = CGFloat(percent) / 100
        let center = NSPoint(x: side / 2, y: side / 2)
        let radius = 7.05 * scale
        let lineWidth = 1.7 * scale
        let eye = IconArtwork.Eye(halfWidth: 4.5 * scale, upperApex: 3.2 * scale,
                                  lowerApex: 2.2 * scale, pupilRadius: 1.5 * scale,
                                  lidFloor: 0.2 * scale)

        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius,
                            startAngle: IconArtwork.arcStart,
                            endAngle: IconArtwork.arcStart + IconArtwork.arcSweep,
                            clockwise: false)
            track.lineWidth = lineWidth
            track.lineCapStyle = .round
            NSColor.black.withAlphaComponent(0.18).setStroke()
            track.stroke()

            if fatigue > 0.005 {
                let progress = NSBezierPath()
                progress.appendArc(withCenter: center, radius: radius,
                                   startAngle: IconArtwork.arcStart,
                                   endAngle: IconArtwork.arcStart + IconArtwork.arcSweep * fatigue,
                                   clockwise: false)
                progress.lineWidth = lineWidth
                progress.lineCapStyle = .round
                NSColor.black.setStroke()
                progress.stroke()
            }

            let shape = IconArtwork.eyePath(center: center, eye: eye, lidApex: eye.upperApex)
            NSColor.black.setFill()
            shape.fill()

            NSGraphicsContext.current?.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            let pupil = NSBezierPath(ovalIn: NSRect(x: center.x - eye.pupilRadius,
                                                    y: center.y - eye.pupilRadius,
                                                    width: eye.pupilRadius * 2,
                                                    height: eye.pupilRadius * 2))
            pupil.fill()
            NSGraphicsContext.current?.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }
}
