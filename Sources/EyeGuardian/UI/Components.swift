import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCorner)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct FatigueRing: View {
    let progress: Double
    var size: CGFloat = 180
    var lineWidth: CGFloat = 14

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(Theme.accentGradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: clamped)
        }
        .frame(width: size, height: size)
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SidebarRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.accent.opacity(0.15) : Color.clear)
            )
            .foregroundStyle(isSelected ? Theme.accentDeep : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
