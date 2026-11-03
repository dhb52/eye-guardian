import Foundation

enum StatusBarTextFormatter {
    static func parts(fatiguePercent: Int, screenMinutes: Int, reminderCount: Int,
                      settings: AppSettings) -> [String] {
        var parts: [String] = []
        if settings.statusShowFatiguePercent {
            parts.append("\(fatiguePercent)%")
        }
        if settings.statusShowScreenTimeHours {
            parts.append(String(format: "%.1fh", Double(screenMinutes) / 60.0))
        }
        if settings.statusShowScreenTimeMinutes {
            parts.append("\(screenMinutes)m")
        }
        if settings.statusShowReminderCount {
            parts.append("\(reminderCount)x")
        }
        return parts
    }
}
