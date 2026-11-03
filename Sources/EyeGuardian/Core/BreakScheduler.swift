import Foundation

struct BreakSchedulerConfig: Equatable {
    var style: ReminderStyle = .notification
    var preReminderEnabled: Bool = true
    var intervalMinutes: Int = 5
    var extraReminderEnabled: Bool = false
    var extraReminderHours: Int = 6
}

struct BreakSchedulerState: Equatable {
    var snoozeUntil: Date?
    var nextReminderAt: Date?
    var preReminderDeadline: Date?
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
                  config: BreakSchedulerConfig,
                  todayScreenMinutes: Int,
                  inBreak: Bool) -> ReminderDecision {
        if inBreak { return .none }
        if state.isSnoozed(at: now) { return .none }

        let extraHours = clampValue(config.extraReminderHours, 1, 24)
        if config.extraReminderEnabled,
           todayScreenMinutes >= extraHours * 60,
           state.extraReminderFiredDay != dayKey(now) {
            state.extraReminderFiredDay = dayKey(now)
            return .extraReminder(hours: extraHours)
        }

        if let deadline = state.preReminderDeadline {
            if now < deadline { return .none }
            state.preReminderDeadline = nil
            return .remind
        }

        guard fatigue >= 99.999 else { return .none }
        if let next = state.nextReminderAt, now < next { return .none }

        if config.style != .notification, config.preReminderEnabled {
            state.preReminderDeadline = now.addingTimeInterval(60)
            return .preNotification(remainingSeconds: 60)
        }
        return .remind
    }

    func reminderShown(at now: Date, config: BreakSchedulerConfig) {
        state.preReminderDeadline = nil
        state.nextReminderAt = now.addingTimeInterval(
            TimeInterval(clampValue(config.intervalMinutes, 1, 60) * 59)
        )
    }

    func breakCompleted(at now: Date) {
        state.nextReminderAt = nil
        state.preReminderDeadline = nil
    }

    func snooze(until: Date) {
        state.snoozeUntil = until
        state.preReminderDeadline = nil
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
