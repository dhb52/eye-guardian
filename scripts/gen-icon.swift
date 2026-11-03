import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
    let inset: CGFloat = 24
    let body = rect.insetBy(dx: inset, dy: inset)
    let path = NSBezierPath(roundedRect: body, xRadius: 112, yRadius: 112)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.43, green: 0.36, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.24, green: 0.16, blue: 0.62, alpha: 1),
    ])
    gradient?.draw(in: path, angle: -90)

    let center = NSPoint(x: side / 2, y: side / 2 + 40)
    let radius: CGFloat = 250

    NSColor.white.withAlphaComponent(0.22).setStroke()
    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    track.lineWidth = 26
    track.stroke()

    NSColor.white.setStroke()
    let ring = NSBezierPath()
    ring.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: -270, clockwise: true)
    ring.lineWidth = 26
    ring.stroke()

    let eyeCenter = NSPoint(x: side / 2, y: side / 2 + 30)
    let eyeWidth: CGFloat = 400
    let eyeHeight: CGFloat = 220
    let left = NSPoint(x: eyeCenter.x - eyeWidth / 2, y: eyeCenter.y)
    let right = NSPoint(x: eyeCenter.x + eyeWidth / 2, y: eyeCenter.y)

    let eye = NSBezierPath()
    eye.move(to: left)
    eye.curve(to: right,
              controlPoint1: NSPoint(x: eyeCenter.x - 110, y: eyeCenter.y + eyeHeight / 2),
              controlPoint2: NSPoint(x: eyeCenter.x + 110, y: eyeCenter.y + eyeHeight / 2))
    eye.curve(to: left,
              controlPoint1: NSPoint(x: eyeCenter.x + 110, y: eyeCenter.y - eyeHeight / 2),
              controlPoint2: NSPoint(x: eyeCenter.x - 110, y: eyeCenter.y - eyeHeight / 2))
    eye.lineWidth = 30
    eye.lineJoinStyle = .round
    eye.lineCapStyle = .round
    NSColor.white.setStroke()
    eye.stroke()

    let pupil = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x - 58, y: eyeCenter.y - 58,
                                            width: 116, height: 116))
    NSColor.white.setFill()
    pupil.fill()

    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to render icon\n".utf8))
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
