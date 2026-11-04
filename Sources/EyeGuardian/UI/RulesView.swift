import SwiftUI

struct RulesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: L10n.t("NavRules"), subtitle: nil)

                defaultTimingCard

                ForEach(Array(model.settings.rules.enumerated()), id: \.element.id) { index, rule in
                    ruleCard(index: index, rule: rule)
                }

                Text(L10n.t("RulesExplanation"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
    }

    private var defaultTimingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("DefaultTiming"))
                    .font(.headline)
                Text(L10n.t("DefaultTimingHint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Stepper(value: defaultWorkBinding, in: 5...180, step: 5) {
                        HStack {
                            Text(L10n.f("WorkForFormat", model.settings.fatigueThresholdMinutes))
                            Spacer()
                        }
                    }
                    Text(L10n.t("FatigueThresholdHint"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Stepper(value: defaultRestBinding, in: 1...60) {
                        HStack {
                            Text(L10n.f("BreakForFormat", model.settings.restMinutes))
                            Spacer()
                        }
                    }
                    Text(L10n.t("RestDurationHint"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Stepper(value: defaultRepeatBinding, in: 1...60) {
                        HStack {
                            Text(L10n.f("RepeatForFormat", model.settings.notificationIntervalMinutes))
                            Spacer()
                        }
                    }
                    Text(L10n.t("ReminderIntervalHint"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var defaultWorkBinding: Binding<Int> {
        Binding(
            get: { model.settings.fatigueThresholdMinutes },
            set: { model.settings.fatigueThresholdMinutes = $0 }
        )
    }

    private var defaultRestBinding: Binding<Int> {
        Binding(
            get: { model.settings.restMinutes },
            set: { model.settings.restMinutes = $0 }
        )
    }

    private var defaultRepeatBinding: Binding<Int> {
        Binding(
            get: { model.settings.notificationIntervalMinutes },
            set: { model.settings.notificationIntervalMinutes = $0 }
        )
    }

    private func ruleCard(index: Int, rule: BreakRule) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle("", isOn: enabledBinding(index))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    Text(L10n.f("RuleFormat", index + 1))
                        .font(.headline)
                    Spacer()
                }

                HStack(spacing: 20) {
                    DatePicker(L10n.t("From"),
                               selection: timeBinding(index, keyPath: \.startMinutes),
                               displayedComponents: .hourAndMinute)
                    DatePicker(L10n.t("To"),
                               selection: timeBinding(index, keyPath: \.endMinutes),
                               displayedComponents: .hourAndMinute)
                }

                Stepper(value: workBinding(index), in: 5...180, step: 5) {
                    HStack {
                        Text(L10n.f("WorkForFormat", rule.workMinutes))
                        Spacer()
                    }
                }

                Stepper(value: restBinding(index), in: 1...60) {
                    HStack {
                        Text(L10n.f("BreakForFormat", rule.restMinutes))
                        Spacer()
                    }
                }

                Stepper(value: repeatBinding(index), in: 1...60) {
                    HStack {
                        Text(L10n.f("RepeatForFormat", rule.repeatMinutes))
                        Spacer()
                    }
                }
            }
        }
    }

    private func enabledBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { model.settings.rules[index].isEnabled },
            set: { model.settings.rules[index].isEnabled = $0 }
        )
    }

    private func workBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { model.settings.rules[index].workMinutes },
            set: { model.settings.rules[index].workMinutes = $0 }
        )
    }

    private func restBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { model.settings.rules[index].restMinutes },
            set: { model.settings.rules[index].restMinutes = $0 }
        )
    }

    private func repeatBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { model.settings.rules[index].repeatMinutes },
            set: { model.settings.rules[index].repeatMinutes = $0 }
        )
    }

    private func timeBinding(_ index: Int,
                             keyPath: WritableKeyPath<BreakRule, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = model.settings.rules[index][keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60,
                                             minute: minutes % 60,
                                             second: 0,
                                             of: Date()) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.settings.rules[index][keyPath: keyPath] =
                    (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }
}
