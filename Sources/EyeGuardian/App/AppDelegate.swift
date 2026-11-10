import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var languageObserver: NSObjectProtocol?
    private var updateMenuCancellable: AnyCancellable?
    private var lastUpdateMenuTitle = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel.shared
        buildMainMenu()
        lastUpdateMenuTitle = model.updateMenuTitle
        updateMenuCancellable = model.$updateState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshUpdateMenuItem()
                }
            }
        languageObserver = NotificationCenter.default.addObserver(
            forName: .eyeGuardianLanguageDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.buildMainMenu()
            }
        }
        model.start()
        model.showMainWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateMenuCancellable?.cancel()
        updateMenuCancellable = nil
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
            self.languageObserver = nil
        }
        AppModel.shared.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppModel.shared.showMainWindow()
        return true
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: L10n.t("MenuAbout"),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        if AppModel.shared.isUpdateFeatureVisible {
            let updates = appMenu.addItem(withTitle: AppModel.shared.updateMenuTitle,
                                          action: #selector(checkForUpdates),
                                          keyEquivalent: "")
            updates.target = self
            updates.isEnabled = AppModel.shared.canCheckForUpdates
        }
        appMenu.addItem(.separator())
        let settingsItem = appMenu.addItem(withTitle: L10n.t("MenuSettings"),
                                           action: #selector(showSettings),
                                           keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.t("MenuHide"),
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: L10n.t("MenuHideOthers"),
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: L10n.t("MenuShowAll"),
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.t("MenuQuit"),
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: L10n.t("MenuEdit"))
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: L10n.t("MenuUndo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L10n.t("MenuRedo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L10n.t("MenuCut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.t("MenuCopy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.t("MenuPaste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.t("MenuSelectAll"),
                         action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: L10n.t("MenuWindow"))
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: L10n.t("MenuMinimize"),
                           action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: L10n.t("MenuZoom"),
                           action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: L10n.t("MenuBringAllToFront"),
                           action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        let openItem = windowMenu.addItem(withTitle: L10n.t("OpenApp"),
                                          action: #selector(showMainWindow), keyEquivalent: "")
        openItem.target = self
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func showSettings() {
        AppModel.shared.showSettings()
    }

    @objc private func checkForUpdates() {
        AppModel.shared.showUpdateSheet(checkIfNeeded: true)
    }

    private func refreshUpdateMenuItem() {
        let title = AppModel.shared.updateMenuTitle
        guard title != lastUpdateMenuTitle else { return }
        lastUpdateMenuTitle = title
        buildMainMenu()
    }

    @objc private func showMainWindow() {
        AppModel.shared.showMainWindow()
    }
}
