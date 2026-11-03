import Foundation
import SQLite3

enum EventStoreError: Error, CustomStringConvertible {
    case openFailed(String)
    case sql(String)
    case unsupportedSchema(Int)

    var description: String {
        switch self {
        case .openFailed(let message): return "open failed: \(message)"
        case .sql(let message): return "sql failed: \(message)"
        case .unsupportedSchema(let version): return "unsupported schema version \(version)"
        }
    }
}

enum BucketGenerator {
    static func align(_ date: Date, granularity: ChartGranularity, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        switch granularity {
        case .daily:
            return startOfDay
        case .weekly:
            let weekday = calendar.component(.weekday, from: startOfDay)
            let daysSinceMonday = (weekday + 5) % 7
            return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: startOfDay)
            return calendar.date(from: components) ?? startOfDay
        }
    }

    static func buckets(from: Date, to: Date, granularity: ChartGranularity, calendar: Calendar) -> [Date] {
        let component: Calendar.Component
        switch granularity {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        }

        var current = align(from, granularity: granularity, calendar: calendar)
        let end = align(to, granularity: granularity, calendar: calendar)
        var result: [Date] = []
        while current <= end && result.count < 5000 {
            result.append(current)
            guard let next = calendar.date(byAdding: component, value: 1, to: current) else { break }
            current = next
        }
        return result
    }
}

private func bucketFunction(_ context: OpaquePointer?,
                            _ argc: Int32,
                            _ argv: UnsafeMutablePointer<OpaquePointer?>?) {
    guard let context, let argv, argc >= 2 else {
        sqlite3_result_null(context)
        return
    }
    let timestamp = sqlite3_value_int64(argv[0])
    let code = sqlite3_value_int64(argv[1])
    guard let raw = sqlite3_user_data(context) else {
        sqlite3_result_null(context)
        return
    }
    let store = Unmanaged<EventStore>.fromOpaque(raw).takeUnretainedValue()
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let start = store.bucketStart(for: date, code: Int(code))
    sqlite3_result_int64(context, Int64(start.timeIntervalSince1970.rounded(.down)))
}

/// Every entry point takes `lock` before touching the database, so instances can
/// be handed to background queues.
final class EventStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    private let calendar: Calendar

    init(path: String, calendar: Calendar = .current) throws {
        self.calendar = calendar
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &handle, flags, nil)
        guard result == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw EventStoreError.openFailed(message)
        }
        db = handle
        _ = sqlite3_create_function_v2(
            handle, "bucket", 2, SQLITE_UTF8 | SQLITE_DETERMINISTIC,
            Unmanaged.passUnretained(self).toOpaque(),
            bucketFunction, nil, nil, nil
        )
        try execute("PRAGMA journal_mode=WAL;")
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        sqlite3_close(db)
        db = nil
    }

    // MARK: - Writes

    func insertSample(at date: Date, fatigue: Int, isUsing: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let sql = "INSERT OR REPLACE INTO usage_sample (ts, fatigue, is_using) VALUES (?, ?, ?);"
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, timestamp(date))
        sqlite3_bind_int(statement, 2, Int32(clampValue(fatigue, 0, 100)))
        sqlite3_bind_int(statement, 3, isUsing ? 1 : 0)
        _ = sqlite3_step(statement)
    }

    func insertAlertStart(at date: Date, style: ReminderStyle) {
        lock.lock()
        defer { lock.unlock() }
        let sql = "INSERT OR REPLACE INTO alert_start (ts, style) VALUES (?, ?);"
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, timestamp(date))
        sqlite3_bind_text(statement, 2, style.rawValue, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(statement)
    }

    func insertAlertFinish(at date: Date, duration: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        let sql = "INSERT OR REPLACE INTO alert_finish (ts, duration) VALUES (?, ?);"
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, timestamp(date))
        sqlite3_bind_int(statement, 2, Int32(max(0, duration.rounded())))
        _ = sqlite3_step(statement)
    }

    // MARK: - Reads

    func todayStats(now: Date) -> TodayStats {
        lock.lock()
        defer { lock.unlock() }
        let start = timestamp(calendar.startOfDay(for: now))
        let end = timestamp(now.addingTimeInterval(1))

        let screen = queryInt(
            "SELECT COALESCE(SUM(is_using), 0) FROM usage_sample WHERE ts >= ? AND ts < ?;",
            bindings: [start, end]
        )
        let reminders = queryInt(
            "SELECT COUNT(*) FROM alert_start WHERE ts >= ? AND ts < ?;",
            bindings: [start, end]
        )
        return TodayStats(screenMinutes: screen, reminderCount: reminders)
    }

    func earliestSampleDate() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return earliestSampleDateLocked()
    }

    func dayAggregates(from: Date, to: Date) -> [DayAggregate] {
        lock.lock()
        defer { lock.unlock() }
        let fromTS = timestamp(from)
        let toTS = timestamp(to)

        let usage = queryUsageBuckets(from: fromTS, to: toTS, code: 0)
        let starts = queryCountBuckets(table: "alert_start", from: fromTS, to: toTS, code: 0,
                                       extraWhere: "style != 'notification'")
        let finishes = queryCountBuckets(table: "alert_finish", from: fromTS, to: toTS, code: 0,
                                         extraWhere: nil)

        let keys = Set(usage.keys).union(starts.keys).union(finishes.keys).sorted()
        return keys.map { key in
            let usageValue = usage[key] ?? (screen: 0, peak: 0)
            return DayAggregate(
                date: Date(timeIntervalSince1970: TimeInterval(key)),
                screenMinutes: usageValue.screen,
                peakMinutes: usageValue.peak,
                alertsShown: starts[key] ?? 0,
                alertsCompleted: finishes[key] ?? 0
            )
        }
    }

    func analysis(range: ChartRange, granularity: ChartGranularity, now: Date) -> AnalysisData {
        lock.lock()
        defer { lock.unlock() }

        let earliest = earliestSampleDateLocked()
        let from = rangeStart(range: range, now: now, earliest: earliest)
        let code = granularityCode(granularity)
        let fromTS = timestamp(from)
        let toTS = timestamp(now)

        let buckets = BucketGenerator.buckets(from: from, to: now, granularity: granularity, calendar: calendar)
        let usage = queryUsageBuckets(from: fromTS, to: toTS, code: code)
        let starts = queryCountBuckets(table: "alert_start", from: fromTS, to: toTS, code: code,
                                       extraWhere: "style != 'notification'")
        let finishes = queryCountBuckets(table: "alert_finish", from: fromTS, to: toTS, code: code,
                                         extraWhere: nil)

        let formatter = labelFormatter(granularity)

        let screen = buckets.map { bucket -> ChartPoint in
            let key = bucketKey(bucket)
            let minutes = usage[key]?.screen ?? 0
            return ChartPoint(bucketStart: bucket, label: formatter.string(from: bucket),
                              value: Double(minutes) / 60.0)
        }
        let peak = buckets.map { bucket -> ChartPoint in
            let key = bucketKey(bucket)
            let minutes = usage[key]?.peak ?? 0
            return ChartPoint(bucketStart: bucket, label: formatter.string(from: bucket),
                              value: Double(minutes))
        }
        let compliance = buckets.map { bucket -> ChartPoint in
            let key = bucketKey(bucket)
            let shown = starts[key] ?? 0
            let completed = finishes[key] ?? 0
            let percent = shown > 0 ? Double(completed) / Double(shown) * 100 : 0
            return ChartPoint(bucketStart: bucket, label: formatter.string(from: bucket),
                              value: percent)
        }

        return AnalysisData(screenTimeHours: screen, peakMinutes: peak, compliancePercent: compliance)
    }

    func exportCSV(now: Date) -> String {
        let aggregates = dayAggregates(from: Date(timeIntervalSince1970: 0), to: now)
        return CSVExporter.make(aggregates: aggregates, timeZone: calendar.timeZone)
    }

    // MARK: - Bucket function support

    fileprivate func bucketStart(for date: Date, code: Int) -> Date {
        let granularity: ChartGranularity
        switch code {
        case 1: granularity = .weekly
        case 2: granularity = .monthly
        default: granularity = .daily
        }
        return BucketGenerator.align(date, granularity: granularity, calendar: calendar)
    }

    // MARK: - Private

    private func migrate() throws {
        var version = 0
        if let statement = prepare("PRAGMA user_version;") {
            if sqlite3_step(statement) == SQLITE_ROW {
                version = Int(sqlite3_column_int64(statement, 0))
            }
            sqlite3_finalize(statement)
        }
        if version > 1 {
            throw EventStoreError.unsupportedSchema(version)
        }
        guard version < 1 else { return }

        try execute("""
            CREATE TABLE IF NOT EXISTS usage_sample (
                ts INTEGER PRIMARY KEY,
                fatigue INTEGER NOT NULL,
                is_using INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS alert_start (
                ts INTEGER PRIMARY KEY,
                style TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS alert_finish (
                ts INTEGER PRIMARY KEY,
                duration INTEGER NOT NULL
            );
            PRAGMA user_version=1;
            """)
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorPointer)
        guard result == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errorPointer)
            throw EventStoreError.sql(message)
        }
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        return statement
    }

    private func queryInt(_ sql: String, bindings: [Int64]) -> Int {
        guard let statement = prepare(sql) else { return 0 }
        defer { sqlite3_finalize(statement) }
        for (index, value) in bindings.enumerated() {
            sqlite3_bind_int64(statement, Int32(index + 1), value)
        }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func queryUsageBuckets(from: Int64, to: Int64, code: Int) -> [Int: (screen: Int, peak: Int)] {
        let sql = """
            SELECT bucket(ts, ?) AS b,
                   COALESCE(SUM(is_using), 0),
                   COALESCE(SUM(CASE WHEN fatigue >= 100 THEN 1 ELSE 0 END), 0)
            FROM usage_sample
            WHERE ts >= ? AND ts < ?
            GROUP BY b ORDER BY b;
            """
        guard let statement = prepare(sql) else { return [:] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(code))
        sqlite3_bind_int64(statement, 2, from)
        sqlite3_bind_int64(statement, 3, to)

        var result: [Int: (screen: Int, peak: Int)] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let key = Int(sqlite3_column_int64(statement, 0))
            result[key] = (Int(sqlite3_column_int64(statement, 1)),
                           Int(sqlite3_column_int64(statement, 2)))
        }
        return result
    }

    private func queryCountBuckets(table: String,
                                   from: Int64,
                                   to: Int64,
                                   code: Int,
                                   extraWhere: String?) -> [Int: Int] {
        let filter = extraWhere.map { " AND \($0)" } ?? ""
        let sql = """
            SELECT bucket(ts, ?) AS b, COUNT(*)
            FROM \(table)
            WHERE ts >= ? AND ts < ?\(filter)
            GROUP BY b ORDER BY b;
            """
        guard let statement = prepare(sql) else { return [:] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(code))
        sqlite3_bind_int64(statement, 2, from)
        sqlite3_bind_int64(statement, 3, to)

        var result: [Int: Int] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            result[Int(sqlite3_column_int64(statement, 0))] = Int(sqlite3_column_int64(statement, 1))
        }
        return result
    }

    private func earliestSampleDateLocked() -> Date? {
        guard let statement = prepare("SELECT MIN(ts) FROM usage_sample;") else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              sqlite3_column_type(statement, 0) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 0)))
    }

    private func rangeStart(range: ChartRange, now: Date, earliest: Date?) -> Date {
        switch range {
        case .last7Days:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        case .last28Days:
            return calendar.date(byAdding: .day, value: -27, to: calendar.startOfDay(for: now)) ?? now
        case .last90Days:
            return calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now)) ?? now
        case .last12Months:
            let monthStart = BucketGenerator.align(now, granularity: .monthly, calendar: calendar)
            return calendar.date(byAdding: .month, value: -11, to: monthStart) ?? now
        case .allTime:
            return earliest ?? calendar.startOfDay(for: now)
        }
    }

    private func granularityCode(_ granularity: ChartGranularity) -> Int {
        switch granularity {
        case .daily: return 0
        case .weekly: return 1
        case .monthly: return 2
        }
    }

    private func labelFormatter(_ granularity: ChartGranularity) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale.current
        switch granularity {
        case .daily, .weekly:
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
        case .monthly:
            formatter.setLocalizedDateFormatFromTemplate("MMMyyyy")
        }
        return formatter
    }

    private func bucketKey(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970.rounded(.down))
    }

    private func timestamp(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded(.down))
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
