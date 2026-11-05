import AppKit

@MainActor
final class StatusBarController: NSObject {
    private struct IconState: Equatable {
        let percent: Int
        let points: Int
        let style: RingStyle
        let palette: RingPalette
        let thickness: RingThickness
        let dark: Bool
    }

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let mainMenu = NSMenu()
    private var lastTitle = ""
    private var lastIconState: IconState?
    private var appearanceObservation: NSKeyValueObservation?

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.setAccessibilityLabel(L10n.t("AppName"))
            button.imagePosition = .imageLeft
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.refresh() }
            }
        }

        mainMenu.autoenablesItems = false
        refresh()
    }

    func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    private var usesDarkMenuBar: Bool {
        let appearance = statusItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    func refresh() {
        let settings = model.settings
        let state = IconState(percent: model.fatiguePercent,
                              points: settings.effectiveStatusIconSize,
                              style: settings.ringStyle,
                              palette: settings.ringPalette,
                              thickness: settings.ringThickness,
                              dark: usesDarkMenuBar)
        if state != lastIconState {
            lastIconState = state
            statusItem.button?.image = StatusBarIconRenderer.image(
                fatigue: state.percent,
                points: state.points,
                style: state.style,
                palette: state.palette,
                thickness: state.thickness,
                dark: state.dark
            )
        }
        let parts = StatusBarTextFormatter.parts(fatiguePercent: model.fatiguePercent,
                                                 screenMinutes: model.todayScreenMinutes,
                                                 reminderCount: model.todayReminderCount,
                                                 settings: settings)
        let title = parts.joined(separator: " · ")
        if title != lastTitle {
            statusItem.button?.title = title
            lastTitle = title
        }
    }

    private func populateMainMenu() {
        mainMenu.removeAllItems()

        let fatigue = NSMenuItem(
            title: "\(L10n.t("Fatigue")) \(model.fatiguePercent)%",
            action: nil, keyEquivalent: ""
        )
        fatigue.isEnabled = false
        mainMenu.addItem(fatigue)

        let screen = NSMenuItem(
            title: L10n.f("ScreenTimeTodayFormat",
                         DurationFormat.abbreviated(minutes: model.todayScreenMinutes)),
            action: nil, keyEquivalent: ""
        )
        screen.isEnabled = false
        mainMenu.addItem(screen)

        mainMenu.addItem(.separator())

        let start = NSMenuItem(title: L10n.t("StartBreakNow"),
                               action: #selector(startBreak), keyEquivalent: "b")
        start.target = self
        start.keyEquivalentModifierMask = [.control, .option, .command]
        mainMenu.addItem(start)

        let open = NSMenuItem(title: L10n.t("OpenApp"),
                              action: #selector(openApp), keyEquivalent: "")
        open.target = self
        mainMenu.addItem(open)

        let pause = NSMenuItem(title: L10n.t("PauseNotification"),
                               action: nil, keyEquivalent: "")
        pause.submenu = makePauseMenu()
        mainMenu.addItem(pause)

        mainMenu.addItem(.separator())

        let settings = NSMenuItem(title: L10n.t("MenuSettings"),
                                  action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        mainMenu.addItem(settings)

        let quit = NSMenuItem(title: L10n.t("QuitApp"),
                              action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        mainMenu.addItem(quit)
    }

    private func makePauseMenu(showsTitle: Bool = false) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if showsTitle {
            let header = NSMenuItem(title: L10n.t("PauseNotification"),
                                    action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        }

        if let until = model.snoozeUntil, until > Date() {
            let paused = NSMenuItem(
                title: L10n.f("PausedUntil", timeString(until)),
                action: nil, keyEquivalent: ""
            )
            paused.isEnabled = false
            menu.addItem(paused)

            let resume = NSMenuItem(title: L10n.t("ResumeReminders"),
                                    action: #selector(resumeReminders), keyEquivalent: "")
            resume.target = self
            menu.addItem(resume)
            return menu
        }

        let options: [(String, Int)] = [
            (L10n.t("Snooze30"), 30),
            (L10n.t("Snooze1h"), 60),
            (L10n.t("Snooze2h"), 120),
            (L10n.t("Snooze6h"), 360),
            (L10n.t("SnoozeTomorrow"), -1),
        ]
        for (title, tag) in options {
            let item = NSMenuItem(title: title, action: #selector(snoozeAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            menu.addItem(item)
        }
        return menu
    }

    private func timeString(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        let menu: NSMenu
        if isRightClick {
            populateMainMenu()
            menu = mainMenu
        } else {
            menu = makePauseMenu(showsTitle: true)
        }
        guard let button = statusItem.button else { return }
        button.highlight(true)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        button.highlight(false)
    }

    @objc private func startBreak() {
        model.startBreakNow()
    }

    @objc private func openApp() {
        model.showMainWindow()
    }

    @objc private func openSettings() {
        model.showSettings()
    }

    @objc private func resumeReminders() {
        model.resumeReminders()
        refresh()
    }

    @objc private func snoozeAction(_ sender: NSMenuItem) {
        switch sender.tag {
        case 30: model.snooze(.minutes30)
        case 60: model.snooze(.hour1)
        case 120: model.snooze(.hours2)
        case 360: model.snooze(.hours6)
        default: model.snooze(.untilTomorrow)
        }
        refresh()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
