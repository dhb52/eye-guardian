import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var local = SettingsLocalState()

    var body: some View {
        Form {
            Section(L10n.t("Permissions")) {
                PermissionList()
                PermissionFooter()
            }

            Section(L10n.t("General")) {
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

            Section(L10n.t("RemindersSection")) {
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

            Section(L10n.t("AccuracySection")) {
                Picker(L10n.t("Mode"), selection: $model.settings.usageMode) {
                    Text(L10n.t("SmartMode")).tag(UsageMode.smart)
                    Text(L10n.t("DumbMode")).tag(UsageMode.dumb)
                }
                .pickerStyle(.segmented)

                Toggle(L10n.t("DetectMouse"), isOn: $model.settings.detectMouse)
                Toggle(L10n.t("DetectKeyboard"), isOn: $model.settings.detectKeyboard)
                Toggle(L10n.t("DetectScreen"), isOn: $model.settings.detectScreenChanges)
                Toggle(L10n.t("MovieMode"), isOn: $model.settings.movieMode)
            }

            Section(L10n.t("AppearanceSection")) {
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

            Section(L10n.t("DataSection")) {
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
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 620, minHeight: 700)
        .alert(L10n.t("AppName"), isPresented: $local.showingAlert) {
            Button(L10n.t("OK")) {}
        } message: {
            Text(local.alertMessage)
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


@MainActor
private final class SettingsLocalState: ObservableObject {
    @Published var alertMessage = ""
    @Published var showingAlert = false
}
