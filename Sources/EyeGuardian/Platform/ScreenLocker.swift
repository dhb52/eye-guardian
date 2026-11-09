import Foundation

enum ScreenLocker {
    private typealias LockFunction = @convention(c) () -> Int32

    private static let path = "/System/Library/PrivateFrameworks/login.framework/Versions/A/login"

    @discardableResult
    static func lock() -> Bool {
        guard let handle = dlopen(path, RTLD_NOW),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else { return false }
        let lock = unsafeBitCast(symbol, to: LockFunction.self)
        return lock() == 0
    }
}
