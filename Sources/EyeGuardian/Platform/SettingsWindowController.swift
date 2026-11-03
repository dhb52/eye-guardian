import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var languageObserver: NSObjectProtocol?

    init(model: AppModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = L10n.t("Settings")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentViewController = NSHostingController(
            rootView: SettingsView().environmentObject(model)
        )
        window.minSize = NSSize(width: 880, height: 620)
        window.setContentSize(NSSize(width: 920, height: 700))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        languageObserver = NotificationCenter.default.addObserver(
            forName: .eyeGuardianLanguageDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.languageDidChange()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func languageDidChange() {
        window?.title = L10n.t("Settings")
    }
}
