import Foundation

struct EffectiveSettings: Equatable {
    let workMinutes: Int
    let restMinutes: Int
    let reminderStyle: ReminderStyle
    let notificationIntervalMinutes: Int
    let skipMode: SkipMode
    let extraReminderEnabled: Bool
    let extraReminderHours: Int
}

struct AppSettings: Codable, Equatable {
    var fatigueThresholdMinutes: Int = 40
    var restMinutes: Int = 5
    var reminderStyle: ReminderStyle = .notification
    var notificationIntervalMinutes: Int = 5
    var preReminderNotification: Bool = true
    var playSoundAtBreakEnd: Bool = true
    var skipMode: SkipMode = .button
    var showSkipButton: Bool = true
    var showDockIcon: Bool = true
    var showStatusBarIcon: Bool = true
    var statusShowFatiguePercent: Bool = true
    var statusShowScreenTimeHours: Bool = false
    var statusShowScreenTimeMinutes: Bool = false
    var statusShowReminderCount: Bool = false
    var ringStyle: RingStyle = .solid
    var ringPalette: RingPalette = .spectrum
    var ringThickness: RingThickness = .regular
    var statusIconSize: Int = 18
    var language: AppLanguage = .system
    var launchAtLogin: Bool = false
    var usageMode: UsageMode = .smart
    var detectMouse: Bool = true
    var detectKeyboard: Bool = true
    var detectScreenChanges: Bool = false
    var movieMode: Bool = false
    var extraReminderEnabled: Bool = false
    var extraReminderHours: Int = 6
    var popupBackground: PopupBackground = .system
    var popupImagePath: String? = nil
    var popupText: String = ""
    var showScreenTimeOnPopup: Bool = true
    var rules: [BreakRule] = BreakRule.defaults

    var detectionActive: Bool { usageMode == .smart }
    var effectiveDetectMouse: Bool { detectionActive && detectMouse }
    var effectiveDetectKeyboard: Bool { detectionActive && detectKeyboard }
    var effectiveDetectScreenChanges: Bool { detectionActive && detectScreenChanges }
    var effectiveStatusIconSize: Int { clampValue(statusIconSize, 14, 22) }

    var statusPlacement: StatusPlacement {
        get {
            if showDockIcon && showStatusBarIcon { return .both }
            if showDockIcon { return .dock }
            return .menuBar
        }
        set {
            switch newValue {
            case .menuBar:
                showDockIcon = false
                showStatusBarIcon = true
            case .dock:
                showDockIcon = true
                showStatusBarIcon = false
            case .both:
                showDockIcon = true
                showStatusBarIcon = true
            }
        }
    }

    var statusScreenTimeStyle: StatusScreenTimeStyle {
        get {
            if statusShowScreenTimeMinutes { return .minutes }
            if statusShowScreenTimeHours { return .hours }
            return .off
        }
        set {
            statusShowScreenTimeHours = newValue == .hours
            statusShowScreenTimeMinutes = newValue == .minutes
        }
    }

    static let `default` = AppSettings()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case fatigueThresholdMinutes, restMinutes, reminderStyle, notificationIntervalMinutes
        case preReminderNotification, playSoundAtBreakEnd, skipMode
        case showSkipButton, showDockIcon, showStatusBarIcon, statusShowFatiguePercent
        case statusShowScreenTimeHours, statusShowScreenTimeMinutes, statusShowReminderCount
        case ringStyle, ringPalette, ringThickness, statusIconSize, language
        case launchAtLogin, usageMode, detectMouse, detectKeyboard, detectScreenChanges
        case movieMode, extraReminderEnabled, extraReminderHours, popupBackground
        case popupImagePath, popupText, showScreenTimeOnPopup, rules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        fatigueThresholdMinutes = (try? c.decodeIfPresent(Int.self, forKey: .fatigueThresholdMinutes)) ?? d.fatigueThresholdMinutes
        restMinutes = (try? c.decodeIfPresent(Int.self, forKey: .restMinutes)) ?? d.restMinutes
        reminderStyle = (try? c.decodeIfPresent(ReminderStyle.self, forKey: .reminderStyle)) ?? d.reminderStyle
        notificationIntervalMinutes = (try? c.decodeIfPresent(Int.self, forKey: .notificationIntervalMinutes)) ?? d.notificationIntervalMinutes
        preReminderNotification = (try? c.decodeIfPresent(Bool.self, forKey: .preReminderNotification)) ?? d.preReminderNotification
        playSoundAtBreakEnd = (try? c.decodeIfPresent(Bool.self, forKey: .playSoundAtBreakEnd)) ?? d.playSoundAtBreakEnd
        skipMode = (try? c.decodeIfPresent(SkipMode.self, forKey: .skipMode)) ?? d.skipMode
        showSkipButton = (try? c.decodeIfPresent(Bool.self, forKey: .showSkipButton)) ?? d.showSkipButton
        showDockIcon = (try? c.decodeIfPresent(Bool.self, forKey: .showDockIcon)) ?? d.showDockIcon
        showStatusBarIcon = (try? c.decodeIfPresent(Bool.self, forKey: .showStatusBarIcon)) ?? d.showStatusBarIcon
        statusShowFatiguePercent = (try? c.decodeIfPresent(Bool.self, forKey: .statusShowFatiguePercent)) ?? d.statusShowFatiguePercent
        statusShowScreenTimeHours = (try? c.decodeIfPresent(Bool.self, forKey: .statusShowScreenTimeHours)) ?? d.statusShowScreenTimeHours
        statusShowScreenTimeMinutes = (try? c.decodeIfPresent(Bool.self, forKey: .statusShowScreenTimeMinutes)) ?? d.statusShowScreenTimeMinutes
        statusShowReminderCount = (try? c.decodeIfPresent(Bool.self, forKey: .statusShowReminderCount)) ?? d.statusShowReminderCount
        ringStyle = (try? c.decodeIfPresent(RingStyle.self, forKey: .ringStyle)) ?? d.ringStyle
        ringPalette = (try? c.decodeIfPresent(RingPalette.self, forKey: .ringPalette)) ?? d.ringPalette
        ringThickness = (try? c.decodeIfPresent(RingThickness.self, forKey: .ringThickness)) ?? d.ringThickness
        statusIconSize = AppSettings.decodeStatusIconSize(from: c) ?? d.statusIconSize
        language = (try? c.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? d.language
        launchAtLogin = (try? c.decodeIfPresent(Bool.self, forKey: .launchAtLogin)) ?? d.launchAtLogin
        usageMode = (try? c.decodeIfPresent(UsageMode.self, forKey: .usageMode)) ?? d.usageMode
        detectMouse = (try? c.decodeIfPresent(Bool.self, forKey: .detectMouse)) ?? d.detectMouse
        detectKeyboard = (try? c.decodeIfPresent(Bool.self, forKey: .detectKeyboard)) ?? d.detectKeyboard
        detectScreenChanges = (try? c.decodeIfPresent(Bool.self, forKey: .detectScreenChanges)) ?? d.detectScreenChanges
        movieMode = (try? c.decodeIfPresent(Bool.self, forKey: .movieMode)) ?? d.movieMode
        extraReminderEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .extraReminderEnabled)) ?? d.extraReminderEnabled
        extraReminderHours = (try? c.decodeIfPresent(Int.self, forKey: .extraReminderHours)) ?? d.extraReminderHours
        popupBackground = (try? c.decodeIfPresent(PopupBackground.self, forKey: .popupBackground)) ?? d.popupBackground
        popupImagePath = (try? c.decodeIfPresent(String.self, forKey: .popupImagePath)) ?? d.popupImagePath
        popupText = (try? c.decodeIfPresent(String.self, forKey: .popupText)) ?? d.popupText
        showScreenTimeOnPopup = (try? c.decodeIfPresent(Bool.self, forKey: .showScreenTimeOnPopup)) ?? d.showScreenTimeOnPopup
        rules = (try? c.decodeIfPresent([BreakRule].self, forKey: .rules)) ?? d.rules
    }

    private static func decodeStatusIconSize(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> Int? {
        if let points = try? container.decodeIfPresent(Int.self, forKey: .statusIconSize) {
            return clampValue(points, 14, 22)
        }
        guard let legacy = try? container.decodeIfPresent(String.self, forKey: .statusIconSize) else {
            return nil
        }
        switch legacy {
        case "small": return 14
        case "large": return 22
        default: return 18
        }
    }

    func effective() -> EffectiveSettings {
        EffectiveSettings(
            workMinutes: clampValue(fatigueThresholdMinutes, 5, 180),
            restMinutes: clampValue(restMinutes, 1, 60),
            reminderStyle: reminderStyle,
            notificationIntervalMinutes: clampValue(notificationIntervalMinutes, 1, 60),
            skipMode: skipMode,
            extraReminderEnabled: extraReminderEnabled,
            extraReminderHours: clampValue(extraReminderHours, 1, 24)
        )
    }
}
