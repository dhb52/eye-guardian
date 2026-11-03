import Foundation

enum L10n {
    static func t(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
    }
}

enum DurationFormat {
    static func abbreviated(minutes: Int) -> String {
        let clamped = max(0, minutes)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = clamped >= 60 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        formatter.calendar = Calendar.current
        return formatter.string(from: TimeInterval(clamped * 60)) ?? "\(clamped)m"
    }
}
