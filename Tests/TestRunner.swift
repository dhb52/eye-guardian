import Foundation

final class TestRunner {
    private var total = 0
    private var failures = 0

    func check(_ name: String, _ condition: @autoclosure () -> Bool) {
        total += 1
        if condition() {
            print("PASS \(name)")
        } else {
            failures += 1
            print("FAIL \(name)")
        }
    }

    func finish() -> Never {
        print("\(total) tests, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
