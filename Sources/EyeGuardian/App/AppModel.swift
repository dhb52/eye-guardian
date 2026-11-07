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
    @Published private(set) var todayFatigueSamples: [FatigueSample] = []
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
    let permissionGuide = PermissionGuideController()

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
    private var appearanceObservation: NSKeyValueObservation?
    private var lastDockPercent = -1
    private var lastDockPaused = false
    private var loginItemDesired: Bool?
    private var lastScreenDetectionActive = false
    private var lastKeyboardDetectionActive = false

    private var isSnoozeActive: Bool {
        snoozeUntil.map { $0 > Date() } ?? false
    }

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
        L10n.apply(settings.language)
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
        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateDockIcon(force: true)
                self?.statusBar.refresh()
            }
        }
        accessibilityTrusted = UsageDetector.isAccessibilityTrusted
        screenRecordingTrusted = ScreenChangeDetector.hasPermission
        lastKeyboardDetectionActive = settings.effectiveDetectKeyboard
        lastScreenDetectionActive = settings.effectiveDetectScreenChanges
        screenDetector.onChange = { [weak self] in
            self?.usageDetector.mark(.screen)
        }
        configureDetectors(force: true)
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.systemState.refreshLockState()
                self?.permissionGuide.hide()
                self?.refreshPermissions()
            }
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
        permissionGuide.hide()
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

        if permissionGuide.isVisible {
            refreshPermissions()
        }

        let effective = settings.effective()
        let timing = RuleResolver.effective(
            now: now,
            rules: settings.rules,
            fallbackWork: effective.workMinutes,
            fallbackRest: effective.restMinutes,
            fallbackRepeat: effective.notificationIntervalMinutes
        )

        let locked = systemState.isLocked
        let asleep = systemState.isAsleep
        let smart = settings.usageMode == .smart && !settings.movieMode
        let anyDetector = settings.effectiveDetectMouse
            || settings.effectiveDetectKeyboard
            || settings.effectiveDetectScreenChanges

        let using: Bool
        if settings.movieMode || settings.usageMode == .dumb || !anyDetector {
            using = !locked && !asleep
        } else {
            let activityWindow: TimeInterval = 60
            let mouseActive = settings.effectiveDetectMouse &&
                (usageDetector.lastMouse.map { now.timeIntervalSince($0) <= activityWindow } ?? false)
            let keyboardActive = settings.effectiveDetectKeyboard &&
                (usageDetector.lastKeyboard.map { now.timeIntervalSince($0) <= activityWindow } ?? false)
            let screenChangeActive = settings.effectiveDetectScreenChanges &&
                (usageDetector.lastScreen.map { now.timeIntervalSince($0) <= activityWindow } ?? false)
            using = mouseActive || keyboardActive || screenChangeActive
        }

        let inBreak = breakSession != nil
        let resting = inBreak || RestDetector.isResting(
            now: now,
            lastActivityAt: usageDetector.lastActivityAt,
            locked: locked,
            asleep: asleep,
            inBreak: false,
            smartMode: smart
        )
        let screenActive = !inBreak && using && !locked && !asleep
        let snoozed = snoozeUntil.map { $0 > now } ?? false

        if !inBreak {
            engine.tick(deltaSeconds: dt,
                        screenActive: screenActive,
                        resting: resting,
                        paused: snoozed,
                        workMinutes: timing.workMinutes,
                        restMinutes: timing.restMinutes)
        }

        if abs(engine.fatigue - fatigue) > 0.0001 {
            fatigue = engine.fatigue
        }
        updateDockIcon()
        statusBar.refresh()
        if isScreenActive != screenActive { isScreenActive = screenActive }
        if isResting != resting { isResting = resting }
        if isSnoozed != snoozed {
            isSnoozed = snoozed
            applyScreenDetector()
        }

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
            systemState.refreshLockState()
            refreshTodayStats()
        }

        if let session = breakSession {
            if session.update(now: now) {
                finishBreak()
            }
        } else {
            let config = schedulerConfig(effective, repeatMinutes: timing.repeatMinutes)
            let decision = scheduler.evaluate(
                now: now,
                fatigue: engine.fatigue,
                config: config,
                todayScreenMinutes: todayScreenMinutes,
                inBreak: false
            )
            handle(decision, effective: effective)
        }
    }

    private func refreshTodayStats() {
        let now = Date()
        let stats = store.todayStats(now: now)
        todayScreenMinutes = stats.screenMinutes
        todayReminderCount = stats.reminderCount
        todayScreenSeconds = Double(stats.screenMinutes * 60)
        todayFatigueSamples = store.todayFatigueSamples(now: now)
    }

    // MARK: - Settings

    private func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Keys.settings)
    }

    private func applySettings() {
        if L10n.apply(settings.language) {
            NotificationCenter.default.post(name: .eyeGuardianLanguageDidChange, object: nil)
        }
        if settings.effectiveDetectKeyboard && !lastKeyboardDetectionActive
            && !UsageDetector.isAccessibilityTrusted {
            openPermissionSettings(.accessibility)
        }
        lastKeyboardDetectionActive = settings.effectiveDetectKeyboard

        if settings.effectiveDetectScreenChanges && !lastScreenDetectionActive
            && !ScreenChangeDetector.hasPermission {
            openPermissionSettings(.screenRecording)
        }
        lastScreenDetectionActive = settings.effectiveDetectScreenChanges

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
        guard settings.showDockIcon else { return }
        let percent = engine.percent
        let paused = snoozeUntil.map { $0 > Date() } ?? false
        guard force || percent != lastDockPercent || paused != lastDockPaused else { return }
        lastDockPercent = percent
        lastDockPaused = paused
        NSApp.applicationIconImage = DockIconRenderer.image(
            fatigue: percent,
            style: settings.ringStyle,
            palette: settings.ringPalette,
            thickness: settings.ringThickness,
            dark: NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua,
            paused: paused
        )
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

    private func applyScreenDetector() {
        if settings.effectiveDetectScreenChanges, ScreenChangeDetector.hasPermission, !isSnoozeActive {
            screenDetector.start()
        } else {
            screenDetector.stop()
        }
    }

    private func configureDetectors(force: Bool) {
        let config = (mouse: settings.effectiveDetectMouse,
                      keyboard: settings.effectiveDetectKeyboard,
                      screen: settings.effectiveDetectScreenChanges)
        if force || config != detectorConfig {
            detectorConfig = config
            usageDetector.start(mouse: config.mouse, keyboard: config.keyboard)
        }
        applyScreenDetector()
        refreshPermissions()
    }

    private func refreshPermissions() {
        let trusted = UsageDetector.isAccessibilityTrusted
        if trusted != accessibilityTrusted {
            accessibilityTrusted = trusted
            usageDetector.start(mouse: settings.effectiveDetectMouse,
                                keyboard: settings.effectiveDetectKeyboard)
        }

        let screenTrusted = ScreenChangeDetector.hasPermission
        if screenTrusted != screenRecordingTrusted { screenRecordingTrusted = screenTrusted }

        applyScreenDetector()

        refreshNotificationAuthorization()

        if let kind = permissionGuide.visibleKind, permissionGranted(kind) {
            permissionGuide.hide()
        }
    }

    private func permissionGranted(_ kind: PermissionKind) -> Bool {
        switch kind {
        case .accessibility: return accessibilityTrusted
        case .screenRecording: return screenRecordingTrusted
        case .notifications:
            return notificationAuthorization == .authorized
                || notificationAuthorization == .provisional
        }
    }

    // MARK: - Actions

    func startBreakNow() {
        guard breakSession == nil else { return }
        let effective = settings.effective()
        let timing = RuleResolver.effective(
            now: Date(),
            rules: settings.rules,
            fallbackWork: effective.workMinutes,
            fallbackRest: effective.restMinutes,
            fallbackRepeat: effective.notificationIntervalMinutes
        )
        let style: ReminderStyle = effective.reminderStyle == .notification ? .fullScreen : effective.reminderStyle
        beginBreakSession(style: style, timing: timing,
                          effective: effective, triggeredByReminder: false)
    }

    func skipCurrentReminder() {
        if breakSession != nil {
            skipBreak()
        }
    }

    func skipBreak() {
        guard breakSession != nil else { return }
        breakSession = nil
        reminderWindows.hide()
    }

    private func finishBreak() {
        guard let session = breakSession else { return }
        store.insertAlertFinish(at: Date(), duration: TimeInterval(session.totalSeconds))
        scheduler.breakCompleted(at: Date())
        engine.applyRest(minutes: Double(session.totalSeconds) / 60.0,
                         restMinutes: max(1, session.totalSeconds / 60))
        fatigue = engine.fatigue
        playSound()
        breakSession = nil
        reminderWindows.hide()
        updateDockIcon(force: true)
        statusBar.refresh()
        refreshTodayStats()
    }

    private func presentScheduledReminder(effective: EffectiveSettings) {
        guard breakSession == nil else { return }
        let now = Date()
        let timing = RuleResolver.effective(
            now: now,
            rules: settings.rules,
            fallbackWork: effective.workMinutes,
            fallbackRest: effective.restMinutes,
            fallbackRepeat: effective.notificationIntervalMinutes
        )
        if effective.reminderStyle == .notification {
            if !notificationsAvailable {
                beginBreakSession(style: .miniPopup, timing: timing,
                                  effective: effective, triggeredByReminder: true)
                return
            }
            notifications.postBreakReminder()
            store.insertAlertStart(at: now, style: .notification)
            scheduler.reminderShown(at: now, config: schedulerConfig(effective, repeatMinutes: timing.repeatMinutes))
            refreshTodayStats()
        } else {
            beginBreakSession(style: effective.reminderStyle,
                              timing: timing,
                              effective: effective,
                              triggeredByReminder: true)
        }
    }

    private func beginBreakSession(style: ReminderStyle,
                                   timing: ResolvedTiming,
                                   effective: EffectiveSettings,
                                   triggeredByReminder: Bool) {
        guard breakSession == nil else { return }
        let now = Date()
        let session = BreakSessionModel(
            totalSeconds: clampValue(timing.restMinutes, 1, 60) * 60,
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
            scheduler.reminderShown(at: now, config: schedulerConfig(effective, repeatMinutes: timing.repeatMinutes))
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

    private func schedulerConfig(_ effective: EffectiveSettings, repeatMinutes: Int) -> BreakSchedulerConfig {
        BreakSchedulerConfig(
            style: effective.reminderStyle,
            preReminderEnabled: settings.preReminderNotification,
            intervalMinutes: repeatMinutes,
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
        applyScreenDetector()
        UserDefaults.standard.set(until, forKey: Keys.snoozeUntil)
        updateDockIcon(force: true)
        statusBar.refresh()
    }

    func resumeReminders() {
        snoozeUntil = nil
        isSnoozed = false
        scheduler.resume()
        applyScreenDetector()
        UserDefaults.standard.removeObject(forKey: Keys.snoozeUntil)
        updateDockIcon(force: true)
        statusBar.refresh()
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
