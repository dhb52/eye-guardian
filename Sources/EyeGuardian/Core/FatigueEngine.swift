import Foundation

struct FatigueEngine: Equatable {
    private(set) var fatigue: Double = 0

    var percent: Int { Int(fatigue.rounded()) }

    mutating func tick(deltaSeconds: Double,
                       screenActive: Bool,
                       resting: Bool,
                       workMinutes: Int) {
        guard deltaSeconds > 0 else { return }
        if resting {
            fatigue = max(0, fatigue - deltaSeconds * (20.0 / 60.0))
        } else if screenActive {
            let rate = 100.0 / (Double(clampValue(workMinutes, 5, 180)) * 60.0)
            fatigue = min(100, fatigue + deltaSeconds * rate)
        }
    }

    mutating func applyRest(minutes: Double) {
        guard minutes > 0 else { return }
        fatigue = max(0, fatigue - minutes * 20.0)
    }

    mutating func reset() {
        fatigue = 0
    }

    mutating func setFatigue(_ value: Double) {
        fatigue = clampValue(value, 0, 100)
    }
}
