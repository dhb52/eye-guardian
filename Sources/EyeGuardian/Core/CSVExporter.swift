import Foundation

enum CSVExporter {
    static func make(aggregates: [DayAggregate], timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        var lines = ["date,screen_minutes,fatigue_peak_minutes,alerts_shown,alerts_completed,compliance_percent"]
        for aggregate in aggregates {
            lines.append([
                formatter.string(from: aggregate.date),
                String(aggregate.screenMinutes),
                String(aggregate.peakMinutes),
                String(aggregate.alertsShown),
                String(aggregate.alertsCompleted),
                String(aggregate.compliancePercent),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
