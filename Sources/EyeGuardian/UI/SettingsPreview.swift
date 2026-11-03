import AppKit
import SwiftUI

struct StatusPreviewBar: View {
    @Binding var darkOverride: Bool?
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    private var settings: AppSettings { model.settings }
    private var isDark: Bool { darkOverride ?? (colorScheme == .dark) }
    private var barInk: Color { isDark ? .white : Color(white: 0.10) }
    private var barFill: Color { isDark ? Color(white: 0.13) : Color(white: 0.97) }

    private var statusText: String {
        StatusBarTextFormatter.parts(fatiguePercent: model.fatiguePercent,
                                     screenMinutes: model.todayScreenMinutes,
                                     reminderCount: model.todayReminderCount,
                                     settings: settings)
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 10) {
            menuBarMock
            Text(L10n.t("LivePreviewCaption"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
    }

    private var menuBarMock: some View {
        HStack(spacing: 10) {
            Image(systemName: "applelogo")
                .font(.system(size: 12))
            Text(L10n.t("PreviewMenuBarApp"))
                .font(.system(size: 12))
            Spacer(minLength: 0)
            statusItemPreview
                .layoutPriority(1)
            Image(systemName: "wifi")
                .font(.system(size: 12))
            Image(systemName: "battery.75")
                .font(.system(size: 12))
            Text("9:41")
                .font(.system(size: 12).monospacedDigit())
            themeToggle
        }
        .foregroundStyle(barInk)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 9).fill(barFill))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(barInk.opacity(0.10)))
    }

    @ViewBuilder
    private var statusItemPreview: some View {
        if settings.showStatusBarIcon {
            HStack(spacing: 4) {
                Image(nsImage: statusIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: CGFloat(settings.effectiveStatusIconSize),
                           height: CGFloat(settings.effectiveStatusIconSize))
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 12).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "eye.slash")
                Text(L10n.t("StatusIconHidden"))
            }
            .font(.system(size: 11))
            .foregroundStyle(barInk.opacity(0.65))
        }
    }

    private var statusIcon: NSImage {
        StatusBarIconRenderer.image(fatigue: model.fatiguePercent,
                                    points: settings.effectiveStatusIconSize,
                                    style: settings.ringStyle,
                                    palette: settings.ringPalette,
                                    thickness: settings.ringThickness,
                                    dark: isDark,
                                    template: false)
    }

    private var themeToggle: some View {
        Button {
            darkOverride = !isDark
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(L10n.t(isDark ? "Dark" : "Light"))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(barInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(barInk.opacity(isDark ? 0.16 : 0.08)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("PreviewTheme"))
    }
}

enum SettingsThumbnails {
    static func ring(style: RingStyle, palette: RingPalette,
                     thickness: RingThickness, dark: Bool) -> AnyView {
        AnyView(
            Image(nsImage: StatusBarIconRenderer.image(fatigue: 88, points: 22,
                                                       style: style, palette: palette,
                                                       thickness: thickness, dark: dark,
                                                       template: false))
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
        )
    }

    static func placement(_ placement: StatusPlacement) -> AnyView {
        AnyView(
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                VStack(spacing: 0) {
                    if placement != .dock {
                        bar
                    }
                    Spacer(minLength: 0)
                    if placement != .menuBar {
                        bar
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
        )
    }

    private static var bar: some View {
        HStack(spacing: 0) {
            Capsule()
                .fill(Theme.selection)
                .frame(width: 10, height: 4)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(height: 9)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.10))
        )
    }

    static func mode(_ mode: UsageMode) -> AnyView {
        switch mode {
        case .smart:
            return AnyView(
                VStack(spacing: 3) {
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "keyboard")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Theme.selection)
            )
        case .dumb:
            return AnyView(
                Image(systemName: "clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.selection)
            )
        }
    }

    static func reminderStyle(_ style: ReminderStyle) -> AnyView {
        switch style {
        case .notification:
            return AnyView(
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        notificationBanner
                    }
                    Spacer(minLength: 0)
                }
                .padding(6)
            )
        case .miniPopup:
            return AnyView(miniPopup)
        case .fullScreen:
            return AnyView(
                LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 26, height: 4)
                    )
            )
        }
    }

    private static var notificationBanner: some View {
        HStack(spacing: 4) {
            Circle()
                .strokeBorder(Theme.selection, lineWidth: 2)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Capsule().fill(Color.primary.opacity(0.22)).frame(width: 22, height: 3)
                Capsule().fill(Color.primary.opacity(0.14)).frame(width: 16, height: 3)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.primary.opacity(0.10))
                )
        )
    }

    private static var miniPopup: some View {
        HStack(spacing: 5) {
            Circle()
                .strokeBorder(Theme.selection, lineWidth: 2)
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 2) {
                Capsule().fill(Color.primary.opacity(0.22)).frame(width: 20, height: 3)
                Capsule().fill(Color.primary.opacity(0.14)).frame(width: 14, height: 3)
            }
        }
        .padding(6)
        .frame(width: 62, height: 38)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color.primary.opacity(0.10))
                )
        )
    }

    static func popupSwatch(_ background: PopupBackground, imagePath: String?) -> AnyView {
        switch background {
        case .system, .purple:
            return AnyView(
                LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .light:
            return AnyView(
                LinearGradient(colors: [Color.white, Color(white: 0.86)],
                               startPoint: .top, endPoint: .bottom)
            )
        case .dark:
            return AnyView(
                LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                               startPoint: .top, endPoint: .bottom)
            )
        case .customImage:
            if let path = imagePath, let image = NSImage(contentsOfFile: path) {
                return AnyView(
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                )
            }
            return AnyView(
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            )
        }
    }
}
