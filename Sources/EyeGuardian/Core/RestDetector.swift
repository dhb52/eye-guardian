import Foundation

enum RestDetector {
    static let idleThreshold: TimeInterval = 60

    static func isResting(now: Date,
                          lastActivityAt: Date?,
                          locked: Bool,
                          asleep: Bool,
                          inBreak: Bool,
                          smartMode: Bool) -> Bool {
        if inBreak || locked || asleep { return true }
        guard smartMode else { return false }
        guard let last = lastActivityAt else { return true }
        return now.timeIntervalSince(last) >= idleThreshold
    }
}
