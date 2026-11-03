import AppKit
import Combine
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Section: CaseIterable, Identifiable {
        case today
        case analysis
        case rules

        var id: String { String(describing: self) }

        var titleKey: String {
            switch self {
            case .today: return "NavToday"
            case .analysis: return "NavAnalysis"
            case .rules: return "NavRules"
            }
        }

        var systemImage: String {
            switch self {
            case .today: return "sun.max"
            case .analysis: return "chart.bar.xaxis"
            case .rules: return "calendar"
            }
        }
    }

    enum SnoozeDuration {
        case minutes30
        case hour1
        case hours2
        case hours6
        case untilTomorrow
    }

    @Published var settings: AppSettings {
        didSet {
            persistSettings()
            applySettings()
        }
    }
    @Published private(set) var fatigue: Double = 0
    @Published private(set) var isScreenActive = false
    @Published private(set) var isResting = false
    @Published private(set) var isSnoozed = false
    @Published private(set) var snoozeUntil: Date?
    @Published private(set) var todayScreenMinutes = 0
    @Published private(set) var todayReminderCount = 0
    @Published var selectedSection: Section = .today
    @Published var isHelpPresented = false


    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var screenRecordingTrusted = false
    @Published private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var loginItemError: String?

    let store: EventStore
    let systemState = SystemStateObserver()
    let usageDetector = UsageDetector()
    let screenDetector = ScreenChangeDetector()

    private let scheduler = BreakScheduler()
    private let reminderWindows = ReminderWindowController()
    private let notifications = NotificationService()
    private(set) var breakSession: BreakSessionModel?

    private var engine = FatigueEngine()
    private var timer: Timer?
    private var lastTick = Date()
    private var lastSampleAt = Date()
    private var currentDay = Calendar.current.startOfDay(for: Date())
    private var todayScreenSeconds: Double = 0
    private var napToken: NSObjectProtocol?
    private var detectorConfig: (mouse: Bool, keyboard: Bool, screen: Bool) = (false, false, false)
    private var activeObserver: NSObjectProtocol?
    private var lastDockPercent = -1
    private var loginItemDesired: Bool?
    private var lastDetectScreenChanges = false
    private var lastDetectKeyboard = false

    private let hotKey = HotKeyManager()
    private(set) lazy var statusBar = StatusBarController(model: self)

    private(set) lazy var mainWindowController = MainWindowController(model: self)
    private(set) lazy var settingsWindowController = SettingsWindowController(model: self)

    private enum Keys {
        static let settings = "settings.v1"
        static let snoozeUntil = "snooze.until"
    }

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.settings),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
        store = AppModel.makeStore()

        if let until = defaults.object(forKey: Keys.snoozeUntil) as? Date {
            snoozeUntil = until
            isSnoozed = until > Date()
            scheduler.snooze(until: until)
        }
    }

    var fatiguePercent: Int { Int(fatigue.rounded()) }

    var stateText: String {
        if isSnoozed, let until = snoozeUntil {
            let time = DateFormatter.localizedString(from: until, dateStyle: .none, timeStyle: .short)
            return L10n.f("PausedUntil", time)
        }
        return isScreenActive ? L10n.t("StateUsing") : L10n.t("StateResting")
    }

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        lastTick = Date()
        lastSampleAt = Date()
        currentDay = Calendar.current.startOfDay(for: Date())
        refreshTodayStats()

        napToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Fatigue monitoring"
        )
        systemState.start()
        accessibilityTrusted = UsageDetector.isAccessibilityTrusted
        screenRecordingTrusted = ScreenChangeDetector.hasPermission
        lastDetectKeyboard = settings.detectKeyboard
        screenDetector.onChange = { [weak self] in
            self?.usageDetector.mark(.screen)
        }
        configureDetectors(force: true)
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
        refreshPermissions()

        notifications.onStartBreak = { [weak self] in self?.startBreakNow() }
        notifications.onSkip = { [weak self] in self?.skipCurrentReminder() }
        notifications.onOpenApp = { [weak self] in self?.showMainWindow() }
        notifications.start { [weak self] status in
            self?.notificationAuthorization = status
        }
        refreshNotificationAuthorization()

        let timer = Timer(timeInterval: 1, target: self,
                          selector: #selector(handleTimer), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        _ = statusBar
        hotKey.onTrigger = { [weak self] in self?.startBreakNow() }
        hotKey.register()
        applyActivationPolicy()
        statusBar.setVisible(settings.showStatusBarIcon || !settings.showDockIcon)
        statusBar.refresh()
        updateDockIcon(force: true)
        applyLaunchAtLogin()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
        systemState.stop()
        usageDetector.stop()
        screenDetector.stop()
        reminderWindows.hide(restoreFocus: false)
        breakSession = nil
        if let token = napToken {
            ProcessInfo.processInfo.endActivity(token)
            napToken = nil
        }
        store.insertSample(at: Date(), fatigue: engine.percent, isUsing: isScreenActive)
        store.close()
    }

    // MARK: - Tick

    @objc private func handleTimer() {
        tick()
    }

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        let dt = min(max(elapsed, 0), 2)
        lastTick = now

        let effective = settings.effective()
        let timing = RuleResolver.effective(
            now: now,
            rules: settings.rules,
            fallbackWork: effective.workMinutes,
            fallbackRest: effective.restMinutes
        )

        let locked = systemState.isLocked
        let asleep = systemState.isAsleep
        let smart = settings.usageMode == .smart && !settings.movieMode
        let anyDetector = settings.detectMouse || settings.detectKeyboard || settings.detectScreenChanges

        let using: Bool
        if settings.movieMode || settings.usageMode == .dumb || !anyDetector {
            using = !locked && !asleep
        } else {
            let activityWindow: TimeInterval = 60
            let mouseActive = settings.detectMouse &&
                (usageDetector.lastMouse.map { now.timeIntervalSince($0) <= activityWindow } ?? false)
            let keyboardActive = settings.detectKeyboard &&
                (usageDetector.lastKeyboard.map { now.timeIntervalSince($0) <= activityWindow } ?? false)
            let screenChangeActive = settings.detectScreenChanges &&
                (usageDetector.lastScreen.map { now.timeIntervalSince($0) <= activityWindow } ?? false)
            using = mouseActive || keyboardActive || screenChangeActive
        }

        let resting = RestDetector.isResting(
            now: now,
            lastActivityAt: usageDetector.lastActivityAt,
            locked: locked,
            asleep: asleep,
            inBreak: false,
            smartMode: smart
        )
        let screenActive = using && !locked && !asleep

        engine.tick(deltaSeconds: dt,
                    screenActive: screenActive,
                    resting: resting,
                    workMinutes: timing.workMinutes,
                    restMinutes: timing.restMinutes)

        if abs(engine.fatigue - fatigue) > 0.0001 {
            fatigue = engine.fatigue
        }
        updateDockIcon()
        statusBar.refresh()
        if isScreenActive != screenActive { isScreenActive = screenActive }
        if isResting != resting { isResting = resting }

        let snoozed = snoozeUntil.map { $0 > now } ?? false
        if isSnoozed != snoozed { isSnoozed = snoozed }

        let day = Calendar.current.startOfDay(for: now)
        if day != currentDay {
            currentDay = day
            refreshTodayStats()
        }

        if screenActive {
            todayScreenSeconds += dt
        }
        let minutes = Int(todayScreenSeconds / 60)
        if minutes != todayScreenMinutes {
            todayScreenMinutes = minutes
        }

        if now.timeIntervalSince(lastSampleAt) >= 60 {
            store.insertSample(at: now, fatigue: engine.percent, isUsing: screenActive)
            lastSampleAt = now
            refreshTodayStats()
        }

        if let session = breakSession {
            if session.update(now: now) {
                finishBreak()
            }
        } else {
            let config = schedulerConfig(effective)
            let ratePerSecond = screenActive ? 100.0 / (Double(timing.workMinutes) * 60) : 0
            let decision = scheduler.evaluate(
                now: now,
                fatigue: engine.fatigue,
                ratePerSecond: ratePerSecond,
                config: config,
                todayScreenMinutes: todayScreenMinutes,
                inBreak: false
            )
            handle(decision, effective: effective)
        }
    }

    private func refreshTodayStats() {
        let stats = store.todayStats(now: Date())
        todayScreenMinutes = stats.screenMinutes
        todayReminderCount = stats.reminderCount
        todayScreenSeconds = Double(stats.screenMinutes * 60)
    }

    // MARK: - Settings

    private func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Keys.settings)
    }

    private func applySettings() {
        if settings.detectKeyboard && !lastDetectKeyboard
            && !UsageDetector.isAccessibilityTrusted {
            UsageDetector.requestAccessibility()
        }
        lastDetectKeyboard = settings.detectKeyboard

        if settings.detectScreenChanges && !lastDetectScreenChanges
            && !ScreenChangeDetector.hasPermission {
            ScreenChangeDetector.requestPermission()
        }
        lastDetectScreenChanges = settings.detectScreenChanges

        configureDetectors(force: false)
        applyActivationPolicy()
        statusBar.setVisible(settings.showStatusBarIcon || !settings.showDockIcon)
        statusBar.refresh()
        updateDockIcon(force: true)
        applyLaunchAtLogin()
    }

    private func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = settings.showDockIcon ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if policy == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateDockIcon(force: Bool = false) {
        let percent = engine.percent
        guard force || percent != lastDockPercent else { return }
        lastDockPercent = percent
        NSApp.applicationIconImage = DockIconRenderer.image(fatigue: percent)
    }

    private func applyLaunchAtLogin() {
        guard loginItemDesired != settings.launchAtLogin else { return }
        loginItemDesired = settings.launchAtLogin
        do {
            try LaunchAtLogin.setEnabled(settings.launchAtLogin)
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
    }

    private func configureDetectors(force: Bool) {
        let config = (mouse: settings.detectMouse,
                      keyboard: settings.detectKeyboard,
                      screen: settings.detectScreenChanges)
        if force || config != detectorConfig {
            detectorConfig = config
            usageDetector.start(mouse: config.mouse, keyboard: config.keyboard)
        }
        if settings.detectScreenChanges, ScreenChangeDetector.hasPermission {
            screenDetector.start()
        } else {
            screenDetector.stop()
        }
        refreshPermissions()
    }

    private func refreshPermissions() {
        let trusted = UsageDetector.isAccessibilityTrusted
        if trusted != accessibilityTrusted {
            accessibilityTrusted = trusted
            usageDetector.start(mouse: settings.detectMouse, keyboard: settings.detectKeyboard)
        }

        let screenTrusted = ScreenChangeDetector.hasPermission
        if screenTrusted != screenRecordingTrusted { screenRecordingTrusted = screenTrusted }

        if settings.detectScreenChanges {
            if screenTrusted {
                screenDetector.start()
            } else {
                screenDetector.stop()
            }
        }

        refreshNotificationAuthorization()
    }

    // MARK: - Actions

    func startBreakNow() {
        guard breakSession == nil else { return }
        let effective = settings.effective()
        let style: ReminderStyle = effective.reminderStyle == .notification ? .fullScreen : effective.reminderStyle
        beginBreakSession(style: style, effective: effective, triggeredByReminder: false)
    }

    func skipCurrentReminder() {
        if breakSession != nil {
            skipBreak()
            return
        }
        scheduler.reminderDismissed(at: Date(),
                                    config: schedulerConfig(settings.effective()))
    }

    func skipBreak() {
        guard breakSession != nil else { return }
        let now = Date()
        scheduler.reminderDismissed(at: now,
                                    config: schedulerConfig(settings.effective()))
        breakSession = nil
        reminderWindows.hide()
    }

    private func finishBreak() {
        guard let session = breakSession else { return }
        store.insertAlertFinish(at: Date(), duration: TimeInterval(session.totalSeconds))
        scheduler.breakCompleted(at: Date())
        engine.reset()
        fatigue = 0
        playSound()
        breakSession = nil
        reminderWindows.hide()
        refreshTodayStats()
    }

    private func presentScheduledReminder(effective: EffectiveSettings) {
        guard breakSession == nil else { return }
        let now = Date()
        if effective.reminderStyle == .notification {
            if !notificationsAvailable {
                beginBreakSession(style: .miniPopup, effective: effective, triggeredByReminder: true)
                return
            }
            notifications.postBreakReminder()
            store.insertAlertStart(at: now, style: .notification)
            scheduler.reminderShown(at: now, config: schedulerConfig(effective))
            refreshTodayStats()
        } else {
            beginBreakSession(style: effective.reminderStyle,
                              effective: effective,
                              triggeredByReminder: true)
        }
    }

    private func beginBreakSession(style: ReminderStyle,
                                   effective: EffectiveSettings,
                                   triggeredByReminder: Bool) {
        guard breakSession == nil else { return }
        let now = Date()
        let timing = RuleResolver.effective(
            now: now,
            rules: settings.rules,
            fallbackWork: effective.workMinutes,
            fallbackRest: effective.restMinutes
        )
        let session = BreakSessionModel(
            totalSeconds: timing.restMinutes * 60,
            style: style,
            skipMode: effective.skipMode,
            showsSkipButton: settings.showSkipButton,
            title: popupTitle(),
            screenTimeText: popupScreenTimeText(),
            background: settings.popupBackground,
            imagePath: settings.popupImagePath
        )
        breakSession = session
        store.insertAlertStart(at: now, style: style)
        if triggeredByReminder {
            scheduler.reminderShown(at: now, config: schedulerConfig(effective))
        }
        reminderWindows.show(session: session) { [weak self] in
            self?.skipBreak()
        }
        refreshTodayStats()
    }

    private func handle(_ decision: ReminderDecision, effective: EffectiveSettings) {
        switch decision {
        case .none:
            break
        case .remind:
            presentScheduledReminder(effective: effective)
        case .preNotification:
            notifications.postPreReminder()
        case .extraReminder(let hours):
            notifications.postExtraReminder(hours: hours)
        }
    }

    private func schedulerConfig(_ effective: EffectiveSettings) -> BreakSchedulerConfig {
        BreakSchedulerConfig(
            style: effective.reminderStyle,
            preReminderEnabled: settings.preReminderNotification,
            intervalMinutes: effective.notificationIntervalMinutes,
            peakRepeatMinutes: clampValue(settings.peakRepeatMinutes, 1, 60),
            extraReminderEnabled: effective.extraReminderEnabled,
            extraReminderHours: effective.extraReminderHours
        )
    }

    private func popupTitle() -> String {
        let custom = settings.popupText.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? L10n.t("TakeABreak") : custom
    }

    private func popupScreenTimeText() -> String? {
        guard settings.showScreenTimeOnPopup else { return nil }
        return L10n.f("ScreenTimeTodayFormat",
                      DurationFormat.abbreviated(minutes: todayScreenMinutes))
    }

    private func playSound() {
        guard settings.playSoundAtBreakEnd else { return }
        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Ping") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func refreshNotificationAuthorization() {
        notifications.refreshAuthorization { [weak self] status in
            guard let self, self.notificationAuthorization != status else { return }
            self.notificationAuthorization = status
        }
    }

    func requestNotificationAuthorization() {
        notifications.requestAuthorization { [weak self] status in
            self?.notificationAuthorization = status
        }
    }

    private var notificationsAvailable: Bool {
        switch notificationAuthorization {
        case .authorized, .provisional:
            return true
        default:
            return false
        }
    }

    func snooze(_ duration: SnoozeDuration) {
        let now = Date()
        let until: Date
        switch duration {
        case .minutes30:
            until = now.addingTimeInterval(30 * 60)
        case .hour1:
            until = now.addingTimeInterval(60 * 60)
        case .hours2:
            until = now.addingTimeInterval(2 * 60 * 60)
        case .hours6:
            until = now.addingTimeInterval(6 * 60 * 60)
        case .untilTomorrow:
            until = Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 60 * 60))
        }
        snoozeUntil = until
        isSnoozed = true
        scheduler.snooze(until: until)
        UserDefaults.standard.set(until, forKey: Keys.snoozeUntil)
    }

    func resumeReminders() {
        snoozeUntil = nil
        isSnoozed = false
        scheduler.resume()
        UserDefaults.standard.removeObject(forKey: Keys.snoozeUntil)
    }

    func showMainWindow() {
        mainWindowController.show()
    }

    func showSettings() {
        settingsWindowController.show()
    }

    @discardableResult
    func exportCSV(to url: URL) throws -> Int {
        let csv = store.exportCSV(now: Date())
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return max(0, csv.split(separator: "\n").count - 1)
    }

    // MARK: - Helpers

    private static func makeStore() -> EventStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("EyeGuardian", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("events.sqlite3")
        if let store = try? EventStore(path: url.path) {
            return store
        }
        return try! EventStore(path: ":memory:")
    }
}
