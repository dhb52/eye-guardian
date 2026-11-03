import Foundation

struct BreakSchedulerConfig: Equatable {
    var style: ReminderStyle = .notification
    var preReminderEnabled: Bool = true
    var intervalMinutes: Int = 5
    var peakRepeatMinutes: Int = 5
    var extraReminderEnabled: Bool = false
    var extraReminderHours: Int = 6
}

struct BreakSchedulerState: Equatable {
    var snoozeUntil: Date?
    var nextReminderAt: Date?
    var preReminderSent = false
    var extraReminderFiredDay: String?

    func isSnoozed(at now: Date) -> Bool {
        guard let until = snoozeUntil else { return false }
        return until > now
    }
}

final class BreakScheduler {
    private(set) var state: BreakSchedulerState
    private let calendar: Calendar

    init(state: BreakSchedulerState = BreakSchedulerState(), calendar: Calendar = .current) {
        self.state = state
        self.calendar = calendar
    }

    func evaluate(now: Date,
                  fatigue: Double,
                  ratePerSecond: Double,
                  config: BreakSchedulerConfig,
                  todayScreenMinutes: Int,
                  inBreak: Bool) -> ReminderDecision {
        if fatigue < 80 {
            state.preReminderSent = false
        }
        if inBreak { return .none }
        if state.isSnoozed(at: now) { return .none }

        let extraHours = clampValue(config.extraReminderHours, 1, 24)
        if config.extraReminderEnabled,
           todayScreenMinutes >= extraHours * 60,
           state.extraReminderFiredDay != dayKey(now) {
            state.extraReminderFiredDay = dayKey(now)
            return .extraReminder(hours: extraHours)
        }

        if config.style != .notification,
           config.preReminderEnabled,
           !state.preReminderSent,
           ratePerSecond > 0,
           fatigue < 99.5 {
            let remainingSeconds = (99.5 - fatigue) / ratePerSecond
            if remainingSeconds > 0, remainingSeconds <= 60 {
                state.preReminderSent = true
                return .preNotification(remainingSeconds: Int(remainingSeconds.rounded(.up)))
            }
        }

        if fatigue >= 99.5 {
            if let next = state.nextReminderAt, now < next { return .none }
            return .remind
        }
        return .none
    }

    func reminderShown(at now: Date, config: BreakSchedulerConfig) {
        state.preReminderSent = false
        if config.style == .notification {
            state.nextReminderAt = now.addingTimeInterval(
                TimeInterval(clampValue(config.intervalMinutes, 1, 60) * 60)
            )
        } else {
            state.nextReminderAt = nil
        }
    }

    func reminderDismissed(at now: Date, config: BreakSchedulerConfig) {
        let minutes = config.style == .notification
            ? clampValue(config.intervalMinutes, 1, 60)
            : clampValue(config.peakRepeatMinutes, 1, 60)
        state.nextReminderAt = now.addingTimeInterval(TimeInterval(minutes * 60))
        state.preReminderSent = false
    }

    func breakCompleted(at now: Date) {
        state.nextReminderAt = nil
        state.preReminderSent = false
    }

    func snooze(until: Date) {
        state.snoozeUntil = until
    }

    func resume() {
        state.snoozeUntil = nil
    }

    func restore(state: BreakSchedulerState) {
        self.state = state
    }

    private func dayKey(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      components.year ?? 0,
                      components.month ?? 0,
                      components.day ?? 0)
    }
}
