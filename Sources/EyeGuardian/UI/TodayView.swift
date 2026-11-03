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
                    VStack(spacing: 14) {
                        ZStack {
                            FatigueRing(progress: model.fatigue / 100, size: 180, lineWidth: 14)
                            VStack(spacing: 2) {
                                Text("\(model.fatiguePercent)%")
                                    .font(.system(size: 44, weight: .semibold))
                                    .monospacedDigit()
                                Text(L10n.t("Fatigue"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(model.stateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
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
                                .fill(Theme.accent)
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
