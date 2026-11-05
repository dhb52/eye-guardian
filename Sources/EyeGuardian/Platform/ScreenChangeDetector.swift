import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class ScreenChangeDetector {
    var onChange: (() -> Void)?

    private var timer: Timer?
    private var lastSignature: [UInt8]?
    private var busy = false

    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func start(interval: TimeInterval = 5) {
        guard timer == nil else { return }
        guard Self.hasPermission else { return }
        lastSignature = nil
        let timer = Timer(timeInterval: interval, target: self,
                          selector: #selector(captureTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        captureTick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastSignature = nil
        busy = false
    }

    @objc private func captureTick() {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            defer { self.busy = false }
            guard let signature = await Self.captureSignature() else { return }
            if let last = self.lastSignature, last.count == signature.count {
                var total = 0
                for index in 0..<signature.count {
                    total += abs(Int(last[index]) - Int(signature[index]))
                }
                let meanDifference = total / max(1, signature.count)
                if meanDifference > 4 {
                    self.onChange?()
                }
            }
            self.lastSignature = signature
        }
    }

    private static func captureSignature() async -> [UInt8]? {
        if #available(macOS 14.0, *) {
            return await screenKitSignature()
        }
        return legacySignature()
    }

    @available(macOS 14.0, *)
    private static func screenKitSignature() async -> [UInt8]? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return nil }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = 32
            configuration.height = 20
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                   configuration: configuration)
            return grayscaleSignature(from: image)
        } catch {
            return nil
        }
    }

    private static func legacySignature() -> [UInt8]? {
        guard let image = CGWindowListCreateImage(.null, .optionOnScreenOnly,
                                                  kCGNullWindowID, .nominalResolution) else {
            return nil
        }
        return grayscaleSignature(from: image)
    }

    private static func grayscaleSignature(from image: CGImage) -> [UInt8]? {
        let width = 32
        let height = 20
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        let drew: Bool = pixels.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Bool in
            guard let context = CGContext(data: buffer.baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }

        let count = width * height
        var result = [UInt8](repeating: 0, count: count)
        for index in 0..<count {
            let offset = index * 4
            result[index] = Self.luma(pixels[offset], pixels[offset + 1], pixels[offset + 2])
        }
        return result
    }

    private static func luma(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> UInt8 {
        let weighted = 299 * Int(red) + 587 * Int(green) + 114 * Int(blue)
        return UInt8(weighted / 1000)
    }
}
