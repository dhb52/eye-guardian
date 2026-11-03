import AppKit
import ApplicationServices

@MainActor
final class UsageDetector {
    enum Kind {
        case mouse
        case keyboard
        case screen
    }

    private(set) var lastMouse: Date?
    private(set) var lastKeyboard: Date?
    private(set) var lastScreen: Date?

    var onChange: (() -> Void)?

    private var globalMouse: Any?
    private var localMouse: Any?
    private var globalKeyboard: Any?
    private var localKeyboard: Any?

    private static let mouseMask: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp, .leftMouseDragged, .rightMouseDragged,
        .otherMouseDragged, .scrollWheel,
    ]

    private static let keyboardMask: NSEvent.EventTypeMask = [.keyDown, .keyUp]

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func start(mouse: Bool, keyboard: Bool) {
        stop()

        if mouse {
            globalMouse = NSEvent.addGlobalMonitorForEvents(matching: Self.mouseMask) { [weak self] _ in
                Task { @MainActor in self?.mark(.mouse) }
            }
            localMouse = NSEvent.addLocalMonitorForEvents(matching: Self.mouseMask) { [weak self] event in
                Task { @MainActor in self?.mark(.mouse) }
                return event
            }
        }

        if keyboard {
            globalKeyboard = NSEvent.addGlobalMonitorForEvents(matching: Self.keyboardMask) { [weak self] _ in
                Task { @MainActor in self?.mark(.keyboard) }
            }
            localKeyboard = NSEvent.addLocalMonitorForEvents(matching: Self.keyboardMask) { [weak self] event in
                Task { @MainActor in self?.mark(.keyboard) }
                return event
            }
        }
    }

    func stop() {
        if let globalMouse {
            NSEvent.removeMonitor(globalMouse)
            self.globalMouse = nil
        }
        if let localMouse {
            NSEvent.removeMonitor(localMouse)
            self.localMouse = nil
        }
        if let globalKeyboard {
            NSEvent.removeMonitor(globalKeyboard)
            self.globalKeyboard = nil
        }
        if let localKeyboard {
            NSEvent.removeMonitor(localKeyboard)
            self.localKeyboard = nil
        }
        lastMouse = nil
        lastKeyboard = nil
        lastScreen = nil
    }

    func mark(_ kind: Kind) {
        let now = Date()
        switch kind {
        case .mouse: lastMouse = now
        case .keyboard: lastKeyboard = now
        case .screen: lastScreen = now
        }
        onChange?()
    }

    var lastActivityAt: Date? {
        [lastMouse, lastKeyboard, lastScreen].compactMap { $0 }.max()
    }
}
