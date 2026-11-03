import SwiftUI

struct FullScreenReminderView: View {
    @ObservedObject var session: BreakSessionModel
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            ReminderBackdrop(session: session)
            ReminderContent(session: session, compact: false, onSkip: onSkip)
        }
        .ignoresSafeArea()
        .onExitCommand {
            if session.requestSkip() {
                onSkip()
            }
        }
    }
}

struct MiniReminderView: View {
    @ObservedObject var session: BreakSessionModel
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            ReminderBackdrop(session: session)
            ReminderContent(session: session, compact: true, onSkip: onSkip)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.18))
        )
        .onExitCommand {
            if session.requestSkip() {
                onSkip()
            }
        }
    }
}

private struct ReminderBackdrop: View {
    let session: BreakSessionModel

    var body: some View {
        Group {
            switch session.background {
            case .customImage:
                if let image = session.backgroundImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .overlay(Color.black.opacity(0.45))
                        .clipped()
                } else {
                    systemGradient
                }
            case .light:
                LinearGradient(colors: [Color(white: 0.98), Color(white: 0.87)],
                               startPoint: .top, endPoint: .bottom)
            case .dark:
                LinearGradient(colors: [Color(white: 0.12), Color(white: 0.03)],
                               startPoint: .top, endPoint: .bottom)
            case .purple:
                LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            case .system:
                systemGradient
            }
        }
    }

    private var systemGradient: some View {
        LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct ReminderContent: View {
    @ObservedObject var session: BreakSessionModel
    let compact: Bool
    let onSkip: () -> Void

    private var foreground: Color {
        session.background == .light ? .black : .white
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 26) {
            Text(session.title)
                .font(.system(size: compact ? 19 : 34, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            ZStack {
                Circle()
                    .stroke(foreground.opacity(0.2), lineWidth: compact ? 8 : 16)
                Circle()
                    .trim(from: 0, to: session.progress)
                    .stroke(foreground,
                            style: StrokeStyle(lineWidth: compact ? 8 : 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: session.progress)
                Text(session.timeText)
                    .font(.system(size: compact ? 38 : 64, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: compact ? 118 : 220, height: compact ? 118 : 220)

            if let screenTime = session.screenTimeText {
                Text(screenTime)
                    .font(compact ? .caption : .subheadline)
                    .opacity(0.85)
            }

            if case .challenge(let a, let b, let error) = session.stage {
                challenge(a: a, b: b, error: error)
            } else if session.skipAvailable {
                Button {
                    if session.requestSkip() {
                        onSkip()
                    }
                } label: {
                    Text(L10n.t("Skip"))
                        .font(.system(size: compact ? 13 : 16, weight: .medium))
                        .padding(.horizontal, compact ? 18 : 26)
                        .padding(.vertical, compact ? 6 : 9)
                        .background(Capsule().fill(foreground.opacity(0.18)))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(foreground)
        .padding(compact ? 16 : 40)
    }

    private func challenge(a: Int, b: Int, error: Bool) -> some View {
        VStack(spacing: 8) {
            Text(L10n.f("ChallengeIntro", "\(a) × \(b) = ?"))
                .font(compact ? .callout : .title3)

            TextField(L10n.t("EnterAnswer"), text: $session.answer)
                .textFieldStyle(.roundedBorder)
                .frame(width: compact ? 160 : 220)
                .onSubmit {
                    if session.submitChallenge() {
                        onSkip()
                    }
                }

            if error {
                Text(L10n.t("ChallengeError"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Button(L10n.t("CancelAndRest")) {
                    session.cancelChallenge()
                }
                Button(L10n.t("SubmitAndSkip")) {
                    if session.submitChallenge() {
                        onSkip()
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(compact ? .small : .regular)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(foreground.opacity(0.12))
        )
    }
}
