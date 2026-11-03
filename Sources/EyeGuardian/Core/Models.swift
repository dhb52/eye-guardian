import Foundation

enum ReminderStyle: String, Codable, CaseIterable, Identifiable {
    case notification
    case miniPopup
    case fullScreen

    var id: String { rawValue }
    var isPopup: Bool { self != .notification }
}

enum SkipMode: String, Codable, CaseIterable, Identifiable {
    case button
    case challenge
    case none

    var id: String { rawValue }
}

enum UsageMode: String, Codable, CaseIterable, Identifiable {
    case smart
    case dumb

    var id: String { rawValue }
}

enum PopupBackground: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case purple
    case customImage

    var id: String { rawValue }
}

enum ChartRange: String, Codable, CaseIterable, Identifiable {
    case last7Days
    case last28Days
    case last90Days
    case last12Months
    case allTime

    var id: String { rawValue }
}

enum ChartGranularity: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }
}

struct BreakRule: Codable, Identifiable, Equatable {
    var id: Int
    var isEnabled: Bool
    var startMinutes: Int
    var endMinutes: Int
    var workMinutes: Int
    var restMinutes: Int

    func contains(minuteOfDay: Int) -> Bool {
        if startMinutes == endMinutes { return false }
        if startMinutes < endMinutes {
            return minuteOfDay >= startMinutes && minuteOfDay < endMinutes
        }
        return minuteOfDay >= startMinutes || minuteOfDay < endMinutes
    }

    static var defaults: [BreakRule] {
        [
            BreakRule(id: 0, isEnabled: true, startMinutes: 9 * 60, endMinutes: 18 * 60,
                      workMinutes: 40, restMinutes: 5),
            BreakRule(id: 1, isEnabled: false, startMinutes: 9 * 60, endMinutes: 18 * 60,
                      workMinutes: 25, restMinutes: 5),
        ]
    }
}

struct ChartPoint: Identifiable, Equatable {
    var id: Date { bucketStart }
    let bucketStart: Date
    let label: String
    let value: Double
}

struct AnalysisData: Equatable {
    var screenTimeHours: [ChartPoint]
    var peakMinutes: [ChartPoint]
    var compliancePercent: [ChartPoint]

    static let empty = AnalysisData(screenTimeHours: [], peakMinutes: [], compliancePercent: [])
}

struct DayAggregate: Equatable {
    let date: Date
    let screenMinutes: Int
    let peakMinutes: Int
    let alertsShown: Int
    let alertsCompleted: Int

    var compliancePercent: Int {
        guard alertsShown > 0 else { return 0 }
        return Int((Double(alertsCompleted) / Double(alertsShown) * 100).rounded())
    }
}

struct TodayStats: Equatable {
    var screenMinutes: Int
    var reminderCount: Int

    static let zero = TodayStats(screenMinutes: 0, reminderCount: 0)
}

struct ResolvedTiming: Equatable {
    let workMinutes: Int
    let restMinutes: Int
}

enum ReminderDecision: Equatable {
    case none
    case preNotification(remainingSeconds: Int)
    case remind
    case extraReminder(hours: Int)
}

func clampValue<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}

enum RingStyle: String, Codable, CaseIterable, Identifiable {
    case solid
    case dotted

    var id: String { rawValue }
}

enum RingPalette: String, Codable, CaseIterable, Identifiable {
    case monochrome
    case spectrum

    var id: String { rawValue }
}

enum RingThickness: String, Codable, CaseIterable, Identifiable {
    case thin
    case regular
    case thick

    var id: String { rawValue }

    var ringWidth: Double {
        switch self {
        case .thin: return 52
        case .regular: return 72
        case .thick: return 92
        }
    }

    var dotDiameter: Double {
        switch self {
        case .thin: return 64
        case .regular: return 82
        case .thick: return 100
        }
    }

    var dotCount: Int {
        switch self {
        case .thin: return 13
        case .regular: return 11
        case .thick: return 9
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case english
    case chinese

    var id: String { rawValue }

    var bundleName: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .chinese: return "zh-Hans"
        }
    }

    var titleKey: String {
        switch self {
        case .system: return "LanguageSystem"
        case .english: return "LanguageEnglish"
        case .chinese: return "LanguageChinese"
        }
    }
}

enum StatusPlacement: String, CaseIterable, Identifiable {
    case menuBar
    case dock
    case both

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .menuBar: return "StatusPlacementMenuBar"
        case .dock: return "StatusPlacementDock"
        case .both: return "StatusPlacementBoth"
        }
    }
}

enum StatusScreenTimeStyle: String, CaseIterable, Identifiable {
    case off
    case hours
    case minutes

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .off: return "ScreenTimeOff"
        case .hours: return "ScreenTimeStyleHours"
        case .minutes: return "ScreenTimeStyleMinutes"
        }
    }
}
