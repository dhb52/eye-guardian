import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var local = SettingsLocalState()

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $local.selectedTab, versionText: versionText)
            content
        }
        .frame(minWidth: 880, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(L10n.t("AppName"), isPresented: $local.showingAlert) {
            Button(L10n.t("OK")) {}
        } message: {
            Text(local.alertMessage)
        }
        .sheet(isPresented: $local.showingHelp) {
            HelpView().environmentObject(model)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch local.selectedTab {
        case .general: generalPane
        case .statusBar: statusBarPane
        case .reminders: remindersPane
        case .detection: detectionPane
        case .appearance: appearancePane
        case .permissions: permissionsPane
        case .data: dataPane
        case .about: aboutPane
        }
    }

    // MARK: - General

    private var generalPane: some View {
        SettingsPane {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(L10n.t("General"))
                SettingsCard {
                    languageRow
                    SettingsDivider()
                    launchAtLoginRow
                    SettingsDivider()
                    shortcutsRow
                    if let error = model.loginItemError {
                        SettingsDivider()
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
    }

    private var languageRow: some View {
        SettingsRow(icon: "globe", tint: .blue,
                    title: L10n.t("Language"),
                    subtitle: L10n.t("LanguageHint")) {
            Picker("", selection: $model.settings.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(L10n.t(language.titleKey)).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    private var launchAtLoginRow: some View {
        SettingsRow(icon: "power", tint: .teal,
                    title: L10n.t("LaunchAtLogin"),
                    subtitle: L10n.t("LaunchAtLoginHint")) {
            Toggle("", isOn: $model.settings.launchAtLogin)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var shortcutsRow: some View {
        SettingsRow(icon: "keyboard", tint: .indigo,
                    title: L10n.t("Shortcuts"),
                    subtitle: L10n.t("ShortcutsHint")) {
            Text("⌃⌥⌘B")
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                )
        }
    }

    // MARK: - Status Bar

    private var statusBarPane: some View {
        SettingsPane {
            VStack(alignment: .leading, spacing: 22) {
                StatusPreviewBar(darkOverride: $local.previewDarkOverride)
                VStack(alignment: .leading, spacing: 10) {
                    SettingsSectionHeader(L10n.t("StatusBarSection"))
                    SettingsCard {
                        placementRow
                        SettingsDivider()
                        fatiguePercentRow
                        SettingsDivider()
                        screenTimeRow
                        SettingsDivider()
                        reminderCountRow
                    }
                }
            }
        }
    }

    private var placementRow: some View {
        SettingsRow(icon: "menubar.rectangle", tint: .blue,
                    title: L10n.t("StatusPlacement"),
                    subtitle: L10n.t("StatusPlacementHint")) {
            SettingsChoiceGrid(choices: StatusPlacement.allCases.map { placement in
                SettingsChoice(value: placement,
                               title: L10n.t(placement.titleKey),
                               preview: SettingsThumbnails.placement(placement))
            }, selection: statusPlacementBinding)
        }
    }

    private var fatiguePercentRow: some View {
        SettingsRow(icon: "percent", tint: .orange,
                    title: L10n.t("ShowFatiguePercent"),
                    subtitle: L10n.t("StatusFatigueHint")) {
            Toggle("", isOn: $model.settings.statusShowFatiguePercent)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var screenTimeRow: some View {
        SettingsRow(icon: "clock", tint: .cyan,
                    title: L10n.t("ScreenTime"),
                    subtitle: L10n.t("StatusScreenTimeHint")) {
            Picker("", selection: statusScreenTimeBinding) {
                ForEach(StatusScreenTimeStyle.allCases) { style in
                    Text(L10n.t(style.titleKey)).tag(style)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    private var reminderCountRow: some View {
        SettingsRow(icon: "bell.badge", tint: .pink,
                    title: L10n.t("ShowReminderCount"),
                    subtitle: L10n.t("StatusReminderCountHint")) {
            Toggle("", isOn: $model.settings.statusShowReminderCount)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    // MARK: - Reminders

    private var remindersPane: some View {
        SettingsPane {
            VStack(alignment: .leading, spacing: 22) {
                timingSection
                styleSection
                extraReminderSection
            }
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(L10n.t("TimingSection"))
            SettingsCard {
                SettingsSliderRow(icon: "hourglass", tint: .orange,
                                  title: L10n.t("FatigueThreshold"),
                                  subtitle: L10n.t("FatigueThresholdHint"),
                                  value: $model.settings.fatigueThresholdMinutes,
                                  range: 5...180, step: 5,
                                  valueText: "\(model.settings.fatigueThresholdMinutes) \(L10n.t("Mins"))")
                SettingsDivider()
                SettingsSliderRow(icon: "cup.and.saucer.fill", tint: .brown,
                                  title: L10n.t("RestDuration"),
                                  subtitle: L10n.t("RestDurationHint"),
                                  value: $model.settings.restMinutes,
                                  range: 1...60,
                                  valueText: "\(model.settings.restMinutes) \(L10n.t("Mins"))")
                SettingsDivider()
                SettingsSliderRow(icon: "repeat", tint: .indigo,
                                  title: L10n.t("PeakRepeat"),
                                  subtitle: L10n.t("ReminderIntervalHint"),
                                  value: $model.settings.notificationIntervalMinutes,
                                  range: 1...60,
                                  valueText: "\(model.settings.notificationIntervalMinutes) \(L10n.t("Mins"))")
            }
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(L10n.t("StyleSection"))
            SettingsCard {
                reminderStyleRow
                SettingsDivider()
                preReminderRow
                SettingsDivider()
                playSoundRow
                SettingsDivider()
                skipButtonRow
                SettingsDivider()
                breakSkippingRow
            }
        }
    }

    private var reminderStyleRow: some View {
        SettingsRow(icon: "bell.fill", tint: .red,
                    title: L10n.t("ReminderStyle")) {
            SettingsChoiceGrid(choices: [
                SettingsChoice(value: ReminderStyle.notification,
                               title: L10n.t("Notification"),
                               preview: SettingsThumbnails.reminderStyle(.notification)),
                SettingsChoice(value: ReminderStyle.miniPopup,
                               title: L10n.t("MiniPopup"),
                               preview: SettingsThumbnails.reminderStyle(.miniPopup)),
                SettingsChoice(value: ReminderStyle.fullScreen,
                               title: L10n.t("FullScreen"),
                               preview: SettingsThumbnails.reminderStyle(.fullScreen)),
            ], selection: $model.settings.reminderStyle)
        }
    }

    private var preReminderRow: some View {
        SettingsRow(icon: "bell.badge", tint: .purple,
                    title: L10n.t("PreReminder"),
                    subtitle: L10n.t("PreReminderHint")) {
            Toggle("", isOn: $model.settings.preReminderNotification)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var playSoundRow: some View {
        SettingsRow(icon: "speaker.wave.2.fill", tint: .green,
                    title: L10n.t("PlaySound"),
                    subtitle: L10n.t("PlaySoundHint")) {
            Toggle("", isOn: $model.settings.playSoundAtBreakEnd)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var skipEnabled: Bool { model.settings.skipMode != .none }

    private var skipButtonRow: some View {
        SettingsRow(icon: "forward.end.fill", tint: .gray,
                    title: L10n.t("ShowSkipButton"),
                    subtitle: L10n.t("ShowSkipButtonHint")) {
            Toggle("", isOn: $model.settings.showSkipButton)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .disabled(!skipEnabled)
        .opacity(skipEnabled ? 1 : 0.5)
    }

    private var breakSkippingRow: some View {
        SettingsRow(icon: "arrow.uturn.forward", tint: .teal,
                    title: L10n.t("BreakSkipping"),
                    subtitle: L10n.t("BreakSkippingHint")) {
            Picker("", selection: $model.settings.skipMode) {
                Text(L10n.t("SkipByButton")).tag(SkipMode.button)
                Text(L10n.t("SkipByChallenge")).tag(SkipMode.challenge)
                Text(L10n.t("CannotSkip")).tag(SkipMode.none)
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var extraReminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(L10n.t("ExtraReminderSection"))
            SettingsCard {
                SettingsRow(icon: "clock.badge.checkmark", tint: .green,
                            title: L10n.t("EnableScreenTimeReminder"),
                            subtitle: L10n.t("ExtraReminderHint")) {
                    Toggle("", isOn: $model.settings.extraReminderEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                SettingsDivider()
                SettingsSliderRow(icon: "clock.arrow.circlepath", tint: .cyan,
                                  title: L10n.t("ScreenTimeReach"),
                                  subtitle: L10n.t("ScreenTimeReachHint"),
                                  value: $model.settings.extraReminderHours,
                                  range: 1...24,
                                  valueText: "\(model.settings.extraReminderHours) \(L10n.t("HoursSuffix"))",
                                  isEnabled: model.settings.extraReminderEnabled)
            }
        }
    }

    // MARK: - Detection

    private var detectionPane: some View {
        SettingsPane {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(L10n.t("DetectionSection"))
                SettingsCard {
                    modeRow
                    SettingsDivider()
                    detectionToggleRow(icon: "computermouse.fill", tint: .blue,
                                       title: L10n.t("DetectMouse"),
                                       subtitle: L10n.t("DetectMouseHint"),
                                       isOn: $model.settings.detectMouse)
                    SettingsDivider()
                    detectionToggleRow(icon: "keyboard.fill", tint: .indigo,
                                       title: L10n.t("DetectKeyboard"),
                                       subtitle: L10n.t("DetectKeyboardHint"),
                                       isOn: $model.settings.detectKeyboard)
                    SettingsDivider()
                    detectionToggleRow(icon: "display", tint: .purple,
                                       title: L10n.t("DetectScreen"),
                                       subtitle: L10n.t("DetectScreenHint"),
                                       isOn: $model.settings.detectScreenChanges)
                    SettingsDivider()
                    detectionToggleRow(icon: "film.fill", tint: .pink,
                                       title: L10n.t("MovieMode"),
                                       subtitle: L10n.t("MovieModeHint"),
                                       isOn: $model.settings.movieMode)
                }
                Text(L10n.t("SmartOnlyHint"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
    }

    private var modeRow: some View {
        SettingsRow(icon: "switch.2", tint: .green,
                    title: L10n.t("Mode"),
                    subtitle: L10n.t("ModeHint")) {
            SettingsChoiceGrid(choices: [
                SettingsChoice(value: UsageMode.smart,
                               title: L10n.t("SmartMode"),
                               preview: SettingsThumbnails.mode(.smart)),
                SettingsChoice(value: UsageMode.dumb,
                               title: L10n.t("DumbMode"),
                               preview: SettingsThumbnails.mode(.dumb)),
            ], selection: $model.settings.usageMode)
        }
    }

    private func detectionToggleRow(icon: String, tint: Color, title: String,
                                    subtitle: String, isOn: Binding<Bool>) -> some View {
        SettingsRow(icon: icon, tint: tint, title: title, subtitle: subtitle) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .disabled(!model.settings.detectionActive)
        .opacity(model.settings.detectionActive ? 1 : 0.5)
    }

    // MARK: - Appearance

    private var appearancePane: some View {
        SettingsPane {
            VStack(alignment: .leading, spacing: 22) {
                StatusPreviewBar(darkOverride: $local.previewDarkOverride)
                iconSection
                popupSection
            }
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(L10n.t("IconSection"))
            SettingsCard {
                ringStyleRow
                SettingsDivider()
                ringPaletteRow
                SettingsDivider()
                ringThicknessRow
                SettingsDivider()
                iconSizeRow
            }
        }
    }

    private var ringStyleRow: some View {
        SettingsRow(icon: "circle.dashed", tint: .purple,
                    title: L10n.t("RingStyle")) {
            SettingsChoiceGrid(choices: [
                SettingsChoice(value: RingStyle.solid,
                               title: L10n.t("RingStyleSolid"),
                               preview: ringThumbnail(style: .solid)),
                SettingsChoice(value: RingStyle.dotted,
                               title: L10n.t("RingStyleDotted"),
                               preview: ringThumbnail(style: .dotted)),
            ], selection: $model.settings.ringStyle)
        }
    }

    private var ringPaletteRow: some View {
        SettingsRow(icon: "paintpalette.fill", tint: .pink,
                    title: L10n.t("RingPalette")) {
            SettingsChoiceGrid(choices: [
                SettingsChoice(value: RingPalette.monochrome,
                               title: L10n.t("RingPaletteMono"),
                               preview: ringThumbnail(palette: .monochrome)),
                SettingsChoice(value: RingPalette.spectrum,
                               title: L10n.t("RingPaletteSpectrum"),
                               preview: ringThumbnail(palette: .spectrum)),
            ], selection: $model.settings.ringPalette)
        }
    }

    private var ringThicknessRow: some View {
        SettingsRow(icon: "lineweight", tint: .indigo,
                    title: L10n.t("RingThickness")) {
            SettingsChoiceGrid(choices: [
                SettingsChoice(value: RingThickness.thin,
                               title: L10n.t("RingThicknessThin"),
                               preview: ringThumbnail(thickness: .thin)),
                SettingsChoice(value: RingThickness.regular,
                               title: L10n.t("RingThicknessRegular"),
                               preview: ringThumbnail(thickness: .regular)),
                SettingsChoice(value: RingThickness.thick,
                               title: L10n.t("RingThicknessThick"),
                               preview: ringThumbnail(thickness: .thick)),
            ], selection: $model.settings.ringThickness)
        }
    }

    private var iconSizeRow: some View {
        SettingsSliderRow(icon: "arrow.up.left.and.arrow.down.right", tint: .indigo,
                          title: L10n.t("StatusIconSize"),
                          subtitle: L10n.t("StatusIconSizeHint"),
                          value: Binding(
                              get: { model.settings.effectiveStatusIconSize },
                              set: { model.settings.statusIconSize = $0 }
                          ),
                          range: 14...22,
                          valueText: L10n.f("PointsFormat", model.settings.effectiveStatusIconSize))
    }

    private func ringThumbnail(style: RingStyle? = nil,
                               palette: RingPalette? = nil,
                               thickness: RingThickness? = nil) -> AnyView {
        SettingsThumbnails.ring(style: style ?? model.settings.ringStyle,
                                palette: palette ?? model.settings.ringPalette,
                                thickness: thickness ?? model.settings.ringThickness,
                                dark: colorScheme == .dark)
    }

    private var popupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(L10n.t("AppearancePopupSection"))
            SettingsCard {
                popupBackgroundRow
                if model.settings.popupBackground == .customImage {
                    SettingsDivider()
                    popupImageButtons
                }
                SettingsDivider()
                showScreenTimeOnPopupRow
                SettingsDivider()
                popupTextRow
            }
        }
    }

    private var popupBackgroundRow: some View {
        SettingsRow(icon: "photo.fill", tint: .purple,
                    title: L10n.t("PopupBackgroundLabel")) {
            HStack(spacing: 8) {
                SettingsThumbnails.popupSwatch(model.settings.popupBackground,
                                               imagePath: model.settings.popupImagePath)
                    .frame(width: 36, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Picker("", selection: $model.settings.popupBackground) {
                    Text(L10n.t("Auto")).tag(PopupBackground.system)
                    Text(L10n.t("Light")).tag(PopupBackground.light)
                    Text(L10n.t("Dark")).tag(PopupBackground.dark)
                    Text(L10n.t("Purple")).tag(PopupBackground.purple)
                    Text(L10n.t("CustomImage")).tag(PopupBackground.customImage)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }

    private var popupImageButtons: some View {
        HStack(spacing: 8) {
            Button(L10n.t("SelectImage")) {
                selectImage()
            }
            .buttonStyle(.bordered)
            if model.settings.popupImagePath != nil {
                Button(L10n.t("ClearImage")) {
                    removeImage()
                }
                .buttonStyle(.bordered)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var showScreenTimeOnPopupRow: some View {
        SettingsRow(icon: "clock", tint: .cyan,
                    title: L10n.t("ShowScreenTimeOnPopup"),
                    subtitle: L10n.t("ShowScreenTimeOnPopupHint")) {
            Toggle("", isOn: $model.settings.showScreenTimeOnPopup)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var popupTextRow: some View {
        SettingsRow(icon: "textformat", tint: .blue,
                    title: L10n.t("PopupText"),
                    subtitle: L10n.t("PopupTextHint")) {
            TextField(L10n.t("TakeABreak"), text: $model.settings.popupText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
        }
    }

    // MARK: - Permissions

    private var permissionsPane: some View {
        SettingsPane {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(L10n.t("Permissions"))
                SettingsCard {
                    PermissionList()
                    SettingsDivider()
                    PermissionFooter()
                }
            }
        }
    }

    // MARK: - Data

    private var dataPane: some View {
        SettingsPane {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(L10n.t("DataSection"))
                SettingsCard {
                    SettingsRow(icon: "square.and.arrow.up", tint: .green,
                                title: L10n.t("ExportDataTitle"),
                                subtitle: L10n.t("ExportDataHint")) {
                        Button(L10n.t("ExportAction")) {
                            exportCSV()
                        }
                        .buttonStyle(.bordered)
                    }
                    SettingsDivider()
                    dataFolderRow
                }
                Text(L10n.t("DataFolderHint"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
    }

    private var dataFolderRow: some View {
        HStack(spacing: 14) {
            SettingsIconTile(icon: "folder.fill", tint: .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("DataFolder"))
                    .font(.system(size: 13, weight: .medium))
                Text(dataDirectory.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(L10n.t("ShowInFinder")) {
                NSWorkspace.shared.activateFileViewerSelecting([dataDirectory])
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }

    // MARK: - About

    private var aboutPane: some View {
        SettingsPane {
            VStack(alignment: .leading, spacing: 22) {
                appIdentityCard
                resourcesCard
                defaultsCard
            }
        }
    }

    private var appIdentityCard: some View {
        SettingsCard {
            VStack(spacing: 8) {
                appIcon
                Text(L10n.t("AppName"))
                    .font(.system(size: 17, weight: .semibold))
                Text(versionText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = NSImage(named: "AppIcon") {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 64, height: 64)
        } else {
            Image(systemName: "eye")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accent)
                .frame(width: 64, height: 64)
        }
    }

    private var resourcesCard: some View {
        SettingsCard {
            SettingsRow(icon: "questionmark.circle.fill", tint: .blue,
                        title: L10n.t("Help"),
                        subtitle: L10n.t("AboutHelpHint")) {
                Button(L10n.t("Open")) {
                    local.showingHelp = true
                }
                .buttonStyle(.bordered)
            }
            SettingsDivider()
            SettingsRow(icon: "hand.raised.fill", tint: .teal,
                        title: L10n.t("About Privacy"),
                        subtitle: L10n.t("PrivacyBody"))
        }
    }

    private var defaultsCard: some View {
        SettingsCard {
            SettingsRow(icon: "arrow.counterclockwise", tint: .red,
                        title: L10n.t("RestoreDefaultsTitle"),
                        subtitle: L10n.t("RestoreDefaultsHint")) {
                Button(L10n.t("RestoreAction")) {
                    local.showingResetAlert = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .alert(L10n.t("RestoreConfirmTitle"), isPresented: $local.showingResetAlert) {
            Button(L10n.t("RestoreConfirmAction"), role: .destructive) {
                restoreDefaults()
            }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t("RestoreConfirmMessage"))
        }
    }

    // MARK: - Bindings

    private var statusPlacementBinding: Binding<StatusPlacement> {
        Binding(
            get: { model.settings.statusPlacement },
            set: { model.settings.statusPlacement = $0 }
        )
    }

    private var statusScreenTimeBinding: Binding<StatusScreenTimeStyle> {
        Binding(
            get: { model.settings.statusScreenTimeStyle },
            set: { model.settings.statusScreenTimeStyle = $0 }
        )
    }

    // MARK: - Helpers

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return L10n.f("VersionFormat", short, build)
    }

    private var dataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("EyeGuardian", isDirectory: true)
    }

    private func restoreDefaults() {
        let language = model.settings.language
        if let path = model.settings.popupImagePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        var defaults = AppSettings.default
        defaults.language = language
        model.settings = defaults
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

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case statusBar
    case reminders
    case detection
    case appearance
    case permissions
    case data
    case about

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .general: return "General"
        case .statusBar: return "StatusBarSection"
        case .reminders: return "RemindersSection"
        case .detection: return "DetectionSection"
        case .appearance: return "AppearanceSection"
        case .permissions: return "Permissions"
        case .data: return "DataSection"
        case .about: return "AboutSection"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape.fill"
        case .statusBar: return "menubar.rectangle"
        case .reminders: return "bell.fill"
        case .detection: return "scope"
        case .appearance: return "paintbrush.pointed.fill"
        case .permissions: return "lock.shield.fill"
        case .data: return "externaldrive.fill"
        case .about: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: return .gray
        case .statusBar: return .blue
        case .reminders: return .red
        case .detection: return .green
        case .appearance: return .purple
        case .permissions: return .teal
        case .data: return .indigo
        case .about: return .orange
        }
    }
}

@MainActor
private final class SettingsLocalState: ObservableObject {
    @Published var selectedTab: SettingsTab = .general
    @Published var previewDarkOverride: Bool?
    @Published var showingHelp = false
    @Published var showingResetAlert = false
    @Published var alertMessage = ""
    @Published var showingAlert = false
}
