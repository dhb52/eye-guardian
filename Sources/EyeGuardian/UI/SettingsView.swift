import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var local = SettingsLocalState()

    var body: some View {
        HStack(spacing: 0) {
            tabList
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 540)
        .alert(L10n.t("AppName"), isPresented: $local.showingAlert) {
            Button(L10n.t("OK")) {}
        } message: {
            Text(local.alertMessage)
        }
    }

    private var tabList: some View {
        SettingsTabList(selection: $local.selectedTab)
    }

    private var content: some View {
        Group {
            switch local.selectedTab {
            case .permissions:
                permissionsPane
            case .general:
                generalPane
            case .reminders:
                remindersPane
            case .accuracy:
                accuracyPane
            case .appearance:
                appearancePane
            case .data:
                dataPane
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionsPane: some View {
        Form {
            Section {
                PermissionList()
                PermissionFooter()
            }
        }
    }

    private var generalPane: some View {
        Form {
            Section {
                Toggle(L10n.t("LaunchAtLogin"), isOn: $model.settings.launchAtLogin)
                Toggle(L10n.t("ShowDockIcon"), isOn: dockBinding)
                Toggle(L10n.t("ShowStatusBarIcon"), isOn: statusBarBinding)
                Toggle(L10n.t("ShowFatiguePercent"), isOn: $model.settings.statusShowFatiguePercent)
                Toggle(L10n.t("ShowScreenTime"), isOn: hoursBinding)
                Toggle(L10n.t("ShowScreenTimeMinutes"), isOn: minutesBinding)
                Toggle(L10n.t("ShowReminderCount"), isOn: $model.settings.statusShowReminderCount)
                HStack {
                    Text(L10n.t("Shortcuts"))
                    Spacer()
                    Text("⌃⌥⌘B")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let error = model.loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var remindersPane: some View {
        Form {
            Section {
                Picker(L10n.t("ReminderStyle"), selection: $model.settings.reminderStyle) {
                    Text(L10n.t("Notification")).tag(ReminderStyle.notification)
                    Text(L10n.t("MiniPopup")).tag(ReminderStyle.miniPopup)
                    Text(L10n.t("FullScreen")).tag(ReminderStyle.fullScreen)
                }

                Stepper(value: $model.settings.fatigueThresholdMinutes, in: 5...180, step: 5) {
                    HStack {
                        Text(L10n.t("FatigueThreshold"))
                        Spacer()
                        Text("\(model.settings.fatigueThresholdMinutes) \(L10n.t("Mins"))")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $model.settings.restMinutes, in: 1...60) {
                    HStack {
                        Text(L10n.t("RestDuration"))
                        Spacer()
                        Text("\(model.settings.restMinutes) \(L10n.t("Mins"))")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $model.settings.notificationIntervalMinutes, in: 1...60) {
                    HStack {
                        Text(L10n.t("ReminderInterval"))
                        Spacer()
                        Text("\(model.settings.notificationIntervalMinutes) \(L10n.t("Mins"))")
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(L10n.t("PreReminder"), isOn: $model.settings.preReminderNotification)
                Toggle(L10n.t("PlaySound"), isOn: $model.settings.playSoundAtBreakEnd)
                Toggle(L10n.t("ShowSkipButton"), isOn: $model.settings.showSkipButton)

                Picker(L10n.t("BreakSkipping"), selection: $model.settings.skipMode) {
                    Text(L10n.t("SkipByButton")).tag(SkipMode.button)
                    Text(L10n.t("SkipByChallenge")).tag(SkipMode.challenge)
                    Text(L10n.t("CannotSkip")).tag(SkipMode.none)
                }

                Stepper(value: $model.settings.peakRepeatMinutes, in: 1...60) {
                    HStack {
                        Text("\(L10n.t("PeakRepeat")) \(model.settings.peakRepeatMinutes) \(L10n.t("Mins")) \(L10n.t("PeakRepeatSuffix"))")
                        Spacer()
                    }
                }

                Toggle(L10n.t("EnableScreenTimeReminder"), isOn: $model.settings.extraReminderEnabled)

                Stepper(value: $model.settings.extraReminderHours, in: 1...24) {
                    HStack {
                        Text(L10n.t("ScreenTimeReach"))
                        Spacer()
                        Text("\(model.settings.extraReminderHours) \(L10n.t("HoursSuffix"))")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!model.settings.extraReminderEnabled)
            }
        }
    }

    private var accuracyPane: some View {
        Form {
            Section {
                Picker(L10n.t("Mode"), selection: $model.settings.usageMode) {
                    Text(L10n.t("SmartMode")).tag(UsageMode.smart)
                    Text(L10n.t("DumbMode")).tag(UsageMode.dumb)
                }
                .pickerStyle(.segmented)

                Toggle(L10n.t("DetectMouse"), isOn: $model.settings.detectMouse)
                    .disabled(!model.settings.detectionActive)
                Toggle(L10n.t("DetectKeyboard"), isOn: $model.settings.detectKeyboard)
                    .disabled(!model.settings.detectionActive)
                Toggle(L10n.t("DetectScreen"), isOn: $model.settings.detectScreenChanges)
                    .disabled(!model.settings.detectionActive)
                Toggle(L10n.t("MovieMode"), isOn: $model.settings.movieMode)
                    .disabled(!model.settings.detectionActive)
            } footer: {
                Text(L10n.t("SmartOnlyHint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appearancePane: some View {
        Form {
            Section(L10n.t("IconSection")) {
                Picker(L10n.t("RingStyle"), selection: $model.settings.ringStyle) {
                    Text(L10n.t("RingStyleSolid")).tag(RingStyle.solid)
                    Text(L10n.t("RingStyleDotted")).tag(RingStyle.dotted)
                }
                Picker(L10n.t("RingPalette"), selection: $model.settings.ringPalette) {
                    Text(L10n.t("RingPaletteMono")).tag(RingPalette.monochrome)
                    Text(L10n.t("RingPaletteSpectrum")).tag(RingPalette.spectrum)
                }
                Picker(L10n.t("RingThickness"), selection: $model.settings.ringThickness) {
                    Text(L10n.t("RingThicknessThin")).tag(RingThickness.thin)
                    Text(L10n.t("RingThicknessRegular")).tag(RingThickness.regular)
                    Text(L10n.t("RingThicknessThick")).tag(RingThickness.thick)
                }
                Picker(L10n.t("StatusIconSize"), selection: $model.settings.statusIconSize) {
                    Text(L10n.t("StatusIconSizeSmall")).tag(StatusIconSize.small)
                    Text(L10n.t("StatusIconSizeMedium")).tag(StatusIconSize.medium)
                    Text(L10n.t("StatusIconSizeLarge")).tag(StatusIconSize.large)
                }
            }

            Section {
                Picker(L10n.t("PopupBackgroundLabel"), selection: $model.settings.popupBackground) {
                    Text(L10n.t("Auto")).tag(PopupBackground.system)
                    Text(L10n.t("Light")).tag(PopupBackground.light)
                    Text(L10n.t("Dark")).tag(PopupBackground.dark)
                    Text(L10n.t("Purple")).tag(PopupBackground.purple)
                    Text(L10n.t("CustomImage")).tag(PopupBackground.customImage)
                }

                if model.settings.popupBackground == .customImage {
                    HStack(spacing: 12) {
                        Button(L10n.t("SelectImage")) {
                            selectImage()
                        }
                        if model.settings.popupImagePath != nil {
                            Button(L10n.t("ClearImage")) {
                                removeImage()
                            }
                        }
                        Spacer()
                    }
                }

                Toggle(L10n.t("ShowScreenTimeOnPopup"), isOn: $model.settings.showScreenTimeOnPopup)

                HStack {
                    Text(L10n.t("PopupText"))
                    TextField(L10n.t("TakeABreak"), text: $model.settings.popupText)
                        .frame(width: 220)
                }
            }
        }
    }

    private var dataPane: some View {
        Form {
            Section {
                Button(L10n.t("ExportCSV")) {
                    exportCSV()
                }
                HStack {
                    Text(L10n.t("DataFolder"))
                    Spacer()
                    Text(dataDirectory.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var dockBinding: Binding<Bool> {
        Binding(
            get: { model.settings.showDockIcon },
            set: { value in
                if !value && !model.settings.showStatusBarIcon { return }
                model.settings.showDockIcon = value
            }
        )
    }

    private var statusBarBinding: Binding<Bool> {
        Binding(
            get: { model.settings.showStatusBarIcon },
            set: { value in
                if !value && !model.settings.showDockIcon { return }
                model.settings.showStatusBarIcon = value
            }
        )
    }

    private var hoursBinding: Binding<Bool> {
        Binding(
            get: { model.settings.statusShowScreenTimeHours },
            set: { value in
                model.settings.statusShowScreenTimeHours = value
                if value { model.settings.statusShowScreenTimeMinutes = false }
            }
        )
    }

    private var minutesBinding: Binding<Bool> {
        Binding(
            get: { model.settings.statusShowScreenTimeMinutes },
            set: { value in
                model.settings.statusShowScreenTimeMinutes = value
                if value { model.settings.statusShowScreenTimeHours = false }
            }
        )
    }

    private var dataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("EyeGuardian", isDirectory: true)
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let directory = dataDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
        let destination = directory.appendingPathComponent("popup-background.\(ext)")
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            model.settings.popupImagePath = destination.path
            model.settings.popupBackground = .customImage
        } catch {
            local.alertMessage = L10n.f("DataExportFailed", error.localizedDescription)
            local.showingAlert = true
        }
    }

    private func removeImage() {
        if let path = model.settings.popupImagePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        model.settings.popupImagePath = nil
        model.settings.popupBackground = .system
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "EyeGuardian-\(formatter.string(from: Date())).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let days = try model.exportCSV(to: url)
            local.alertMessage = L10n.f("DataExportDone", days)
        } catch {
            local.alertMessage = L10n.f("DataExportFailed", error.localizedDescription)
        }
        local.showingAlert = true
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case permissions
    case general
    case reminders
    case accuracy
    case appearance
    case data

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .permissions: return "Permissions"
        case .general: return "General"
        case .reminders: return "RemindersSection"
        case .accuracy: return "AccuracySection"
        case .appearance: return "AppearanceSection"
        case .data: return "DataSection"
        }
    }

    var systemImage: String {
        switch self {
        case .permissions: return "lock.shield"
        case .general: return "gearshape"
        case .reminders: return "bell"
        case .accuracy: return "scope"
        case .appearance: return "paintbrush"
        case .data: return "externaldrive"
        }
    }
}

private struct SettingsTabList: View {
    @Binding var selection: SettingsTab

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                SidebarRow(title: L10n.t(tab.titleKey),
                           systemImage: tab.systemImage,
                           isSelected: selection == tab) {
                    selection = tab
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 190)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

@MainActor
private final class SettingsLocalState: ObservableObject {
    @Published var selectedTab: SettingsTab = .permissions
    @Published var alertMessage = ""
    @Published var showingAlert = false
}
