import Charts
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(title: L10n.t("NavToday"), subtitle: nil)

                if model.hasMissingPermission {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.t("Permissions"))
                                .font(.headline)
                            PermissionList(showsSatisfied: false)
                            PermissionFooter()
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("Fatigue"))
                                    .font(.headline)
                                Text(model.stateText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text("\(model.fatiguePercent)%")
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                        }

                        if model.todayFatigueSamples.isEmpty {
                            Text(L10n.t("NoData"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            TodayFatigueChart(samples: model.todayFatigueSamples)
                                .frame(height: 200)
                        }
                    }
                }

                HStack(spacing: 12) {
                    MetricCard(title: L10n.t("ScreenTimeToday"),
                               value: DurationFormat.abbreviated(minutes: model.todayScreenMinutes),
                               systemImage: "display")
                    MetricCard(title: L10n.t("RemindersToday"),
                               value: "\(model.todayReminderCount)",
                               systemImage: "bell")
                }

                Button {
                    model.startBreakNow()
                } label: {
                    Label(L10n.t("StartBreakNow"), systemImage: "cup.and.saucer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.accentDeep)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("Tips"))
                            .font(.headline)
                        Text(L10n.t("HintKeepUsing"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct TodayFatigueChart: View {
    let samples: [FatigueSample]

    private var dayStart: Date {
        Calendar.current.startOfDay(for: samples.last?.date ?? Date())
    }

    private var end: Date {
        let last = samples.last?.date ?? dayStart
        return max(last.addingTimeInterval(60), dayStart.addingTimeInterval(3600))
    }

    var body: some View {
        Chart(samples) { sample in
            AreaMark(
                x: .value("Time", sample.date),
                y: .value("Fatigue", sample.value)
            )
            .foregroundStyle(
                LinearGradient(colors: [Theme.accent.opacity(0.20), Theme.accent.opacity(0.02)],
                               startPoint: .top, endPoint: .bottom)
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Time", sample.date),
                y: .value("Fatigue", sample.value)
            )
            .foregroundStyle(Theme.accent)
            .interpolationMethod(.monotone)
        }
        .chartXScale(domain: dayStart...end)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Int.self) {
                        Text("\(percent)%")
                    }
                }
            }
        }
    }
}
