import CoreGraphics
import Foundation

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.timeZone = utc.timeZone
    return utc.date(from: components)!
}

@main
enum CoreTestsMain {
    static func main() {
        let runner = TestRunner()
        testEngine(runner)
        testRestDetector(runner)
        testRuleResolver(runner)
        testEffectiveSettings(runner)
        testDetectionGating(runner)
        testScheduler(runner)
        testEventStore(runner)
        testTodayFatigueSamples(runner)
        testPermissionGuideLayout(runner)
        testSettingsMigration(runner)
        testStatusPresentation(runner)
        runner.finish()
    }

    private static func testSettingsMigration(_ runner: TestRunner) {
        func decode(_ json: String) -> AppSettings? {
            guard let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(AppSettings.self, from: data)
        }

        runner.check("legacy large icon size maps to 26 points",
                     decode("{\"statusIconSize\":\"large\"}")?.statusIconSize == 26)
        runner.check("legacy small icon size maps to 18 points",
                     decode("{\"statusIconSize\":\"small\"}")?.statusIconSize == 18)
        runner.check("numeric icon size is clamped",
                     decode("{\"statusIconSize\":99}")?.effectiveStatusIconSize == 26)
        runner.check("numeric icon size below range is clamped",
                     decode("{\"statusIconSize\":2}")?.effectiveStatusIconSize == 18)
        runner.check("unknown icon size string falls back to 18",
                     decode("{\"statusIconSize\":\"weird\"}")?.statusIconSize == 18)
        runner.check("missing icon size keeps the default",
                     decode("{}")?.statusIconSize == 24)
        runner.check("default settings hide the dock icon",
                     decode("{}")?.showDockIcon == false)
        runner.check("default settings hide the fatigue percent",
                     decode("{}")?.statusShowFatiguePercent == false)
        runner.check("default settings use the monochrome ring",
                     decode("{}")?.ringPalette == .monochrome)
        runner.check("default settings enable movie mode",
                     decode("{}")?.movieMode == true)
        runner.check("language decodes from storage",
                     decode("{\"language\":\"chinese\"}")?.language == .chinese)
        runner.check("missing language follows the system",
                     decode("{}")?.language == .system)
        runner.check("unknown language follows the system",
                     decode("{\"language\":\"klingon\"}")?.language == .system)
    }

    private static func testStatusPresentation(_ runner: TestRunner) {
        var settings = AppSettings()

        settings.statusPlacement = .dock
        runner.check("dock placement hides the menu bar icon",
                     settings.showDockIcon && !settings.showStatusBarIcon)
        runner.check("dock placement round-trips", settings.statusPlacement == .dock)

        settings.statusPlacement = .menuBar
        runner.check("menu bar placement hides the dock icon",
                     !settings.showDockIcon && settings.showStatusBarIcon)
        runner.check("menu bar placement round-trips", settings.statusPlacement == .menuBar)

        settings.statusPlacement = .both
        runner.check("both placement shows both icons",
                     settings.showDockIcon && settings.showStatusBarIcon)
        runner.check("both placement round-trips", settings.statusPlacement == .both)

        settings.statusScreenTimeStyle = .hours
        runner.check("hours style enables only hours",
                     settings.statusShowScreenTimeHours && !settings.statusShowScreenTimeMinutes)
        settings.statusScreenTimeStyle = .minutes
        runner.check("minutes style enables only minutes",
                     !settings.statusShowScreenTimeHours && settings.statusShowScreenTimeMinutes)
        settings.statusScreenTimeStyle = .off
        runner.check("off style disables both screen time readouts",
                     !settings.statusShowScreenTimeHours && !settings.statusShowScreenTimeMinutes)
        runner.check("off style round-trips", settings.statusScreenTimeStyle == .off)
    }

    private static func testPermissionGuideLayout(_ runner: TestRunner) {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let settings = CGRect(x: 400, y: 300, width: 600, height: 450)
        let anchored = PermissionGuideLayout.frame(settingsWindow: settings, visibleFrame: screen)
        runner.check("guide centers under settings window",
                     abs(anchored.minX - 420) < 0.001 && abs(anchored.minY - 170) < 0.001)
        runner.check("guide uses fixed panel size", anchored.width == 560 && anchored.height == 124)
        runner.check("guide sits six points below settings",
                     abs(anchored.maxY - (settings.minY - 6)) < 0.001)
        runner.check("anchored guide stays on screen", screen.contains(anchored))

        let fallback = PermissionGuideLayout.frame(settingsWindow: nil, visibleFrame: screen)
        runner.check("guide falls back to bottom center",
                     abs(fallback.minX - 440) < 0.001 && abs(fallback.minY - 28) < 0.001)

        let bottomClamped = PermissionGuideLayout.frame(
            settingsWindow: CGRect(x: 400, y: 0, width: 600, height: 450),
            visibleFrame: screen
        )
        runner.check("guide clamps to screen bottom", abs(bottomClamped.minY - 8) < 0.001)
        runner.check("bottom-clamped guide stays on screen", screen.contains(bottomClamped))

        let leftClamped = PermissionGuideLayout.frame(
            settingsWindow: CGRect(x: -500, y: 300, width: 600, height: 450),
            visibleFrame: screen
        )
        runner.check("guide clamps to screen left", abs(leftClamped.minX - 8) < 0.001)

        let secondary = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let secondaryFrame = PermissionGuideLayout.frame(
            settingsWindow: CGRect(x: -1600, y: 300, width: 600, height: 400),
            visibleFrame: secondary
        )
        runner.check("guide positions on secondary display",
                     abs(secondaryFrame.minX - (-1580)) < 0.001 &&
                     abs(secondaryFrame.minY - 170) < 0.001)
        runner.check("secondary guide stays on screen", secondary.contains(secondaryFrame))
    }

    private static func testEngine(_ runner: TestRunner) {
        var engine = FatigueEngine()
        for _ in 0..<40 {
            engine.tick(deltaSeconds: 60, screenActive: true, resting: false,
                        workMinutes: 40)
        }
        runner.check("40 work minutes fill fatigue to 100", engine.fatigue >= 99.999)
        runner.check("engine percent rounds to 100", engine.percent == 100)

        engine.setFatigue(100)
        for _ in 0..<5 {
            engine.tick(deltaSeconds: 60, screenActive: false, resting: true,
                        workMinutes: 40)
        }
        runner.check("5 rest minutes empty fatigue", abs(engine.fatigue) < 0.0001)

        engine.setFatigue(100)
        engine.tick(deltaSeconds: 60, screenActive: false, resting: true, workMinutes: 40)
        runner.check("one rest minute removes twenty percent", abs(engine.fatigue - 80) < 0.0001)

        engine.setFatigue(100)
        engine.applyRest(minutes: 2)
        runner.check("two rest minutes remove forty percent", abs(engine.fatigue - 60) < 0.0001)
        engine.applyRest(minutes: 10)
        runner.check("applied rest never drops below zero", engine.fatigue == 0)

        engine.setFatigue(10)
        engine.tick(deltaSeconds: 3600, screenActive: false, resting: true,
                    workMinutes: 40)
        runner.check("fatigue never drops below zero", engine.fatigue == 0)

        engine.tick(deltaSeconds: 3600, screenActive: true, resting: false,
                    workMinutes: 5)
        runner.check("fatigue never exceeds one hundred", engine.fatigue == 100)

        engine.setFatigue(50)
        engine.tick(deltaSeconds: 120, screenActive: false, resting: false,
                    workMinutes: 40)
        runner.check("idle without resting holds fatigue", abs(engine.fatigue - 50) < 0.0001)
    }

    private static func testRestDetector(_ runner: TestRunner) {
        let now = makeDate(2026, 11, 3, 12, 0)

        runner.check("recent activity is not resting",
                     !RestDetector.isResting(now: now, lastActivityAt: now.addingTimeInterval(-30),
                                             locked: false, asleep: false, inBreak: false, smartMode: true))
        runner.check("sixty seconds of silence is resting",
                     RestDetector.isResting(now: now, lastActivityAt: now.addingTimeInterval(-61),
                                            locked: false, asleep: false, inBreak: false, smartMode: true))
        runner.check("no activity ever is resting",
                     RestDetector.isResting(now: now, lastActivityAt: nil,
                                            locked: false, asleep: false, inBreak: false, smartMode: true))
        runner.check("locked is resting",
                     RestDetector.isResting(now: now, lastActivityAt: now,
                                            locked: true, asleep: false, inBreak: false, smartMode: true))
        runner.check("break is resting",
                     RestDetector.isResting(now: now, lastActivityAt: now,
                                            locked: false, asleep: false, inBreak: true, smartMode: true))
        runner.check("dumb mode ignores idle",
                     !RestDetector.isResting(now: now, lastActivityAt: now.addingTimeInterval(-3600),
                                             locked: false, asleep: false, inBreak: false, smartMode: false))
    }

    private static func testRuleResolver(_ runner: TestRunner) {
        let rules = [
            BreakRule(id: 0, isEnabled: true, startMinutes: 9 * 60, endMinutes: 18 * 60,
                      workMinutes: 50, restMinutes: 6),
            BreakRule(id: 1, isEnabled: false, startMinutes: 9 * 60, endMinutes: 18 * 60,
                      workMinutes: 25, restMinutes: 5),
        ]

        let inside = RuleResolver.effective(now: makeDate(2026, 11, 3, 12, 0), rules: rules,
                                            fallbackWork: 40, fallbackRest: 5, calendar: utc)
        runner.check("rule inside window wins", inside == ResolvedTiming(workMinutes: 50, restMinutes: 6))

        let outside = RuleResolver.effective(now: makeDate(2026, 11, 3, 20, 0), rules: rules,
                                             fallbackWork: 33, fallbackRest: 7, calendar: utc)
        runner.check("outside window uses fallback", outside == ResolvedTiming(workMinutes: 33, restMinutes: 7))

        let overnight = [
            BreakRule(id: 2, isEnabled: true, startMinutes: 22 * 60, endMinutes: 2 * 60,
                      workMinutes: 30, restMinutes: 4)
        ]
        let lateEvening = RuleResolver.effective(now: makeDate(2026, 11, 3, 23, 0), rules: overnight,
                                                 fallbackWork: 40, fallbackRest: 5, calendar: utc)
        let earlyMorning = RuleResolver.effective(now: makeDate(2026, 11, 3, 1, 0), rules: overnight,
                                                  fallbackWork: 40, fallbackRest: 5, calendar: utc)
        let midday = RuleResolver.effective(now: makeDate(2026, 11, 3, 12, 0), rules: overnight,
                                            fallbackWork: 40, fallbackRest: 5, calendar: utc)
        runner.check("overnight rule matches evening", lateEvening.workMinutes == 30)
        runner.check("overnight rule matches early morning", earlyMorning.workMinutes == 30)
        runner.check("overnight rule misses midday", midday.workMinutes == 40)

        let clamped = RuleResolver.effective(now: makeDate(2026, 11, 3, 12, 0),
                                             rules: [BreakRule(id: 3, isEnabled: true, startMinutes: 0, endMinutes: 1439,
                                                               workMinutes: 999, restMinutes: 0)],
                                             fallbackWork: 40, fallbackRest: 5, calendar: utc)
        runner.check("rule values are clamped", clamped == ResolvedTiming(workMinutes: 180, restMinutes: 1))
    }

    private static func testEffectiveSettings(_ runner: TestRunner) {
        var settings = AppSettings()
        settings.fatigueThresholdMinutes = 90
        settings.restMinutes = 10
        settings.reminderStyle = .fullScreen
        settings.notificationIntervalMinutes = 12
        settings.skipMode = .challenge
        settings.extraReminderEnabled = true
        settings.extraReminderHours = 8

        let effective = settings.effective()
        runner.check("effective keeps custom durations",
                     effective.workMinutes == 90 && effective.restMinutes == 10)
        runner.check("effective keeps popup style", effective.reminderStyle == .fullScreen)
        runner.check("effective keeps interval", effective.notificationIntervalMinutes == 12)
        runner.check("effective keeps skip mode", effective.skipMode == .challenge)
        runner.check("effective keeps extra reminder",
                     effective.extraReminderEnabled && effective.extraReminderHours == 8)

        var clamped = AppSettings()
        clamped.fatigueThresholdMinutes = 1
        clamped.restMinutes = 999
        let clampedEffective = clamped.effective()
        runner.check("effective settings clamp durations",
                     clampedEffective.workMinutes == 5 && clampedEffective.restMinutes == 60)
    }

    private static func testDetectionGating(_ runner: TestRunner) {
        var settings = AppSettings()
        settings.detectMouse = true
        settings.detectKeyboard = false
        settings.detectScreenChanges = true

        runner.check("smart mode activates enabled detectors",
                     settings.detectionActive
                     && settings.effectiveDetectMouse
                     && !settings.effectiveDetectKeyboard
                     && settings.effectiveDetectScreenChanges)

        settings.usageMode = .dumb
        runner.check("dumb mode deactivates all detectors",
                     !settings.detectionActive
                     && !settings.effectiveDetectMouse
                     && !settings.effectiveDetectKeyboard
                     && !settings.effectiveDetectScreenChanges)

        settings.usageMode = .smart
        runner.check("smart mode restores stored detector values",
                     settings.effectiveDetectMouse
                     && !settings.effectiveDetectKeyboard
                     && settings.effectiveDetectScreenChanges
                     && settings.detectScreenChanges)
    }

    private static func testScheduler(_ runner: TestRunner) {
        let start = makeDate(2026, 11, 3, 10, 0)

        var popup = BreakSchedulerConfig()
        popup.style = .fullScreen
        popup.preReminderEnabled = true
        popup.intervalMinutes = 5

        let scheduler = BreakScheduler(calendar: utc)
        let far = scheduler.evaluate(now: start, fatigue: 90,
                                     config: popup, todayScreenMinutes: 0, inBreak: false)
        runner.check("pre-reminder waits for peak fatigue", far == .none)

        let due = scheduler.evaluate(now: start, fatigue: 100,
                                     config: popup, todayScreenMinutes: 0, inBreak: false)
        runner.check("peak starts a sixty second countdown", due == .preNotification(remainingSeconds: 60))

        let counting = scheduler.evaluate(now: start.addingTimeInterval(59), fatigue: 100,
                                          config: popup, todayScreenMinutes: 0, inBreak: false)
        runner.check("countdown suppresses the popup", counting == .none)

        let afterCountdown = scheduler.evaluate(now: start.addingTimeInterval(60), fatigue: 100,
                                                config: popup, todayScreenMinutes: 0, inBreak: false)
        runner.check("popup appears when countdown ends", afterCountdown == .remind)

        scheduler.reminderShown(at: start.addingTimeInterval(60), config: popup)
        runner.check("re-arm is interval times 59 seconds",
                     scheduler.state.nextReminderAt == start.addingTimeInterval(60 + 5 * 59))

        let earlyRepeat = scheduler.evaluate(now: start.addingTimeInterval(200), fatigue: 100,
                                             config: popup, todayScreenMinutes: 0, inBreak: false)
        runner.check("re-arm suppresses early repeat", earlyRepeat == .none)

        let rearmDue = scheduler.evaluate(now: start.addingTimeInterval(60 + 5 * 59), fatigue: 100,
                                          config: popup, todayScreenMinutes: 0, inBreak: false)
        runner.check("re-arm starts the countdown again", rearmDue == .preNotification(remainingSeconds: 60))

        let secondPopup = scheduler.evaluate(now: start.addingTimeInterval(120 + 5 * 59), fatigue: 100,
                                             config: popup, todayScreenMinutes: 0, inBreak: false)
        runner.check("second popup follows the countdown", secondPopup == .remind)

        scheduler.breakCompleted(at: start.addingTimeInterval(120 + 5 * 59))
        let afterBreak = scheduler.evaluate(now: start.addingTimeInterval(60 + 5 * 59 + 400),
                                            fatigue: 0, config: popup,
                                            todayScreenMinutes: 0, inBreak: false)
        runner.check("completed break clears cooldown", afterBreak == .none)

        let inBreak = scheduler.evaluate(now: start, fatigue: 100,
                                         config: popup, todayScreenMinutes: 0, inBreak: true)
        runner.check("no reminder while resting", inBreak == .none)

        var notificationConfig = BreakSchedulerConfig()
        notificationConfig.style = .notification
        notificationConfig.preReminderEnabled = true
        notificationConfig.intervalMinutes = 5

        let notifications = BreakScheduler(calendar: utc)
        let notificationDue = notifications.evaluate(now: start, fatigue: 100,
                                                      config: notificationConfig,
                                                      todayScreenMinutes: 0, inBreak: false)
        runner.check("notification style skips the countdown", notificationDue == .remind)

        notifications.reminderShown(at: start, config: notificationConfig)
        let early = notifications.evaluate(now: start.addingTimeInterval(60), fatigue: 100,
                                           config: notificationConfig,
                                           todayScreenMinutes: 0, inBreak: false)
        runner.check("notification interval suppresses early repeat", early == .none)
        let later = notifications.evaluate(now: start.addingTimeInterval(5 * 59), fatigue: 100,
                                           config: notificationConfig,
                                           todayScreenMinutes: 0, inBreak: false)
        runner.check("notification repeats after interval", later == .remind)

        let snoozed = BreakScheduler(calendar: utc)
        snoozed.snooze(until: start.addingTimeInterval(3600))
        let whileSnoozed = snoozed.evaluate(now: start, fatigue: 100,
                                            config: popup, todayScreenMinutes: 0, inBreak: false)
        runner.check("snooze suppresses reminders", whileSnoozed == .none)
        snoozed.resume()
        let afterResume = snoozed.evaluate(now: start, fatigue: 100,
                                           config: popup, todayScreenMinutes: 0, inBreak: false)
        runner.check("resume restarts the countdown", afterResume == .preNotification(remainingSeconds: 60))

        var extraConfig = popup
        extraConfig.extraReminderEnabled = true
        extraConfig.extraReminderHours = 6
        let extra = BreakScheduler(calendar: utc)
        let firstExtra = extra.evaluate(now: start, fatigue: 10,
                                        config: extraConfig, todayScreenMinutes: 360, inBreak: false)
        runner.check("extra reminder fires at threshold", firstExtra == .extraReminder(hours: 6))
        let secondExtra = extra.evaluate(now: start.addingTimeInterval(60), fatigue: 10,
                                         config: extraConfig, todayScreenMinutes: 400, inBreak: false)
        runner.check("extra reminder only once per day", secondExtra == .none)
    }

    private static func testEventStore(_ runner: TestRunner) {
        let store = try! EventStore(path: ":memory:", calendar: utc)
        defer { store.close() }

        let day1 = makeDate(2026, 11, 1, 10, 0)
        let day2 = makeDate(2026, 11, 2, 10, 0)
        let day3 = makeDate(2026, 11, 3, 10, 0)
        let now = makeDate(2026, 11, 3, 12, 0)

        store.insertSample(at: day1, fatigue: 100, isUsing: true)
        store.insertSample(at: day1.addingTimeInterval(60), fatigue: 100, isUsing: true)
        store.insertSample(at: day1.addingTimeInterval(120), fatigue: 50, isUsing: false)
        store.insertSample(at: day2, fatigue: 20, isUsing: true)
        store.insertSample(at: day3, fatigue: 0, isUsing: false)

        store.insertAlertStart(at: day1, style: .fullScreen)
        store.insertAlertFinish(at: day1.addingTimeInterval(300), duration: 300)
        store.insertAlertStart(at: day2, style: .notification)
        store.insertAlertStart(at: day3, style: .miniPopup)

        runner.check("earliest sample is day one",
                     store.earliestSampleDate() == day1)

        let today = store.todayStats(now: now)
        runner.check("today screen minutes are zero", today.screenMinutes == 0)
        runner.check("today reminder count is one", today.reminderCount == 1)

        let aggregates = store.dayAggregates(from: makeDate(2026, 10, 31, 0, 0),
                                             to: makeDate(2026, 11, 4, 0, 0))
        runner.check("three daily aggregates", aggregates.count == 3)
        if aggregates.count == 3 {
            runner.check("day one screen minutes", aggregates[0].screenMinutes == 2)
            runner.check("day one peak minutes", aggregates[0].peakMinutes == 2)
            runner.check("day one compliance", aggregates[0].compliancePercent == 100)
            runner.check("day two excludes notification reminders", aggregates[1].alertsShown == 0)
            runner.check("day three counts popup reminder", aggregates[2].alertsShown == 1)
            runner.check("day three has no completion", aggregates[2].alertsCompleted == 0)
        }

        let csv = store.exportCSV(now: now)
        let expectedCSV = """
            date,screen_minutes,fatigue_peak_minutes,alerts_shown,alerts_completed,compliance_percent
            2026-11-01,2,2,1,1,100
            2026-11-02,1,0,0,0,0
            2026-11-03,0,0,1,0,0

            """
        runner.check("csv matches expected bytes", csv == expectedCSV)

        let analysis = store.analysis(range: .last7Days, granularity: .daily, now: now)
        runner.check("seven daily buckets", analysis.screenTimeHours.count == 7)
        if analysis.screenTimeHours.count == 7 {
            runner.check("chart last bucket is today",
                         analysis.screenTimeHours[6].bucketStart == makeDate(2026, 11, 3, 0, 0))
            runner.check("day one screen hours", abs(analysis.screenTimeHours[4].value - 2.0 / 60.0) < 0.0001)
            runner.check("day one peak minutes", analysis.peakMinutes[4].value == 2)
            runner.check("day one compliance percent", analysis.compliancePercent[4].value == 100)
            runner.check("day two peak minutes are zero", analysis.peakMinutes[5].value == 0)
        }

        let empty = try! EventStore(path: ":memory:", calendar: utc)
        defer { empty.close() }
        let emptyAnalysis = empty.analysis(range: .last7Days, granularity: .daily, now: now)
        runner.check("empty analysis fills zero buckets",
                     emptyAnalysis.screenTimeHours.count == 7 &&
                     emptyAnalysis.peakMinutes.allSatisfy { $0.value == 0 })
        runner.check("empty csv is header only",
                     empty.exportCSV(now: now) ==
                     "date,screen_minutes,fatigue_peak_minutes,alerts_shown,alerts_completed,compliance_percent\n")

        let weekly = store.analysis(range: .last28Days, granularity: .weekly, now: now)
        runner.check("weekly buckets start on Monday",
                     weekly.screenTimeHours.first?.bucketStart == makeDate(2026, 10, 5, 0, 0))
        runner.check("weekly bucket count", weekly.screenTimeHours.count == 5)
        if weekly.screenTimeHours.count == 5 {
            runner.check("weekly aggregates Sunday samples",
                         abs(weekly.screenTimeHours[3].value - 2.0 / 60.0) < 0.0001)
            runner.check("weekly aggregates Monday samples",
                         abs(weekly.screenTimeHours[4].value - 1.0 / 60.0) < 0.0001)
        }

        let monthly = store.analysis(range: .last12Months, granularity: .monthly, now: now)
        runner.check("monthly bucket count", monthly.screenTimeHours.count == 12)
        if let november = monthly.screenTimeHours.last {
            runner.check("monthly bucket label is November", november.bucketStart == makeDate(2026, 11, 1, 0, 0))
            runner.check("monthly aggregates all samples", abs(november.value - 3.0 / 60.0) < 0.0001)
            runner.check("monthly peak aggregates", monthly.peakMinutes.last?.value == 2)
        }
    }

    private static func testTodayFatigueSamples(_ runner: TestRunner) {
        let store = try! EventStore(path: ":memory:", calendar: utc)
        defer { store.close() }

        let midnight = makeDate(2026, 11, 3, 0, 0)
        let now = makeDate(2026, 11, 3, 12, 0)
        let midday = makeDate(2026, 11, 3, 9, 30)

        store.insertSample(at: makeDate(2026, 11, 2, 23, 59), fatigue: 88, isUsing: true)
        store.insertSample(at: midnight, fatigue: 10, isUsing: true)
        store.insertSample(at: midday, fatigue: 42, isUsing: false)
        store.insertSample(at: now, fatigue: 70, isUsing: true)
        store.insertSample(at: makeDate(2026, 11, 3, 12, 1), fatigue: 71, isUsing: true)

        let samples = store.todayFatigueSamples(now: now)
        runner.check("today fatigue samples span the current day only",
                     samples.map(\.value) == [10, 42, 70])
        runner.check("today fatigue samples keep their timestamps",
                     samples.map(\.date) == [midnight, midday, now])
    }
}
