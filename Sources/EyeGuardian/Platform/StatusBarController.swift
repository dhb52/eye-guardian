import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private var lastTitle = ""

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: L10n.t("AppName"))
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeft
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refresh()
    }

    func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    func refresh() {
        let settings = model.settings
        var parts: [String] = []
        if settings.statusShowFatiguePercent {
            parts.append("\(model.fatiguePercent)%")
        }
        if settings.statusShowScreenTimeHours {
            parts.append(String(format: "%.1fh", Double(model.todayScreenMinutes) / 60.0))
        }
        if settings.statusShowScreenTimeMinutes {
            parts.append("\(model.todayScreenMinutes)m")
        }
        if settings.statusShowReminderCount {
            parts.append("\(model.todayReminderCount)x")
        }
        let title = parts.joined(separator: " · ")
        if title != lastTitle {
            statusItem.button?.title = title
            lastTitle = title
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let fatigue = NSMenuItem(
            title: "\(L10n.t("Fatigue")) \(model.fatiguePercent)%",
            action: nil, keyEquivalent: ""
        )
        fatigue.isEnabled = false
        menu.addItem(fatigue)

        let screen = NSMenuItem(
            title: L10n.f("ScreenTimeTodayFormat",
                         DurationFormat.abbreviated(minutes: model.todayScreenMinutes)),
            action: nil, keyEquivalent: ""
        )
        screen.isEnabled = false
        menu.addItem(screen)

        menu.addItem(.separator())

        let start = NSMenuItem(title: L10n.t("StartBreakNow"),
                               action: #selector(startBreak), keyEquivalent: "b")
        start.target = self
        start.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(start)

        let open = NSMenuItem(title: L10n.t("OpenApp"),
                              action: #selector(openApp), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let snooze = NSMenuItem(title: L10n.t("PauseNotification"),
                                action: nil, keyEquivalent: "")
        snooze.submenu = makeSnoozeMenu()
        menu.addItem(snooze)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: L10n.t("MenuSettings"),
                                  action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: L10n.t("QuitApp"),
                              action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func makeSnoozeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

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
