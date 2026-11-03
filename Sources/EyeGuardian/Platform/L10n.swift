import Foundation

extension Notification.Name {
    static let eyeGuardianLanguageDidChange = Notification.Name("EyeGuardianLanguageDidChange")
}

enum L10n {
    private static var overrideBundle: Bundle?
    private(set) static var appliedLanguage: AppLanguage = .system

    @discardableResult
    static func apply(_ language: AppLanguage) -> Bool {
        guard language != appliedLanguage else { return false }
        appliedLanguage = language
        overrideBundle = language.bundleName.flatMap { name in
            Bundle.main.path(forResource: name, ofType: "lproj").flatMap(Bundle.init(path:))
        }
        return true
    }

    static func t(_ key: String) -> String {
        if let bundle = overrideBundle {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        return NSLocalizedString(key, comment: "")
    }

    static func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
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
