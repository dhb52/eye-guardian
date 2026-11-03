import AppKit

@MainActor
final class BreakSessionModel: ObservableObject {
    enum Stage: Equatable {
        case idle
        case challenge(a: Int, b: Int, error: Bool)
    }

    let totalSeconds: Int
    let style: ReminderStyle
    let skipMode: SkipMode
    let showsSkipButton: Bool
    let title: String
    let screenTimeText: String?
    let background: PopupBackground
    let backgroundImage: NSImage?
    let endDate: Date

    @Published private(set) var remainingSeconds: Int
    @Published private(set) var stage: Stage = .idle
    @Published var answer: String = ""

    init(totalSeconds: Int,
         style: ReminderStyle,
         skipMode: SkipMode,
         showsSkipButton: Bool,
         title: String,
         screenTimeText: String?,
         background: PopupBackground,
         imagePath: String?) {
        let seconds = max(1, totalSeconds)
        self.totalSeconds = seconds
        self.style = style
        self.skipMode = skipMode
        self.showsSkipButton = showsSkipButton
        self.title = title
        self.screenTimeText = screenTimeText
        self.endDate = Date().addingTimeInterval(TimeInterval(seconds))
        self.remainingSeconds = seconds

        if background == .customImage,
           let path = imagePath,
           let image = NSImage(contentsOfFile: path) {
            self.background = .customImage
            self.backgroundImage = image
        } else {
            self.background = background == .customImage ? .system : background
            self.backgroundImage = nil
        }
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var timeText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var skipAvailable: Bool {
        showsSkipButton && skipMode != .none
    }

    func update(now: Date) -> Bool {
        let remaining = max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
        if remaining != remainingSeconds {
            remainingSeconds = remaining
        }
        return remaining == 0
    }

    func requestSkip() -> Bool {
        switch skipMode {
        case .button:
            return true
        case .challenge:
            if case .idle = stage {
                stage = .challenge(a: Int.random(in: 11...29),
                                   b: Int.random(in: 3...9),
                                   error: false)
                answer = ""
            }
            return false
        case .none:
            return false
        }
    }

    func submitChallenge() -> Bool {
        guard case .challenge(let a, let b, _) = stage else { return false }
        if Int(answer.trimmingCharacters(in: .whitespaces)) == a * b {
            return true
        }
        stage = .challenge(a: a, b: b, error: true)
        return false
    }

    func cancelChallenge() {
        stage = .idle
        answer = ""
    }
}
