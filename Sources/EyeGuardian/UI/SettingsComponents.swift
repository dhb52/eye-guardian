import SwiftUI

struct SettingsPane<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsPaneWithHeader<Header: View, Content: View>: View {
    private let header: Header
    private let content: Content

    init(@ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.header = header()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    content
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.settingsCardCorner)
                .fill(Theme.group)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.settingsCardCorner)
                .strokeBorder(Theme.hairline)
        )
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.leading, 60)
    }
}

struct SettingsIconTile: View {
    let icon: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(tint)
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

struct SettingsRow<Accessory: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 14) {
            SettingsIconTile(icon: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

extension SettingsRow where Accessory == EmptyView {
    init(icon: String, tint: Color, title: String, subtitle: String? = nil) {
        self.init(icon: icon, tint: tint, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct SettingsSliderRow: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String?
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let valueText: String
    var isEnabled: Bool = true

    var body: some View {
        SettingsRow(icon: icon, tint: tint, title: title, subtitle: subtitle) {
            HStack(spacing: 10) {
                Slider(value: sliderValue,
                       in: Double(range.lowerBound)...Double(range.upperBound))
                    .frame(width: 180)
                Text(valueText)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: 64, alignment: .trailing)
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { newValue in
                let raw = Int(newValue.rounded())
                let offset = (raw - range.lowerBound + step / 2) / step * step
                value = clampValue(range.lowerBound + offset, range.lowerBound, range.upperBound)
            }
        )
    }
}

struct SettingsChoice<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let preview: AnyView

    var id: Value { value }
}

struct SettingsChoiceGrid<Value: Hashable>: View {
    let choices: [SettingsChoice<Value>]
    @Binding var selection: Value
    var itemWidth: CGFloat = 88
    var previewHeight: CGFloat = 54

    var body: some View {
        HStack(spacing: 10) {
            ForEach(choices) { choice in
                item(choice)
            }
        }
    }

    private func item(_ choice: SettingsChoice<Value>) -> some View {
        let isSelected = choice.value == selection
        return Button {
            selection = choice.value
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.page)
                    choice.preview
                }
                .frame(width: itemWidth, height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Theme.selection : Color.primary.opacity(0.10),
                                      lineWidth: isSelected ? 2 : 1)
                )
                Text(choice.title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: itemWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

struct SettingsSidebarRow: View {
    @Environment(\.controlActiveState) private var controlActiveState

    let icon: String
    let tint: Color
    let title: String
    let isSelected: Bool
    var detail: String?
    let action: () -> Void

    private var isEmphasized: Bool { isSelected && controlActiveState == .key }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEmphasized ? Color.white.opacity(0.22) : tint)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isEmphasized ? Color.white : Color.primary)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 10.5))
                            .foregroundStyle(isEmphasized ? Color.white.opacity(0.8) : Color.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? SidebarSelection.fill(isEmphasized: isEmphasized) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct SettingsSidebar: View {
    @Binding var selection: SettingsTab
    let versionText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                SettingsSidebarRow(icon: tab.systemImage,
                                   tint: tab.tint,
                                   title: L10n.t(tab.titleKey),
                                   isSelected: selection == tab,
                                   detail: tab == .about ? versionText : nil) {
                    selection = tab
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 44)
        .padding(.bottom, 16)
        .frame(width: Theme.settingsSidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background { SidebarBackground() }
    }
}
