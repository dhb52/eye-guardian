import Combine
import Foundation
import os

@MainActor
final class UpdateService: ObservableObject {
    @Published private(set) var state: UpdateState

    let configuration: UpdateConfiguration

    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private let installer: UpdateInstaller
    private let api: UpdateAPI
    private let downloader: UpdateDownloading
    private let defaults: UserDefaults
    private let clock: () -> Date
    private let notificationsAllowed: () -> Bool
    private let isBreakActive: () -> Bool
    private let notify: (UpdateRelease) -> Void
    private let readyToQuit: () -> Void
    private let logger = Logger(subsystem: "com.barry.eyeguardian", category: "update")

    private(set) var checkTask: Task<Void, Never>?
    private(set) var downloadTask: Task<Void, Never>?
    private(set) var openTask: Task<Void, Never>?

    private var stateBeforeCheck: UpdateState = .idle
    private var downloadCancelled = false
    private var lastFailureWasDownload = false
    private var pendingNotification: UpdateRelease?
    private var autoCheckEnabled = false
    private var started = false
    private var lastCheckAt: Date?
    private var skippedVersion: UpdateVersion?
    private var downloaded: DownloadedUpdate?
    private var lastNotifiedVersion: String?
    private var lastNotifiedAt: Date?
    private var incompatibleVersion: UpdateVersion?
    private var incompatibleMinimum: String?
    private var tempDownloadURL: URL?

    private enum Keys {
        static let lastCheckAt = "update.lastCheckAt"
        static let skippedVersion = "update.skippedVersion"
        static let downloaded = "update.downloaded"
        static let lastNotifiedVersion = "update.lastNotifiedVersion"
        static let lastNotifiedAt = "update.lastNotifiedAt"
        static let incompatibleVersion = "update.incompatibleVersion"
        static let incompatibleMinimum = "update.incompatibleMinimum"
    }

    init(configuration: UpdateConfiguration,
         installer: UpdateInstaller,
         api: UpdateAPI,
         downloader: UpdateDownloading,
         defaults: UserDefaults = .standard,
         clock: @escaping () -> Date = Date.init,
         notificationsAllowed: @escaping () -> Bool = { false },
         isBreakActive: @escaping () -> Bool = { false },
         notify: @escaping (UpdateRelease) -> Void = { _ in },
         readyToQuit: @escaping () -> Void = {}) {
        self.configuration = configuration
        self.installer = installer
        self.api = api
        self.downloader = downloader
        self.defaults = defaults
        self.clock = clock
        self.notificationsAllowed = notificationsAllowed
        self.isBreakActive = isBreakActive
        self.notify = notify
        self.readyToQuit = readyToQuit
        self.state = .idle
        restoreState()
    }

    func start(autoCheckEnabled: Bool) {
        guard !started else { return }
        started = true
        self.autoCheckEnabled = autoCheckEnabled
        checkIfDue()
    }

    func setAutoCheckEnabled(_ enabled: Bool) {
        guard started else { return }
        guard autoCheckEnabled != enabled else { return }
        autoCheckEnabled = enabled
        if enabled { checkIfDue() }
    }

    func check(manual: Bool) {
        guard configuration.disabledReason == nil else { return }
        guard !state.isBusy else { return }
        if !manual && !autoCheckEnabled { return }
        if !manual, let lastCheckAt,
           clock().timeIntervalSince(lastCheckAt) < Self.checkInterval {
            return
        }
        stateBeforeCheck = state
        lastFailureWasDownload = false
        state = .checking
        checkTask = Task { [weak self] in
            await self?.performCheck(manual: manual)
        }
    }

    func download() {
        guard let release = state.release else { return }
        guard !state.isBusy else { return }
        if case .downloaded = state { return }
        downloadCancelled = false
        state = .downloading(release, progress: 0)
        downloadTask = Task { [weak self] in
            await self?.performDownload(release)
        }
    }

    func cancelDownload() {
        guard case .downloading(let release, _) = state else { return }
        downloadCancelled = true
        downloader.cancel()
        downloadTask?.cancel()
        if let temp = tempDownloadURL {
            cleanupTemp(temp)
            tempDownloadURL = nil
        }
        state = .available(release)
    }

    func skipCurrentRelease() {
        guard !state.isBusy, let release = state.release else { return }
        skippedVersion = release.version
        defaults.set(release.version.description, forKey: Keys.skippedVersion)
        pendingNotification = nil
        if case .downloaded(let downloadedRelease, let fileURL) = state {
            installer.removeDownloadedFile(fileURL, version: downloadedRelease.version)
            downloaded = nil
            clearDownloadedPersistence()
        }
        state = .skipped(version: release.version.description, release: release)
    }

    func unskip() {
        guard case .skipped(_, let release) = state else { return }
        clearSkipped()
        if let release {
            state = .available(release)
        } else {
            state = .idle
        }
    }

    func retry() {
        if case .failed(.incompatibleSystem, _, _) = state {
            check(manual: true)
            return
        }
        if lastFailureWasDownload, state.release != nil {
            download()
        } else {
            check(manual: true)
        }
    }

    func openDownloaded() {
        guard case .downloaded(let release, let fileURL) = state else { return }
        guard let downloaded,
              downloaded.fileURL.standardizedFileURL == fileURL.standardizedFileURL else {
            lastFailureWasDownload = true
            state = .failed(.fileMissing, release: release, manual: true)
            return
        }
        state = .opening(release, fileURL: fileURL)
        openTask = Task { [weak self] in
            await self?.performOpen(release, fileURL: fileURL, signature: downloaded.signature)
        }
    }

    func breakDidEnd() {
        guard let release = pendingNotification else { return }
        pendingNotification = nil
        guard state.release?.version == release.version else { return }
        maybeNotify(release)
    }

    func clearPendingNotification() {
        pendingNotification = nil
    }

    func stop() {
        checkTask?.cancel()
        checkTask = nil
        downloadCancelled = true
        downloader.cancel()
        downloadTask?.cancel()
        downloadTask = nil
        openTask?.cancel()
        openTask = nil
        if let temp = tempDownloadURL {
            cleanupTemp(temp)
            tempDownloadURL = nil
        }
    }

    // MARK: - Checking

    private func checkIfDue() {
        guard configuration.disabledReason == nil, autoCheckEnabled else { return }
        guard !state.isBusy else { return }
        if let lastCheckAt, clock().timeIntervalSince(lastCheckAt) < Self.checkInterval {
            return
        }
        check(manual: false)
    }

    private func performCheck(manual: Bool) async {
        do {
            let release = try await api.latestRelease()
            guard !Task.isCancelled else { return }
            guard let current = configuration.currentVersion else {
                throw UpdateError.configuration
            }
            let now = clock()

            if release.version <= current {
                recordCheck(now)
                if let downloaded,
                   downloaded.release.version >= release.version,
                   FileManager.default.fileExists(atPath: downloaded.fileURL.path) {
                    state = .downloaded(downloaded.release, fileURL: downloaded.fileURL)
                } else {
                    clearDownloadedState()
                    state = .upToDate(version: current.description, checkedAt: now)
                }
                if let skippedVersion, skippedVersion <= current {
                    clearSkipped()
                }
                return
            }

            if let skippedVersion, skippedVersion == release.version {
                recordCheck(now)
                state = .skipped(version: release.version.description, release: release)
                return
            }

            if let incompatibleVersion, incompatibleVersion == release.version {
                recordCheck(now)
                state = .failed(.incompatibleSystem(incompatibleMinimum ?? "macOS"),
                                release: release, manual: !manual)
                return
            }

            if let downloaded,
               downloaded.release.version == release.version,
               FileManager.default.fileExists(atPath: downloaded.fileURL.path) {
                recordCheck(now)
                state = .downloaded(downloaded.release, fileURL: downloaded.fileURL)
                return
            }

            if let downloaded, downloaded.release.version < release.version {
                installer.removeDownloadedFile(downloaded.fileURL, version: downloaded.release.version)
                self.downloaded = nil
                clearDownloadedPersistence()
            }
            if let incompatibleVersion, incompatibleVersion < release.version {
                clearIncompatible()
            }

            recordCheck(now)
            state = .available(release)
            if !manual { maybeNotify(release) }
        } catch {
            guard !Task.isCancelled else { return }
            if manual {
                state = .failed(Self.map(error), release: stateBeforeCheck.release, manual: true)
            } else {
                logger.error("update check failed: \(String(describing: error), privacy: .public)")
                state = stateBeforeCheck
            }
        }
    }

    private func recordCheck(_ date: Date) {
        lastCheckAt = date
        defaults.set(date, forKey: Keys.lastCheckAt)
    }

    // MARK: - Downloading

    private func performDownload(_ release: UpdateRelease) async {
        do {
            let temp = try await downloader.download(
                release.dmg.browserDownloadURL,
                userAgent: configuration.userAgent
            ) { [weak self] progress in
                guard let self else { return }
                if case .downloading(let current, _) = self.state,
                   current.version == release.version {
                    self.state = .downloading(release, progress: min(max(progress, 0), 1))
                }
            }
            guard !Task.isCancelled, !downloadCancelled else {
                cleanupTemp(temp)
                throw UpdateError.cancelled
            }
            tempDownloadURL = temp

            let signatureData = try await api.data(from: release.signature.browserDownloadURL)
            guard !Task.isCancelled, !downloadCancelled else {
                cleanupTemp(temp)
                throw UpdateError.cancelled
            }
            let signature = String(decoding: signatureData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let installer = self.installer
            try await Task.detached(priority: .userInitiated) {
                try installer.verify(fileURL: temp, signature: signature, release: release)
            }.value

            let finalURL = try installer.moveToInstallLocation(temp, version: release.version)
            tempDownloadURL = nil
            let downloaded = DownloadedUpdate(release: release,
                                              fileURL: finalURL,
                                              signature: signature)
            self.downloaded = downloaded
            persistDownloaded(downloaded)
            state = .downloaded(release, fileURL: finalURL)
        } catch {
            if let temp = tempDownloadURL {
                cleanupTemp(temp)
                tempDownloadURL = nil
            }
            if downloadCancelled || (error as? UpdateError) == .cancelled || Task.isCancelled {
                state = .available(release)
                return
            }
            lastFailureWasDownload = true
            state = .failed(Self.map(error), release: release, manual: true)
        }
    }

    // MARK: - Opening

    private func performOpen(_ release: UpdateRelease, fileURL: URL, signature: String) async {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            clearDownloadedState()
            lastFailureWasDownload = true
            state = .failed(.fileMissing, release: release, manual: true)
            return
        }

        let installer = self.installer
        do {
            let mounted = try await Task.detached(priority: .userInitiated) {
                try installer.verify(fileURL: fileURL, signature: signature, release: release)
                return try installer.mountAndValidate(fileURL, release: release)
            }.value

            guard installer.open(mounted.mountURL) else {
                installer.detach(mounted.mountURL)
                throw UpdateError.openFailed
            }
            readyToQuit()
        } catch {
            let mapped = Self.map(error)
            switch mapped {
            case .incompatibleSystem(let minimum):
                installer.removeDownloadedFile(fileURL, version: release.version)
                clearDownloadedState()
                incompatibleVersion = release.version
                incompatibleMinimum = minimum
                defaults.set(release.version.description, forKey: Keys.incompatibleVersion)
                defaults.set(minimum, forKey: Keys.incompatibleMinimum)
            case .signatureMismatch, .digestMismatch:
                installer.removeDownloadedFile(fileURL, version: release.version)
                clearDownloadedState()
            default:
                break
            }
            lastFailureWasDownload = true
            state = .failed(mapped, release: release, manual: true)
        }
    }

    // MARK: - Notifications

    private func maybeNotify(_ release: UpdateRelease) {
        guard notificationsAllowed() else { return }
        let version = release.version.description
        if lastNotifiedVersion == version,
           let lastNotifiedAt,
           clock().timeIntervalSince(lastNotifiedAt) < Self.checkInterval {
            return
        }
        if isBreakActive() {
            pendingNotification = release
            return
        }
        deliverNotification(release)
    }

    private func deliverNotification(_ release: UpdateRelease) {
        notify(release)
        lastNotifiedVersion = release.version.description
        lastNotifiedAt = clock()
        defaults.set(lastNotifiedVersion, forKey: Keys.lastNotifiedVersion)
        defaults.set(lastNotifiedAt, forKey: Keys.lastNotifiedAt)
    }

    // MARK: - Persistence

    private func restoreState() {
        if let reason = configuration.disabledReason {
            state = .disabled(reason)
            return
        }

        lastCheckAt = defaults.object(forKey: Keys.lastCheckAt) as? Date
        lastNotifiedVersion = defaults.string(forKey: Keys.lastNotifiedVersion)
        lastNotifiedAt = defaults.object(forKey: Keys.lastNotifiedAt) as? Date
        skippedVersion = defaults.string(forKey: Keys.skippedVersion).flatMap { UpdateVersion($0) }
        incompatibleVersion = defaults.string(forKey: Keys.incompatibleVersion).flatMap { UpdateVersion($0) }
        incompatibleMinimum = defaults.string(forKey: Keys.incompatibleMinimum)

        if let data = defaults.data(forKey: Keys.downloaded),
           let downloaded = try? JSONDecoder().decode(DownloadedUpdate.self, from: data) {
            if let current = configuration.currentVersion, current >= downloaded.release.version {
                installer.removeDownloadedFile(downloaded.fileURL, version: downloaded.release.version)
                clearDownloadedPersistence()
            } else if FileManager.default.fileExists(atPath: downloaded.fileURL.path) {
                self.downloaded = downloaded
                state = .downloaded(downloaded.release, fileURL: downloaded.fileURL)
                return
            } else {
                clearDownloadedPersistence()
            }
        }

        if let skippedVersion {
            state = .skipped(version: skippedVersion.description, release: nil)
        } else {
            state = .idle
        }
    }

    private func persistDownloaded(_ downloaded: DownloadedUpdate) {
        guard let data = try? JSONEncoder().encode(downloaded) else { return }
        defaults.set(data, forKey: Keys.downloaded)
    }

    private func clearDownloadedPersistence() {
        defaults.removeObject(forKey: Keys.downloaded)
    }

    private func clearDownloadedState() {
        downloaded = nil
        clearDownloadedPersistence()
    }

    private func clearSkipped() {
        skippedVersion = nil
        defaults.removeObject(forKey: Keys.skippedVersion)
    }

    private func clearIncompatible() {
        incompatibleVersion = nil
        incompatibleMinimum = nil
        defaults.removeObject(forKey: Keys.incompatibleVersion)
        defaults.removeObject(forKey: Keys.incompatibleMinimum)
    }

    private func cleanupTemp(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func map(_ error: Error) -> UpdateError {
        if let error = error as? UpdateError { return error }
        return .unknown
    }
}
