import AppKit
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            Group {
                switch model.selectedSection {
                case .today:
                    TodayView()
                case .analysis:
                    AnalysisView()
                case .rules:
                    RulesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Theme.page.ignoresSafeArea() }
        }
        .frame(minWidth: 780, minHeight: 520)
        .sheet(isPresented: $model.isHelpPresented) {
            HelpView()
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                }
                Text(L10n.t("AppName"))
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            fatigueCard

            VStack(spacing: 4) {
                ForEach(AppModel.Section.allCases) { section in
                    SidebarRow(title: L10n.t(section.titleKey),
                               systemImage: section.systemImage,
                               isSelected: model.selectedSection == section) {
                        model.selectedSection = section
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                Button {
                    model.isHelpPresented = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help(L10n.t("Help"))

                Button {
                    model.showSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(L10n.t("Settings"))

                Spacer()
            }
            .buttonStyle(.plain)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: Theme.sidebarWidth)
        .background { SidebarBackground() }
    }

    private var fatigueCard: some View {
        HStack(spacing: 12) {
            ZStack {
                FatigueRing(progress: model.fatigue / 100, size: 54, lineWidth: 7)
                Text("\(model.fatiguePercent)%")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("Fatigue"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.stateText)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.page)
        )
    }
}

struct HelpView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.t("Help"))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(L10n.t("Close")) {
                    dismiss()
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    helpSection(titleKey: "How does Eye Guardian work?", bodyKey: "HowItWorksBody")
                    helpSection(titleKey: "Limitations", bodyKey: "LimitationsBody")
                    helpSection(titleKey: "About Privacy", bodyKey: "PrivacyBody")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 520, height: 480)
    }

    private func helpSection(titleKey: String, bodyKey: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t(titleKey))
                .font(.headline)
            Text(L10n.t(bodyKey))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
