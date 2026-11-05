import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    init(model: AppModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = L10n.t("AppName")
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentViewController = NSHostingController(
            rootView: MainWindowView().environmentObject(model)
        )
        window.minSize = NSSize(width: 780, height: 520)
        let hasSavedFrame = UserDefaults.standard.object(forKey: "NSWindow Frame MainWindow") != nil
        window.setFrameAutosaveName("MainWindow")
        if !hasSavedFrame {
            window.setContentSize(NSSize(width: 900, height: 620))
            window.center()
        }
        window.isReleasedWhenClosed = false
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
