import AppKit
import SwiftUI

final class ReminderPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}

@MainActor
final class ReminderWindowController {
    private var panels: [ReminderPanel] = []
    private weak var previousApp: NSRunningApplication?
    private var activeObserver: NSObjectProtocol?

    func show(session: BreakSessionModel, onSkip: @escaping () -> Void) {
        hide(restoreFocus: false)
        previousApp = NSWorkspace.shared.frontmostApplication

        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.bringPanelsForward()
            }
        }

        let escape: () -> Void = { [weak self, weak session] in
            guard let session else { return }
            if session.requestSkip() {
                onSkip()
            } else if case .challenge = session.stage {
                self?.activateForInput()
            }
        }

        if session.style == .miniPopup {
            presentMini(session: session, onSkip: onSkip, escape: escape)
        } else {
            presentFullScreen(session: session, onSkip: onSkip, escape: escape)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide(restoreFocus: Bool = true) {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()

        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }

        if restoreFocus,
           let previousApp,
           previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp.activate(options: [])
        }
        previousApp = nil
    }

    func activateForInput() {
        guard let panel = panels.first else { return }
        panel.styleMask.remove(.nonactivatingPanel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func bringPanelsForward() {
        guard let first = panels.first else { return }
        for panel in panels { panel.orderFrontRegardless() }
        if !first.isKeyWindow { first.makeKey() }
    }

    private func presentFullScreen(session: BreakSessionModel,
                                   onSkip: @escaping () -> Void,
                                   escape: @escaping () -> Void) {
        for (index, screen) in NSScreen.screens.enumerated() {
            let panel = ReminderPanel(contentRect: screen.frame,
                                      styleMask: [.borderless],
                                      backing: .buffered,
                                      defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                        .fullScreenAuxiliary, .ignoresCycle]
            panel.isOpaque = true
            panel.backgroundColor = .black
            panel.hasShadow = false
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.onEscape = escape
            panel.contentViewController = NSHostingController(
                rootView: FullScreenReminderView(session: session, onSkip: onSkip)
            )
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            if index == 0 {
                panel.makeKey()
            }
            panels.append(panel)
        }
    }

    private func presentMini(session: BreakSessionModel,
                             onSkip: @escaping () -> Void,
                             escape: @escaping () -> Void) {
        let size = NSSize(width: 360, height: 230)
        let panel = ReminderPanel(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered,
                                  defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.onEscape = escape
        panel.contentViewController = NSHostingController(
            rootView: MiniReminderView(session: session, onSkip: onSkip)
        )
        panel.setContentSize(size)

        if let visible = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 16,
                                         y: visible.maxY - size.height - 16))
        }
        panel.orderFrontRegardless()
        panels.append(panel)
    }
}
