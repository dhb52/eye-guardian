import AppKit

enum DockIconRenderer {
    private static var cache: [Int: NSImage] = [:]

    static func image(fatigue: Int) -> NSImage {
        let value = min(max(fatigue, 0), 100)
        if let cached = cache[value] {
            return cached
        }
        let image = render(value)
        cache[value] = image
        return image
    }

    private static func render(_ fatigue: Int) -> NSImage {
        let side: CGFloat = 512
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let body = rect.insetBy(dx: 24, dy: 24)
            let background = NSBezierPath(roundedRect: body, xRadius: 112, yRadius: 112)
            let gradient = NSGradient(colors: [
                NSColor(calibratedRed: 0.43, green: 0.36, blue: 0.96, alpha: 1),
                NSColor(calibratedRed: 0.24, green: 0.16, blue: 0.62, alpha: 1),
            ])
            gradient?.draw(in: background, angle: -90)

            let center = NSPoint(x: side / 2, y: side / 2 + 62)
            let radius: CGFloat = 140

            NSColor.white.withAlphaComponent(0.22).setStroke()
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = 24
            track.stroke()

            if fatigue > 0 {
                NSColor.white.setStroke()
                let progress = NSBezierPath()
                let endAngle = 90 - 360 * CGFloat(fatigue) / 100
                progress.appendArc(withCenter: center, radius: radius,
                                   startAngle: 90, endAngle: endAngle, clockwise: true)
                progress.lineWidth = 24
                progress.lineCapStyle = .round
                progress.stroke()
            }

            let eyeWidth: CGFloat = 210
            let eyeHeight: CGFloat = 116
            let left = NSPoint(x: center.x - eyeWidth / 2, y: center.y)
            let right = NSPoint(x: center.x + eyeWidth / 2, y: center.y)
            let eye = NSBezierPath()
            eye.move(to: left)
            eye.curve(to: right,
                      controlPoint1: NSPoint(x: center.x - 58, y: center.y + eyeHeight / 2),
                      controlPoint2: NSPoint(x: center.x + 58, y: center.y + eyeHeight / 2))
            eye.curve(to: left,
                      controlPoint1: NSPoint(x: center.x + 58, y: center.y - eyeHeight / 2),
                      controlPoint2: NSPoint(x: center.x - 58, y: center.y - eyeHeight / 2))
            eye.lineWidth = 15
            eye.lineJoinStyle = .round
            NSColor.white.setStroke()
            eye.stroke()

            let pupil = NSBezierPath(ovalIn: NSRect(x: center.x - 30, y: center.y - 30,
                                                    width: 60, height: 60))
            NSColor.white.setFill()
            pupil.fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 64, weight: .semibold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph,
            ]
            let textRect = NSRect(x: 0, y: 34, width: side, height: 84)
            NSString(string: "\(fatigue)%").draw(in: textRect, withAttributes: attributes)
            return true
        }
    }
}
