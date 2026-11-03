import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(model: AppModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = L10n.t("Settings")
        window.contentViewController = NSHostingController(
            rootView: SettingsView().environmentObject(model)
        )
        window.setContentSize(NSSize(width: 780, height: 600))
        window.minSize = NSSize(width: 760, height: 580)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
