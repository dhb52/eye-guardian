import AppKit
import SwiftUI

@MainActor
final class PermissionGuideController {
    private var panel: NSPanel?
    private var trackingTimer: Timer?
    private(set) var visibleKind: PermissionKind?

    var isVisible: Bool { visibleKind != nil }

    func show(_ kind: PermissionKind) {
        visibleKind = kind

        let panel = panel ?? makePanel()
        self.panel = panel

        let hosting = NSHostingView(
            rootView: PermissionGuideView(kind: kind, onDragEnded: { [weak self] in
                self?.hide()
            })
        )
        hosting.frame = NSRect(origin: .zero, size: PermissionGuideLayout.panelSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.setContentSize(PermissionGuideLayout.panelSize)

        updateFrame()
        panel.orderFrontRegardless()
        startTracking()
    }

    func hide() {
        stopTracking()
        visibleKind = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: PermissionGuideLayout.panelSize),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.isMovable = false
        return panel
    }

    private func updateFrame() {
        guard let panel else { return }
        let settingsWindow = SystemSettingsWindowLocator.windowFrame()
        let screen = settingsWindow.flatMap { self.screen(containing: $0) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let frame = PermissionGuideLayout.frame(settingsWindow: settingsWindow,
                                                visibleFrame: screen.visibleFrame)
        panel.setFrame(frame, display: true)
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }

    private func startTracking() {
        guard trackingTimer == nil else { return }
        let timer = Timer(timeInterval: 0.15, target: self,
                          selector: #selector(trackingTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer
    }

    private func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
    }

    @objc private func trackingTick() {
        updateFrame()
    }
}

enum SystemSettingsWindowLocator {
    static func windowFrame() -> CGRect? {
        guard let settings = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.systempreferences")
            .first else {
            return nil
        }

        let pid = settings.processIdentifier
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return windows.compactMap { info -> CGRect? in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: NSNumber],
                  let x = bounds["X"]?.doubleValue,
                  let y = bounds["Y"]?.doubleValue,
                  let width = bounds["Width"]?.doubleValue,
                  let height = bounds["Height"]?.doubleValue,
                  width > 0, height > 0 else {
                return nil
            }
            return CGRect(x: x,
                          y: primaryHeight - y - height,
                          width: width,
                          height: height)
        }
        .max { $0.width * $0.height < $1.width * $1.height }
    }
}
