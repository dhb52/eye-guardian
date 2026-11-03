import AppKit

/// Single source of truth for the app icon, the live Dock badge and the
/// menu bar template. Coordinates use a 1024×1024 canvas, origin bottom left.
enum IconArtwork {
    enum Surface {
        case appIcon
        case menuBar
    }

    struct Look {
        var fatigue: CGFloat
        var compact: Bool = false
        var style: RingStyle = .solid
        var palette: RingPalette = .spectrum
        var thickness: RingThickness = .regular
        var dark: Bool = true
        var surface: Surface = .appIcon
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
    /// Visible break at 12 o'clock, in degrees — measured from the reference icon
    /// (arc tips at ±35.8° off vertical). Round caps and dot bodies eat into their
    /// path, so each shape widens the break by its own angular half-width.
    static let ringGapDegrees: CGFloat = 70
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

    /// Green → amber → red, interpolated in HSB so the mid range stays vivid
    /// instead of turning olive the way an sRGB blend does around 35%.
    static func spectrum(_ value: CGFloat) -> NSColor {
        let t = min(max(value, 0), 1)
        let hue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat
        if t < 0.5 {
            let k = t / 0.5
            hue = 142 + (38 - 142) * k
            saturation = 0.72 + (0.92 - 0.72) * k
            brightness = 0.78 + (1 - 0.78) * k
        } else {
            let k = (t - 0.5) / 0.5
            hue = 38 + (4 - 38) * k
            saturation = 0.92
            brightness = 1
        }
        return hsb(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Spectrum on a light plate is darkened so the arc still reads as a shape,
    /// and the number switches to ink because a lime number on off-white does not.
    private static func darkened(_ color: NSColor, by factor: CGFloat) -> NSColor {
        let c = color.usingColorSpace(.sRGB) ?? color
        return NSColor(srgbRed: c.redComponent * factor, green: c.greenComponent * factor,
                       blue: c.blueComponent * factor, alpha: 1)
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
            return
        }
        let tint = tone(dark: look.dark)
        drawPlate(tint: tint)

        var fill = look.palette == .spectrum ? spectrum(fatigue) : tint.ink
        if look.palette == .spectrum && !look.dark {
            fill = darkened(fill, by: 0.8)
        }
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

    /// Two digits nearly fill the gap; three digits shrink to stay clear of the arc tips.
    private static let gapNumberSize: CGFloat = 224

    private static func drawGapNumber(_ fatigue: CGFloat, color: NSColor) {
        let text = NSString(string: "\(Int((fatigue * 100).rounded()))")
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: gapNumberSize, weight: .bold),
            .foregroundColor: color,
            .kern: -2,
        ]
        var size = text.size(withAttributes: attributes)
        let available = 2 * ringRadius * sin(ringGapDegrees / 2 * .pi / 180) * 0.95
        if size.width > available {
            attributes[.font] = NSFont.monospacedDigitSystemFont(ofSize: gapNumberSize * available / size.width,
                                                                weight: .bold)
            size = text.size(withAttributes: attributes)
        }
        text.draw(at: NSPoint(x: center.x - size.width / 2,
                              y: center.y + ringRadius - size.height / 2),
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
}
