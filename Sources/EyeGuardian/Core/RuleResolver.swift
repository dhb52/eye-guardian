import Foundation

enum RuleResolver {
    static func effective(now: Date,
                          rules: [BreakRule],
                          fallbackWork: Int,
                          fallbackRest: Int,
                          fallbackRepeat: Int,
                          calendar: Calendar = .current) -> ResolvedTiming {
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if let rule = rules.first(where: { $0.isEnabled && $0.contains(minuteOfDay: minute) }) {
            return ResolvedTiming(
                workMinutes: clampValue(rule.workMinutes, 5, 180),
                restMinutes: clampValue(rule.restMinutes, 1, 60),
                repeatMinutes: clampValue(rule.repeatMinutes, 1, 60)
            )
        }
        return ResolvedTiming(
            workMinutes: clampValue(fallbackWork, 5, 180),
            restMinutes: clampValue(fallbackRest, 1, 60),
            repeatMinutes: clampValue(fallbackRepeat, 1, 60)
        )
    }
}
