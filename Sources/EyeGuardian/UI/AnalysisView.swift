import Charts
import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var state: AnalysisState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(title: L10n.t("NavAnalysis"), subtitle: nil)

                HStack(alignment: .center, spacing: 16) {
                    Picker(L10n.t("Range"), selection: $state.range) {
                        Text(L10n.t("Last7Days")).tag(ChartRange.last7Days)
                        Text(L10n.t("Last28Days")).tag(ChartRange.last28Days)
                        Text(L10n.t("Last90Days")).tag(ChartRange.last90Days)
                        Text(L10n.t("Last12Months")).tag(ChartRange.last12Months)
                        Text(L10n.t("AllTime")).tag(ChartRange.allTime)
                    }
                    .pickerStyle(.menu)
                    .fixedSize()

                    HStack(spacing: 8) {
                        Text(L10n.t("Granularity"))
                            .lineLimit(1)
                            .fixedSize()
                        Picker(L10n.t("Granularity"), selection: $state.granularity) {
                            Text(L10n.t("Daily")).tag(ChartGranularity.daily)
                            Text(L10n.t("Weekly")).tag(ChartGranularity.weekly)
                            Text(L10n.t("Monthly")).tag(ChartGranularity.monthly)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(minWidth: 190, maxWidth: 240)
                    }
                }

                if state.loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }

                ChartCard(title: L10n.t("ScreenTime"),
                          subtitle: L10n.t("ScreenTimeHours"),
                          points: state.data.screenTimeHours,
                          style: .bar)

                ChartCard(title: L10n.t("FatiguePeak"),
                          subtitle: L10n.t("DurationMins"),
                          points: state.data.peakMinutes,
                          style: .bar)

                ChartCard(title: L10n.t("Compliance"),
                          subtitle: L10n.t("CompletionRate"),
                          points: state.data.compliancePercent,
                          style: .line)
            }
            .padding(24)
        }
        .onAppear {
            state.load(store: model.store)
        }
        .onChange(of: state.range) { _ in
            state.load(store: model.store)
        }
        .onChange(of: state.granularity) { _ in
            state.load(store: model.store)
        }
    }
}

@MainActor
final class AnalysisState: ObservableObject {
    @Published var range: ChartRange = .last7Days
    @Published var granularity: ChartGranularity = .daily
    @Published private(set) var data = AnalysisData.empty
    @Published private(set) var loading = false

    func load(store: EventStore) {
        loading = true
        let range = self.range
        let granularity = self.granularity
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = store.analysis(range: range, granularity: granularity, now: Date())
            Task { @MainActor in
                self?.data = result
                self?.loading = false
            }
        }
    }
}

private struct ChartCard: View {
    enum ChartStyle {
        case bar
        case line
    }

    let title: String
    let subtitle: String
    let points: [ChartPoint]
    let style: ChartStyle

    private var isEmpty: Bool {
        points.allSatisfy { $0.value == 0 }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isEmpty {
                    Text(L10n.t("NoData"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    chart
                        .frame(height: 200)
                }
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        Chart(points) { point in
            switch style {
            case .bar:
                BarMark(
                    x: .value("Bucket", point.label),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Theme.accent.gradient)
                .cornerRadius(3)
            case .line:
                AreaMark(
                    x: .value("Bucket", point.label),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Theme.accent.opacity(0.12))
                LineMark(
                    x: .value("Bucket", point.label),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
        .chartYAxis {
            AxisMarks()
        }
    }
}
