import AppKit
import SwiftUI
import UserNotifications

enum PermissionKind: String {
    case accessibility
    case screenRecording
    case notifications

    var titleKey: String {
        switch self {
        case .accessibility: return "PermissionAccessibility"
        case .screenRecording: return "PermissionScreenRecording"
        case .notifications: return "PermissionNotifications"
        }
    }

    var reasonKey: String {
        switch self {
        case .accessibility: return "AccessibilityReason"
        case .screenRecording: return "ScreenRecordingReason"
        case .notifications: return "NotificationsReason"
        }
    }

    var systemImage: String {
        switch self {
        case .accessibility: return "accessibility"
        case .screenRecording: return "display"
        case .notifications: return "bell"
        }
    }

    var tint: Color {
        switch self {
        case .accessibility: return .blue
        case .screenRecording: return .purple
        case .notifications: return .orange
        }
    }

    var settingsURLString: String {
        switch self {
        case .accessibility:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .notifications:
            return "x-apple.systempreferences:com.apple.preference.notifications"
        }
    }

    var supportsDragGuide: Bool {
        self == .accessibility || self == .screenRecording
    }

    func actionTitleKey(for state: PermissionState) -> String? {
        switch self {
        case .accessibility:
            return state == .notGranted ? "OpenSettingsForAccessibility" : nil
        case .screenRecording:
            return state == .notGranted ? "OpenSettingsForScreenRecording" : nil
        case .notifications:
            switch state {
            case .notGranted: return "AllowNotifications"
            case .denied: return "OpenNotificationSettings"
            default: return nil
            }
        }
    }
}

enum PermissionState: Equatable {
    case granted
    case notGranted
    case denied
    case notRequired

    var isActionable: Bool { self == .notGranted || self == .denied }

    var labelKey: String {
        switch self {
        case .granted: return "PermissionGranted"
        case .notGranted: return "PermissionNotGranted"
        case .denied: return "PermissionDenied"
        case .notRequired: return "PermissionNotUsed"
        }
    }
}

struct PermissionStatus: Identifiable {
    let kind: PermissionKind
    let state: PermissionState
    var id: String { kind.rawValue }
}

struct PermissionList: View {
    @EnvironmentObject private var model: AppModel
    var showsSatisfied = true

    var body: some View {
        let rows = statuses
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, status in
            PermissionRow(status: status, showsDivider: index < rows.count - 1)
        }
    }

    private var statuses: [PermissionStatus] {
        showsSatisfied
            ? model.permissionStatuses
            : model.permissionStatuses.filter { $0.state.isActionable }
    }
}

struct PermissionRow: View {
    let status: PermissionStatus
    var showsDivider = false
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                SettingsIconTile(icon: status.kind.systemImage, tint: status.kind.tint)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(L10n.t(status.kind.titleKey))
                            .font(.system(size: 13, weight: .medium))
                        Label(L10n.t(status.state.labelKey), systemImage: stateIcon)
                            .font(.caption)
                            .foregroundStyle(stateColor)
                    }

                    Text(L10n.t(status.kind.reasonKey))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if status.state == .notRequired {
                        Text(L10n.t("PermissionNotUsedHint"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                if let key = status.kind.actionTitleKey(for: status.state) {
                    Button(L10n.t(key)) { activate() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 56)

            if showsDivider {
                SettingsDivider()
            }
        }
    }

    private var stateIcon: String {
        switch status.state {
        case .granted: return "checkmark.circle.fill"
        case .notGranted: return "exclamationmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notRequired: return "minus.circle"
        }
    }

    private var stateColor: Color {
        switch status.state {
        case .granted: return .green
        case .notGranted: return .orange
        case .denied: return .red
        case .notRequired: return .secondary
        }
    }

    private func activate() {
        switch status.kind {
        case .notifications where model.notificationAuthorization == .notDetermined:
            model.requestNotificationAuthorization()
        default:
            model.openPermissionSettings(status.kind)
        }
    }
}

struct PermissionFooter: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("PermissionRestartHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(L10n.t("RestartApp")) { model.relaunch() }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

extension AppModel {
    var permissionStatuses: [PermissionStatus] {
        [
            PermissionStatus(kind: .accessibility,
                             state: mergedState(granted: accessibilityTrusted,
                                                needed: settings.effectiveDetectKeyboard)),
            PermissionStatus(kind: .screenRecording,
                             state: mergedState(granted: screenRecordingTrusted,
                                                needed: settings.effectiveDetectScreenChanges)),
            PermissionStatus(kind: .notifications, state: notificationState),
        ]
    }

    var hasMissingPermission: Bool {
        permissionStatuses.contains { $0.state.isActionable }
    }

    func openPermissionSettings(_ kind: PermissionKind) {
        guard let url = URL(string: kind.settingsURLString) else { return }
        if kind.supportsDragGuide {
            permissionGuide.show(kind)
        }
        if !NSWorkspace.shared.open(url) {
            permissionGuide.hide()
        }
    }

    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL,
                                           configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    private func mergedState(granted: Bool, needed: Bool) -> PermissionState {
        if granted { return .granted }
        return needed ? .notGranted : .notRequired
    }

    private var notificationState: PermissionState {
        switch notificationAuthorization {
        case .authorized, .provisional:
            return .granted
        case .denied:
            return .denied
        default:
            return notificationsNeeded ? .notGranted : .notRequired
        }
    }

    private var notificationsNeeded: Bool {
        settings.reminderStyle == .notification
            || settings.preReminderNotification
            || settings.extraReminderEnabled
    }
}
