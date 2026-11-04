import AppKit

@MainActor
final class SystemStateObserver {
    private(set) var isLocked = false
    private(set) var isAsleep = false
    var onChange: (() -> Void)?

    private var distributedObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    func start() {
        guard distributedObservers.isEmpty else { return }
        refreshLockState()
        let distributed = DistributedNotificationCenter.default()
        distributedObservers.append(
            distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"),
                                    object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isLocked = true
                    self?.onChange?()
                }
            }
        )
        distributedObservers.append(
            distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                                    object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isLocked = false
                    self?.onChange?()
                }
            }
        )

        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            workspace.addObserver(forName: NSWorkspace.willSleepNotification,
                                  object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isAsleep = true
                    self?.refreshLockState()
                    self?.onChange?()
                }
            }
        )
        workspaceObservers.append(
            workspace.addObserver(forName: NSWorkspace.didWakeNotification,
                                  object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isAsleep = false
                    self?.refreshLockState()
                    self?.onChange?()
                }
            }
        )
    }

    func stop() {
        let distributed = DistributedNotificationCenter.default()
        distributedObservers.forEach { distributed.removeObserver($0) }
        distributedObservers.removeAll()
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { workspace.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    func refreshLockState() {
        isLocked = Self.isScreenLocked
    }

    private static var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? NSNumber)?.boolValue ?? false
    }
}
