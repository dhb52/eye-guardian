import AppKit

/// Single source of truth for the app icon, the live Dock badge and the
/// menu bar template. Coordinates use a 1024×1024 canvas, origin bottom left.
enum IconArtwork {
    enum Surface {
        case appIcon
        case menuBar
    }

    enum PlateStyle {
        case automatic
        case white
    }

    struct Look {
        var fatigue: CGFloat
        var compact: Bool = false
        var style: RingStyle = .solid
        var palette: RingPalette = .spectrum
        var thickness: RingThickness = .regular
        var dark: Bool = true
        var surface: Surface = .appIcon
        var plate: PlateStyle = .automatic
        var paused: Bool = false
    }

    private struct Tone {
        let plateTop: NSColor
        let plateBottom: NSColor
        let ink: NSColor
        let pupil: NSColor
        let rim: NSColor
    }

    static let canvas: CGFloat = 1024
    /// Apple's icon grid: an 824×824 rounded square centred with a 100pt margin.
    static let plateInset: CGFloat = 100
    static let cornerRadius: CGFloat = 185
    static let glyphScale: CGFloat = 0.9
    static let center = NSPoint(x: 512, y: 512)
    static let ringRadius: CGFloat = 300
    /// Visible break at 12 o'clock, in degrees. Wide enough for the three-digit
    /// label at `gapNumberSize` to clear the arc tips and dot bodies with the same
    /// margin "88" had at 70°, so every value draws at one size. Round caps and dot
    /// bodies eat into their path, so each shape widens the break by its own
    /// angular half-width.
    static let ringGapDegrees: CGFloat = 92
    static let compactRingRadius: CGFloat = 320
    static let compactRingWidth: CGFloat = 96
    /// Below this width the dot ring collapses into an unreadable smudge.
    static let smallDetailWidth: CGFloat = 96
    /// Below this width a plate icon's gap number cannot be resolved.
    static let numberDetailWidth: CGFloat = 48

    /// Path angles whose round caps leave `ringGapDegrees` visible at 12 o'clock.
    static func arcAngles(radius: CGFloat, width: CGFloat) -> (start: CGFloat, sweep: CGFloat) {
        let capSweep = asin(min(1, width / 2 / radius)) * 180 / .pi
        let pathGap = ringGapDegrees + capSweep * 2
        return (90 + pathGap / 2, 360 - pathGap)
    }

    struct Eye {
        var halfWidth: CGFloat
        var upperApex: CGFloat
        var lowerApex: CGFloat
        var pupilRadius: CGFloat
        var lidFloor: CGFloat

        func scaled(_ factor: CGFloat) -> Eye {
            Eye(halfWidth: halfWidth * factor, upperApex: upperApex * factor,
                lowerApex: lowerApex * factor, pupilRadius: pupilRadius * factor,
                lidFloor: lidFloor * factor)
        }
    }

    static let detailedEye = Eye(halfWidth: 210, upperApex: 150, lowerApex: 105,
                                 pupilRadius: 70, lidFloor: 8)
    static let compactEye = detailedEye.scaled(1.15)

    static func tone(dark: Bool) -> (plateTop: NSColor, plateBottom: NSColor,
                                     ink: NSColor, pupil: NSColor, rim: NSColor) {
        if dark {
            return (NSColor(srgbRed: 0.149, green: 0.141, blue: 0.129, alpha: 1),
                    NSColor(srgbRed: 0.082, green: 0.078, blue: 0.075, alpha: 1),
                    NSColor(srgbRed: 0.969, green: 0.953, blue: 0.925, alpha: 1),
                    NSColor(srgbRed: 0.086, green: 0.082, blue: 0.078, alpha: 1),
                    NSColor.white.withAlphaComponent(0.07))
        }
        return (NSColor(srgbRed: 0.984, green: 0.980, blue: 0.969, alpha: 1),
                NSColor(srgbRed: 0.914, green: 0.898, blue: 0.867, alpha: 1),
                NSColor(srgbRed: 0.106, green: 0.102, blue: 0.098, alpha: 1),
                NSColor(srgbRed: 0.973, green: 0.957, blue: 0.929, alpha: 1),
                NSColor.black.withAlphaComponent(0.06))
    }

    /// Pure white plate: the pupil matches the plate so the eye reads as a cut-out.
    static func whiteTone() -> (plateTop: NSColor, plateBottom: NSColor,
                                ink: NSColor, pupil: NSColor, rim: NSColor) {
        (NSColor.white, NSColor.white,
         NSColor(srgbRed: 0.106, green: 0.102, blue: 0.098, alpha: 1),
         NSColor.white,
         NSColor.black.withAlphaComponent(0.06))
    }

    /// Green → amber → brand orange, interpolated in HSB so the mid range stays
    /// vivid instead of turning olive the way an sRGB blend does around 35%.
    /// The endpoints are chosen for the off-white plate: a deep green at 0% and
    /// the "Start a break now" fill (`Theme.accentDeep`, #A8540B) at 100%.
    static func spectrum(_ value: CGFloat) -> NSColor {
        let t = min(max(value, 0), 1)
        let hue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat
        if t < 0.5 {
            let k = t / 0.5
            hue = 142 + (38 - 142) * k
            saturation = 0.80 + (0.92 - 0.80) * k
            brightness = 0.60 + (0.82 - 0.60) * k
        } else {
            let k = (t - 0.5) / 0.5
            hue = 38 + (27.9 - 38) * k
            saturation = 0.92 + (0.9345 - 0.92) * k
            brightness = 0.82 + (0.6588 - 0.82) * k
        }
        return hsb(hue: hue, saturation: saturation, brightness: brightness)
    }

    private static func hsb(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> NSColor {
        let position = hue / 60
        let index = Int(floor(position)) % 6
        let fraction = position - floor(position)
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * fraction)
        let t = brightness * (1 - saturation * (1 - fraction))
        let rgb: (CGFloat, CGFloat, CGFloat)
        switch index {
        case 0: rgb = (brightness, t, p)
        case 1: rgb = (q, brightness, p)
        case 2: rgb = (p, brightness, t)
        case 3: rgb = (p, q, brightness)
        case 4: rgb = (t, p, brightness)
        default: rgb = (brightness, p, q)
        }
        return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }

    static func draw(in rect: NSRect, look: Look) {
        guard let context = NSGraphicsContext.current else { return }
        let scale = min(rect.width, rect.height) / canvas
        context.saveGraphicsState()
        context.cgContext.translateBy(x: rect.minX, y: rect.minY)
        context.cgContext.scaleBy(x: scale, y: scale)
        defer { context.restoreGraphicsState() }

        let fatigue = min(max(look.fatigue, 0), 1)
        if look.surface == .menuBar {
            drawMenuBarGlyph(fatigue: fatigue, look: look)
            if look.paused {
                drawPauseBadge(look: look, tint: nil)
            }
            return
        }
        let tint = look.plate == .white ? whiteTone() : tone(dark: look.dark)
        drawPlate(tint: tint)

        let fill = look.palette == .spectrum ? spectrum(fatigue) : tint.ink
        let track = tint.ink.withAlphaComponent(look.palette == .spectrum ? 0.12 : 0.16)

        // Optically match the system grid: the glyph sits inside the plate, not on its edge.
        context.saveGraphicsState()
        context.cgContext.translateBy(x: center.x, y: center.y)
        context.cgContext.scaleBy(x: glyphScale, y: glyphScale)
        context.cgContext.translateBy(x: -center.x, y: -center.y)

        if look.compact {
            drawArc(radius: compactRingRadius, width: compactRingWidth, fatigue: fatigue,
                    fill: fill, track: track)
            drawEye(center: center, eye: compactEye, fatigue: fatigue, tint: tint, catchesLight: false)
        } else {
            if look.style == .dotted && rect.width >= smallDetailWidth {
                drawDots(diameter: CGFloat(look.thickness.dotDiameter),
                         count: look.thickness.dotCount,
                         fatigue: fatigue, fill: fill, track: track)
            } else {
                drawArc(radius: ringRadius, width: CGFloat(look.thickness.ringWidth),
                        fatigue: fatigue, fill: fill, track: track)
            }
            drawEye(center: center, eye: detailedEye, fatigue: fatigue, tint: tint,
                    catchesLight: look.dark)
        }

        if !look.compact && rect.width >= numberDetailWidth {
            let numberColor = look.palette == .spectrum && look.dark ? fill : tint.ink
            drawGapNumber(fatigue, color: numberColor)
        }
        context.restoreGraphicsState()

        if look.paused {
            drawPauseBadge(look: look, tint: tint)
        }
    }

    /// A ⏸ badge a third of the canvas tall in the lower-right corner. The chip is
    /// knocked out on the menu bar and painted with the plate colour on the app icon,
    /// so the bars never merge with the ring underneath.
    private static let pauseGlyphHeight: CGFloat = canvas / 3

    private static func drawPauseBadge(look: Look,
                                       tint: (plateTop: NSColor, plateBottom: NSColor,
                                              ink: NSColor, pupil: NSColor,
                                              rim: NSColor)?) {
        let height = pauseGlyphHeight
        let barWidth = height * 0.20
        let gap = height * 0.17
        let padding = height * 0.10
        let width = barWidth * 2 + gap + padding * 2
        // Keep the app icon's chip inside the plate's rounded corner; the menu bar
        // glyph sits a little further from the button's right edge than its bottom.
        let insetY = look.surface == .appIcon ? plateInset + 60 : canvas * 0.075
        let insetX = look.surface == .appIcon ? insetY : canvas * 0.105
        let chip = NSRect(x: canvas - insetX - width, y: insetY,
                          width: width, height: height + padding * 2)
        let chipPath = NSBezierPath(roundedRect: chip, xRadius: padding, yRadius: padding)

        if let tint {
            tint.pupil.setFill()
            chipPath.fill()
        } else {
            guard let context = NSGraphicsContext.current else { return }
            context.saveGraphicsState()
            context.compositingOperation = .clear
            chipPath.fill()
            context.restoreGraphicsState()
        }

        let ink = tint?.ink ?? (look.dark ? NSColor.white : NSColor.black)
        ink.setFill()
        let left = chip.midX - gap / 2 - barWidth
        for x in [left, chip.midX + gap / 2] {
            NSBezierPath(roundedRect: NSRect(x: x, y: chip.minY + padding,
                                             width: barWidth, height: height),
                         xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        }
    }

    private static let menuBarGlyphScale: CGFloat = 1.2

    private static func drawMenuBarGlyph(fatigue: CGFloat, look: Look) {
        guard let context = NSGraphicsContext.current else { return }
        let monochrome = look.palette == .monochrome
        let ink: NSColor = look.dark ? .white : .black
        let fill = monochrome ? ink : spectrum(fatigue)
        let track = ink.withAlphaComponent(monochrome ? 0.35 : 0.18)

        context.saveGraphicsState()
        context.cgContext.translateBy(x: center.x, y: center.y)
        context.cgContext.scaleBy(x: menuBarGlyphScale, y: menuBarGlyphScale)
        context.cgContext.translateBy(x: -center.x, y: -center.y)

        if look.style == .dotted {
            drawDots(diameter: CGFloat(look.thickness.dotDiameter),
                     count: look.thickness.dotCount,
                     fatigue: fatigue, fill: fill, track: track)
        } else {
            drawArc(radius: ringRadius, width: CGFloat(look.thickness.ringWidth),
                    fatigue: fatigue, fill: fill, track: track)
        }
        drawMenuBarEye(center: center, eye: detailedEye, fatigue: fatigue, ink: ink)
        drawGapNumber(fatigue, color: fill)
        context.restoreGraphicsState()
    }

    private static func drawMenuBarEye(center: NSPoint, eye: Eye,
                                       fatigue: CGFloat, ink: NSColor) {
        let droop = fatigue * 0.55
        let lidApex = eye.upperApex + (eye.lidFloor - eye.upperApex) * droop
        let irisRadius = eye.pupilRadius * (1 - 0.28 * droop)
        let irisCenter = NSPoint(x: center.x,
                                 y: center.y + lidApex - irisRadius - eye.upperApex * 0.05)
        let shape = eyePath(center: center, eye: eye, lidApex: lidApex)
        ink.setFill()
        shape.fill()

        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        shape.addClip()
        context.compositingOperation = .clear
        NSBezierPath(ovalIn: NSRect(x: irisCenter.x - irisRadius,
                                    y: irisCenter.y - irisRadius,
                                    width: irisRadius * 2,
                                    height: irisRadius * 2)).fill()
        context.restoreGraphicsState()
    }

    private static func drawPlate(tint: (plateTop: NSColor, plateBottom: NSColor,
                                         ink: NSColor, pupil: NSColor, rim: NSColor)) {
        let body = NSRect(x: plateInset, y: plateInset,
                          width: canvas - plateInset * 2, height: canvas - plateInset * 2)
        let plate = NSBezierPath(roundedRect: body, xRadius: cornerRadius, yRadius: cornerRadius)
        NSGradient(colors: [tint.plateTop, tint.plateBottom])?.draw(in: plate, angle: -90)

        let rim = NSBezierPath(roundedRect: body.insetBy(dx: 5, dy: 5),
                               xRadius: cornerRadius - 5, yRadius: cornerRadius - 5)
        rim.lineWidth = 5
        tint.rim.setStroke()
        rim.stroke()
    }

    private static func drawArc(radius: CGFloat, width: CGFloat, fatigue: CGFloat,
                                fill: NSColor, track: NSColor) {
        let angles = arcAngles(radius: radius, width: width)
        let trackPath = NSBezierPath()
        trackPath.appendArc(withCenter: center, radius: radius, startAngle: angles.start,
                            endAngle: angles.start + angles.sweep, clockwise: false)
        trackPath.lineWidth = width
        trackPath.lineCapStyle = .round
        track.setStroke()
        trackPath.stroke()

        guard fatigue > 0.005 else { return }
        let progress = NSBezierPath()
        progress.appendArc(withCenter: center, radius: radius, startAngle: angles.start,
                           endAngle: angles.start + angles.sweep * fatigue, clockwise: false)
        progress.lineWidth = width
        progress.lineCapStyle = .round
        fill.setStroke()
        progress.stroke()
    }

    private static func drawDots(diameter: CGFloat, count: Int, fatigue: CGFloat,
                                 fill: NSColor, track: NSColor) {
        guard count > 0 else { return }
        let radius = diameter / 2
        let dotSweep = asin(min(1, radius / ringRadius)) * 2 * 180 / .pi
        let pitch = count > 1 ? (360 - ringGapDegrees - dotSweep) / CGFloat(count - 1) : 0
        let first = 90 + ringGapDegrees / 2 + dotSweep / 2
        for index in 0..<count {
            let progress = (CGFloat(index) + 0.5) / CGFloat(count)
            let angle = (first + pitch * CGFloat(index)) * .pi / 180
            let dot = NSBezierPath(ovalIn: NSRect(x: center.x + ringRadius * cos(angle) - radius,
                                                  y: center.y + ringRadius * sin(angle) - radius,
                                                  width: diameter, height: diameter))
            (progress <= fatigue ? fill : track).setFill()
            dot.fill()
        }
    }

    private static func drawEye(center: NSPoint, eye: Eye, fatigue: CGFloat,
                                tint: (plateTop: NSColor, plateBottom: NSColor,
                                       ink: NSColor, pupil: NSColor, rim: NSColor),
                                catchesLight: Bool) {
        let droop = fatigue * 0.55
        let lidApex = eye.upperApex + (eye.lidFloor - eye.upperApex) * droop
        // The iris rides with the lid instead of being sliced by it.
        let irisRadius = eye.pupilRadius * (1 - 0.28 * droop)
        let irisCenter = NSPoint(x: center.x, y: center.y + lidApex - irisRadius - eye.upperApex * 0.05)

        let shape = eyePath(center: center, eye: eye, lidApex: lidApex)
        tint.ink.setFill()
        shape.fill()

        let pupil = NSBezierPath(ovalIn: NSRect(x: irisCenter.x - irisRadius,
                                                y: irisCenter.y - irisRadius,
                                                width: irisRadius * 2,
                                                height: irisRadius * 2))
        NSGraphicsContext.current?.saveGraphicsState()
        shape.addClip()
        tint.pupil.setFill()
        pupil.fill()

        if catchesLight {
            let glintRadius = irisRadius * 0.26
            let glint = NSBezierPath(ovalIn: NSRect(x: irisCenter.x - irisRadius * 0.34 - glintRadius,
                                                    y: irisCenter.y + irisRadius * 0.26 - glintRadius,
                                                    width: glintRadius * 2, height: glintRadius * 2))
            tint.ink.setFill()
            glint.fill()
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    static func eyePath(center: NSPoint, eye: Eye, lidApex: CGFloat) -> NSBezierPath {
        let left = NSPoint(x: center.x - eye.halfWidth, y: center.y)
        let right = NSPoint(x: center.x + eye.halfWidth, y: center.y)
        let upperControl = lidApex * 4 / 3
        let lowerControl = -eye.lowerApex * 4 / 3
        let spread = eye.halfWidth * 0.44

        let path = NSBezierPath()
        path.move(to: left)
        path.curve(to: right,
                   controlPoint1: NSPoint(x: center.x - spread, y: center.y + upperControl),
                   controlPoint2: NSPoint(x: center.x + spread, y: center.y + upperControl))
        path.curve(to: left,
                   controlPoint1: NSPoint(x: center.x + spread, y: center.y + lowerControl),
                   controlPoint2: NSPoint(x: center.x - spread, y: center.y + lowerControl))
        path.close()
        return path
    }

    /// One label size for every value, so 88% and 100% draw identically.
    private static let gapNumberSize: CGFloat = 224

    private static func drawGapNumber(_ fatigue: CGFloat, color: NSColor) {
        let text = NSString(string: "\(Int((fatigue * 100).rounded()))")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: gapNumberSize, weight: .bold),
            .foregroundColor: color,
            .kern: -2,
        ]
        let bounds = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: center.x - bounds.width / 2,
                              y: center.y + ringRadius - bounds.height / 2),
                  withAttributes: attributes)
    }

    /// Renders the artwork into an sRGB PNG at the requested pixel size.
    static func png(pixels: Int, look: Look) -> Data? {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        draw(in: NSRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels)), look: look)
        NSGraphicsContext.restoreGraphicsState()

        guard let image = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    /// Renders the artwork into a bitmap-backed image of `points` × `scale` pixels.
    ///
    /// A `NSImage(size:flipped:drawingHandler:)` is captured by AppKit as an
    /// `NSCGImageSnapshotRep` on first draw — 8 MB per icon at 1024 px — and stays
    /// alive as long as the image does. A ready bitmap has no snapshot cost.
    static func image(points: CGFloat, scale: CGFloat, look: Look) -> NSImage {
        let side = max(1, points)
        let pixels = max(1, Int((side * scale).rounded()))
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: pixels, height: pixels,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: NSSize(width: side, height: side))
        }
        context.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        draw(in: NSRect(x: 0, y: 0, width: side, height: side), look: look)
        NSGraphicsContext.restoreGraphicsState()
        guard let cgImage = context.makeImage() else {
            return NSImage(size: NSSize(width: side, height: side))
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: side, height: side)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.addRepresentation(rep)
        return image
    }
}
