import AppKit
import SwiftUI

struct UpdateCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.isUpdateFeatureVisible {
            SettingsCard {
                SettingsRow(icon: "arrow.triangle.2.circlepath", tint: .orange,
                            title: L10n.t("UpdateSection"),
                            subtitle: statusText) {
                    if model.isUpdateSupported {
                        Button(buttonTitle) {
                            model.showUpdateSheet(checkIfNeeded: true)
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.updateState.isBusy && !model.updateState.isDownloading)
                    }
                }
                if model.isUpdateSupported {
                    SettingsDivider()
                    SettingsRow(icon: "clock.arrow.circlepath", tint: .gray,
                                title: L10n.t("UpdateAutoCheck"),
                                subtitle: L10n.t("UpdateAutoCheckHint")) {
                        Toggle("", isOn: $model.settings.autoCheckUpdates)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }
        }
    }

    private var statusText: String {
        switch model.updateState {
        case .disabled(let reason):
            return reason.message
        case .idle:
            return L10n.t("UpdateStatusIdle")
        case .checking:
            return L10n.t("UpdateStatusChecking")
        case .upToDate(let version, let checkedAt):
            return L10n.f("UpdateStatusUpToDateFormat", version, time(checkedAt))
        case .skipped(let version, _):
            return L10n.f("UpdateStatusSkippedFormat", version)
        case .available(let release):
            return L10n.f("UpdateStatusAvailableFormat", release.version.description)
        case .downloading(let release, let progress):
            return L10n.f("UpdateStatusDownloadingFormat",
                          release.version.description,
                          Int(progress * 100))
        case .downloaded(let release, _):
            return L10n.f("UpdateStatusDownloadedFormat", release.version.description)
        case .opening:
            return L10n.t("UpdateStatusOpening")
        case .failed(let error, _, _):
            return error.localizedDescription
        }
    }

    private var buttonTitle: String {
        switch model.updateState {
        case .checking:
            return L10n.t("UpdateMenuChecking")
        case .downloading:
            return L10n.t("UpdateViewProgress")
        case .opening:
            return L10n.t("UpdateStatusOpening")
        case .available, .downloaded, .skipped, .failed:
            return L10n.t("UpdateView")
        default:
            return L10n.t("UpdateCheckNow")
        }
    }

    private func time(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
}

struct UpdateSheet: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var local = UpdateSheetState()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            footer
        }
        .padding(22)
        .frame(width: 540, height: 480)
        .background(Theme.page)
        .alert(L10n.t("UpdateBreakConfirmTitle"), isPresented: $local.showingBreakAlert) {
            Button(L10n.t("UpdateBreakConfirmAction"), role: .destructive) {
                model.updateService.openDownloaded()
            }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t("UpdateBreakConfirmMessage"))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            SettingsIconTile(icon: "arrow.triangle.2.circlepath", tint: .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("UpdateSheetTitle"))
                    .font(.system(size: 16, weight: .semibold))
                Text(L10n.f("UpdateCurrentVersionFormat", currentVersion))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.updateState {
        case .disabled(let reason):
            Text(reason.message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .idle:
            Text(L10n.t("UpdateStatusIdle"))
                .foregroundStyle(.secondary)
        case .checking:
            ProgressView(L10n.t("UpdateStatusChecking"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .upToDate(let version, let checkedAt):
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.green)
                Text(L10n.f("UpdateStatusUpToDateFormat", version, time(checkedAt)))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .skipped(let version, let release):
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.f("UpdateStatusSkippedFormat", version))
                    .foregroundStyle(.secondary)
                if let release { releaseHeader(release) }
            }
        case .available(let release):
            releaseDetails(release)
        case .downloading(let release, let progress):
            VStack(alignment: .leading, spacing: 12) {
                releaseHeader(release)
                ProgressView(value: progress)
                Text(L10n.f("UpdateStatusDownloadingFormat",
                            release.version.description,
                            Int(progress * 100)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(L10n.t("UpdateDownloadContinuesHint"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .downloaded(let release, _):
            VStack(alignment: .leading, spacing: 12) {
                releaseHeader(release)
                Text(L10n.t("UpdateInstallSteps"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .opening:
            ProgressView(L10n.t("UpdateStatusOpening"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error, let release, _):
            VStack(alignment: .leading, spacing: 10) {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                if let release { releaseHeader(release) }
            }
        }
    }

    private func releaseDetails(_ release: UpdateRelease) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            releaseHeader(release)
            Divider()
            Text(L10n.t("UpdateReleaseNotes"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                notesText(release.notes)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 120)
        }
    }

    private func releaseHeader(_ release: UpdateRelease) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.f("UpdateLatestVersionFormat", release.version.description))
                .font(.system(size: 13, weight: .semibold))
            HStack(spacing: 8) {
                if let date = release.publishedAt {
                    Text(L10n.f("UpdatePublishedFormat", time(date)))
                }
                Text(ByteCountFormatter.string(fromByteCount: Int64(release.dmg.size),
                                               countStyle: .file))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch model.updateState {
        case .available:
            HStack(spacing: 8) {
                Button(L10n.t("UpdateSkipVersion")) {
                    model.updateService.skipCurrentRelease()
                    close()
                }
                .buttonStyle(.bordered)
                Spacer(minLength: 0)
                Button(L10n.t("UpdateLater")) { close() }
                    .buttonStyle(.bordered)
                Button(L10n.t("UpdateDownload")) { model.updateService.download() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        case .downloading:
            HStack(spacing: 8) {
                Button(L10n.t("UpdateCancel")) { model.updateService.cancelDownload() }
                    .buttonStyle(.bordered)
                Spacer(minLength: 0)
                Button(L10n.t("UpdateLater")) { close() }
                    .buttonStyle(.bordered)
            }
        case .downloaded:
            HStack(spacing: 8) {
                Button(L10n.t("UpdateSkipVersion")) {
                    model.updateService.skipCurrentRelease()
                    close()
                }
                .buttonStyle(.bordered)
                Spacer(minLength: 0)
                Button(L10n.t("UpdateLater")) { close() }
                    .buttonStyle(.bordered)
                Button(L10n.t("UpdateOpenDMG")) { openDownloaded() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        case .skipped:
            HStack(spacing: 8) {
                if model.updateState.release != nil {
                    Button(L10n.t("UpdateUnskip")) { model.updateService.unskip() }
                        .buttonStyle(.bordered)
                    Spacer(minLength: 0)
                    Button(L10n.t("UpdateDownload")) { model.updateService.download() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Spacer(minLength: 0)
                    Button(L10n.t("UpdateClose")) { close() }
                        .buttonStyle(.bordered)
                }
            }
        case .failed:
            HStack(spacing: 8) {
                if model.updateState.release != nil {
                    Button(L10n.t("UpdateSkipVersion")) {
                        model.updateService.skipCurrentRelease()
                        close()
                    }
                    .buttonStyle(.bordered)
                }
                Spacer(minLength: 0)
                Button(L10n.t("UpdateClose")) { close() }
                    .buttonStyle(.bordered)
                Button(L10n.t("UpdateRetry")) { model.updateService.retry() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        case .idle, .upToDate:
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(L10n.t("UpdateClose")) { close() }
                    .buttonStyle(.bordered)
                Button(L10n.t("UpdateCheckNow")) { model.updateService.check(manual: true) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        case .checking, .opening:
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(L10n.t("UpdateClose")) { close() }
                    .buttonStyle(.bordered)
            }
        case .disabled:
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(L10n.t("UpdateClose")) { close() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func openDownloaded() {
        if model.breakSession != nil {
            local.showingBreakAlert = true
        } else {
            model.updateService.openDownloaded()
        }
    }

    private func close() {
        model.updateSheetPresented = false
    }

    private func time(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private func notesText(_ notes: String) -> Text {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Text(L10n.t("UpdateNoReleaseNotes"))
        }
        let cleaned = trimmed
            .components(separatedBy: .newlines)
            .map { line -> String in
                let value = line.trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("#") {
                    let title = value.drop(while: { $0 == "#" })
                        .trimmingCharacters(in: .whitespaces)
                    return title.isEmpty ? "" : "**\(title)**"
                }
                if value.hasPrefix("- ") { return "• " + value.dropFirst(2) }
                if value.hasPrefix("* ") { return "• " + value.dropFirst(2) }
                if value.hasPrefix("> ") { return String(value.dropFirst(2)) }
                return line
            }
            .joined(separator: "\n")
        if let attributed = try? AttributedString(
            markdown: cleaned,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(cleaned)
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

private final class UpdateSheetState: ObservableObject {
    @Published var showingBreakAlert = false
}
