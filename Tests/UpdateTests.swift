import CryptoKit
import Foundation
import Testing

@testable import EyeGuardianKit

private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("EyeGuardianTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeRelease(version: String, digest: String? = nil, size: Int = 1024) -> UpdateRelease {
    let value = UpdateVersion(version)!
    let dmgName = "EyeGuardian-\(value).dmg"
    return UpdateRelease(
        version: value,
        tag: "v\(value)",
        notes: "Release notes",
        publishedAt: nil,
        dmg: GitHubRelease.Asset(
            name: dmgName,
            size: size,
            digest: digest,
            browserDownloadURL: URL(string: "https://example.com/\(dmgName)")!
        ),
        signature: GitHubRelease.Asset(
            name: dmgName + ".sig",
            size: 64,
            digest: nil,
            browserDownloadURL: URL(string: "https://example.com/\(dmgName).sig")!
        ),
        htmlURL: URL(string: "https://example.com/release")!
    )
}

private func makeConfiguration(publicKey: String,
                               downloads: URL,
                               fallback: URL,
                               currentVersion: String = "1.0.0") -> UpdateConfiguration {
    UpdateConfiguration(
        enabled: true,
        publicKey: publicKey,
        currentVersionString: currentVersion,
        bundleIdentifier: "com.barry.eyeguardian",
        downloadsDirectory: downloads,
        fallbackUpdatesDirectory: fallback
    )
}

private struct StubAPI: UpdateAPI {
    let release: UpdateRelease
    var signature: Data = Data()
    var error: UpdateError?

    func latestRelease() async throws -> UpdateRelease {
        if let error { throw error }
        return release
    }

    func data(from url: URL) async throws -> Data {
        signature
    }
}

private final class StubDownloader: UpdateDownloading {
    let fileURL: URL
    let error: UpdateError?
    private(set) var cancelled = false

    init(fileURL: URL, error: UpdateError? = nil) {
        self.fileURL = fileURL
        self.error = error
    }

    func download(_ url: URL,
                  userAgent: String,
                  progress: @escaping @MainActor (Double) -> Void) async throws -> URL {
        await progress(1)
        if let error { throw error }
        return fileURL
    }

    func cancel() {
        cancelled = true
    }
}

private func makeDefaults() -> (String, UserDefaults) {
    let suite = "EyeGuardianTests-\(UUID().uuidString)"
    return (suite, UserDefaults(suiteName: suite)!)
}

@Test func testUpdateVersionParsingAndOrdering() {
    check("parses v1.2.3", UpdateVersion.releaseTag("v1.2.3") == UpdateVersion(major: 1, minor: 2, patch: 3))
    check("parses bare 1.2.3", UpdateVersion("1.2.3") == UpdateVersion(major: 1, minor: 2, patch: 3))
    check("rejects two components", UpdateVersion("1.2") == nil)
    check("rejects four components", UpdateVersion("1.2.3.4") == nil)
    check("rejects non-numeric components", UpdateVersion("v1.2.x") == nil)
    check("release tags require v", UpdateVersion.releaseTag("1.2.3") == nil)
    check("orders minor numerically", UpdateVersion("1.10.0")! > UpdateVersion("1.9.9")!)
    check("orders major numerically", UpdateVersion("2.0.0")! > UpdateVersion("1.99.99")!)
    check("v prefix is ignored", UpdateVersion("v1.0.0") == UpdateVersion("1.0.0"))
}

@Test func testUpdateReleaseSelection() throws {
    let json = """
    {
      "tag_name": "v1.2.0",
      "name": "v1.2.0",
      "body": "Notes",
      "published_at": "2026-11-09T14:55:32Z",
      "html_url": "https://github.com/dhb52/eye-guardian/releases/tag/v1.2.0",
      "draft": false,
      "prerelease": false,
      "assets": [
        {
          "name": "EyeGuardian-1.2.0.dmg",
          "size": 1491456,
          "digest": "sha256:3d068d062510122f50f065e116369acc91d981fe8401348f357665f9f5f55af7",
          "browser_download_url": "https://github.com/dhb52/eye-guardian/releases/download/v1.2.0/EyeGuardian-1.2.0.dmg"
        },
        {
          "name": "EyeGuardian-1.2.0.dmg.sig",
          "size": 88,
          "digest": null,
          "browser_download_url": "https://github.com/dhb52/eye-guardian/releases/download/v1.2.0/EyeGuardian-1.2.0.dmg.sig"
        }
      ]
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let github = try decoder.decode(GitHubRelease.self, from: Data(json.utf8))
    let release = try #require(UpdateRelease(githubRelease: github))
    check("selects tag version", release.version == UpdateVersion("1.2.0"))
    check("selects disk image", release.dmg.name == "EyeGuardian-1.2.0.dmg")
    check("selects signature", release.signature.name == "EyeGuardian-1.2.0.dmg.sig")
    check("keeps release notes", release.notes == "Notes")
    check("keeps published date", release.publishedAt != nil)
    check("keeps digest", release.dmg.digest?.hasPrefix("sha256:") == true)

    let draft = GitHubRelease(tagName: github.tagName,
                              name: github.name,
                              body: github.body,
                              publishedAt: github.publishedAt,
                              htmlURL: github.htmlURL,
                              draft: true,
                              prerelease: false,
                              assets: github.assets)
    check("rejects drafts", UpdateRelease(githubRelease: draft) == nil)

    let prerelease = GitHubRelease(tagName: github.tagName,
                                   name: github.name,
                                   body: github.body,
                                   publishedAt: github.publishedAt,
                                   htmlURL: github.htmlURL,
                                   draft: false,
                                   prerelease: true,
                                   assets: github.assets)
    check("rejects prereleases", UpdateRelease(githubRelease: prerelease) == nil)

    let missingSignature = GitHubRelease(tagName: github.tagName,
                                         name: github.name,
                                         body: github.body,
                                         publishedAt: github.publishedAt,
                                         htmlURL: github.htmlURL,
                                         draft: false,
                                         prerelease: false,
                                         assets: [github.assets[0]])
    check("rejects missing signature", UpdateRelease(githubRelease: missingSignature) == nil)

    let badTag = GitHubRelease(tagName: "release-1.2.0",
                               name: github.name,
                               body: github.body,
                               publishedAt: github.publishedAt,
                               htmlURL: github.htmlURL,
                               draft: false,
                               prerelease: false,
                               assets: github.assets)
    check("rejects non-semver tags", UpdateRelease(githubRelease: badTag) == nil)
}

@Test func testUpdateSignatureAndDigest() throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("update.dmg")
    let data = Data("hello update".utf8)
    try data.write(to: file)

    let key = Curve25519.Signing.PrivateKey()
    let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
    let signature = try key.signature(for: data).base64EncodedString()

    try UpdateSignature.verify(fileURL: file, signatureBase64: signature, publicKeyBase64: publicKey)
    check("sha256 matches CryptoKit",
          UpdateSignature.sha256(data: data)
            == SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())

    var rejected = false
    do {
        try UpdateSignature.verify(fileURL: file,
                                   signatureBase64: Data(repeating: 1, count: 64).base64EncodedString(),
                                   publicKeyBase64: publicKey)
    } catch UpdateError.signatureMismatch {
        rejected = true
    }
    check("tampered signature is rejected", rejected)

    var invalidKey = false
    do {
        try UpdateSignature.verify(fileURL: file, signatureBase64: signature, publicKeyBase64: "not-a-key")
    } catch UpdateError.invalidPublicKey {
        invalidKey = true
    }
    check("invalid public key is rejected", invalidKey)
}

@Test func testUpdateInstallerHelpers() throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let config = makeConfiguration(publicKey: "", downloads: directory, fallback: directory)
    let installer = UpdateInstaller(configuration: config)
    let version = UpdateVersion("1.2.3")!

    check("builds disk image name",
          installer.fileURL(for: version, in: directory).lastPathComponent == "EyeGuardian-1.2.3.dmg")
    check("13.0 satisfies 13.0",
          UpdateInstaller.isSystemVersion(OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0),
                                          atLeast: "13.0"))
    check("13.0 rejects 14.0",
          !UpdateInstaller.isSystemVersion(OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0),
                                           atLeast: "14.0"))
    check("14.2.1 satisfies 14.2",
          UpdateInstaller.isSystemVersion(OperatingSystemVersion(majorVersion: 14, minorVersion: 2, patchVersion: 1),
                                          atLeast: "14.2"))
    check("invalid minimum is rejected",
          !UpdateInstaller.isSystemVersion(OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0),
                                           atLeast: "abc"))
}

@Test func testAutoCheckSettingMigration() {
    func decode(_ json: String) -> AppSettings? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }
    check("auto check defaults on", decode("{}")?.autoCheckUpdates == true)
    check("auto check decodes off", decode("{\"autoCheckUpdates\":false}")?.autoCheckUpdates == false)
    check("auto check round-trips", {
        var settings = AppSettings()
        settings.autoCheckUpdates = false
        guard let data = try? JSONEncoder().encode(settings) else { return false }
        return (try? JSONDecoder().decode(AppSettings.self, from: data))?.autoCheckUpdates == false
    }())
}

@Test @MainActor func testUpdateServiceCheckSkipAndRestore() async throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let (suite, defaults) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let release = makeRelease(version: "1.1.0")
    let config = makeConfiguration(publicKey: "test-key", downloads: directory, fallback: directory)
    let service = UpdateService(configuration: config,
                                installer: UpdateInstaller(configuration: config),
                                api: StubAPI(release: release),
                                downloader: StubDownloader(fileURL: directory.appendingPathComponent("unused.dmg")),
                                defaults: defaults)
    service.start(autoCheckEnabled: false)
    check("starts idle", service.state == .idle)

    service.check(manual: true)
    await service.checkTask?.value
    var isAvailable = false
    if case .available = service.state { isAvailable = true }
    check("manual check finds the update", isAvailable)
    check("records the last check", defaults.object(forKey: "update.lastCheckAt") != nil)

    service.skipCurrentRelease()
    var isSkipped = false
    if case .skipped(let version, _) = service.state {
        isSkipped = version == "1.1.0"
    }
    check("skip marks the version", isSkipped)
    check("skip persists", defaults.string(forKey: "update.skippedVersion") == "1.1.0")

    service.unskip()
    isAvailable = false
    if case .available = service.state { isAvailable = true }
    check("unskip restores availability", isAvailable)

    service.skipCurrentRelease()
    let restored = UpdateService(configuration: config,
                                 installer: UpdateInstaller(configuration: config),
                                 api: StubAPI(release: release),
                                 downloader: StubDownloader(fileURL: directory.appendingPathComponent("unused.dmg")),
                                 defaults: defaults)
    var restoredSkipped = false
    if case .skipped(let version, let release) = restored.state {
        restoredSkipped = version == "1.1.0" && release == nil
    }
    check("restores the skipped version", restoredSkipped)
}

@Test @MainActor func testUpdateServiceDownloadVerificationAndPersistence() async throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let (suite, defaults) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let content = Data("update bytes".utf8)
    let source = directory.appendingPathComponent("source.dmg")
    try content.write(to: source)
    let key = Curve25519.Signing.PrivateKey()
    let signature = try key.signature(for: content).base64EncodedString()
    let digest = "sha256:" + UpdateSignature.sha256(data: content)
    let release = makeRelease(version: "1.1.0", digest: digest, size: content.count)

    let downloads = directory.appendingPathComponent("Downloads", isDirectory: true)
    let fallback = directory.appendingPathComponent("Fallback", isDirectory: true)
    let config = makeConfiguration(publicKey: key.publicKey.rawRepresentation.base64EncodedString(),
                                   downloads: downloads,
                                   fallback: fallback)
    let service = UpdateService(configuration: config,
                                installer: UpdateInstaller(configuration: config),
                                api: StubAPI(release: release, signature: Data(signature.utf8)),
                                downloader: StubDownloader(fileURL: source),
                                defaults: defaults)
    service.check(manual: true)
    await service.checkTask?.value
    service.download()
    await service.downloadTask?.value

    guard case .downloaded(let downloadedRelease, let fileURL) = service.state else {
        check("expected downloaded state", false)
        return
    }
    check("downloads the expected version", downloadedRelease.version == release.version)
    check("moves the file into Downloads",
          fileURL.deletingLastPathComponent().standardizedFileURL == downloads.standardizedFileURL)
    check("keeps the release file name", fileURL.lastPathComponent == "EyeGuardian-1.1.0.dmg")
    check("persists the downloaded update", defaults.data(forKey: "update.downloaded") != nil)
    check("downloads the verified bytes", (try? Data(contentsOf: fileURL)) == content)

    let restored = UpdateService(configuration: config,
                                 installer: UpdateInstaller(configuration: config),
                                 api: StubAPI(release: release),
                                 downloader: StubDownloader(fileURL: source),
                                 defaults: defaults)
    guard case .downloaded(_, let restoredURL) = restored.state else {
        check("restores the downloaded state", false)
        return
    }
    check("restores the same file", restoredURL.standardizedFileURL == fileURL.standardizedFileURL)
}

@Test @MainActor func testUpdateServiceRejectsTamperedSignature() async throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let (suite, defaults) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let content = Data("update bytes".utf8)
    let source = directory.appendingPathComponent("source.dmg")
    try content.write(to: source)
    let key = Curve25519.Signing.PrivateKey()
    let release = makeRelease(version: "1.1.0")

    let downloads = directory.appendingPathComponent("Downloads", isDirectory: true)
    let fallback = directory.appendingPathComponent("Fallback", isDirectory: true)
    let config = makeConfiguration(publicKey: key.publicKey.rawRepresentation.base64EncodedString(),
                                   downloads: downloads,
                                   fallback: fallback)
    let service = UpdateService(configuration: config,
                                installer: UpdateInstaller(configuration: config),
                                api: StubAPI(release: release,
                                             signature: Data(Data(repeating: 1, count: 64).base64EncodedString().utf8)),
                                downloader: StubDownloader(fileURL: source),
                                defaults: defaults)
    service.check(manual: true)
    await service.checkTask?.value
    service.download()
    await service.downloadTask?.value

    var failed = false
    if case .failed(.signatureMismatch, _, _) = service.state { failed = true }
    check("tampered download is rejected", failed)
    check("tampered download is not persisted", defaults.data(forKey: "update.downloaded") == nil)
    check("tampered download is removed from Downloads",
          !FileManager.default.fileExists(atPath: downloads.appendingPathComponent("EyeGuardian-1.1.0.dmg").path))
}

@Test func testUpdateConfigurationDisabledReasons() throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    var config = UpdateConfiguration(enabled: false,
                                     publicKey: "test-key",
                                     currentVersionString: "1.0.0",
                                     downloadsDirectory: directory,
                                     fallbackUpdatesDirectory: directory)
    check("disabled builds are gated",
          config.disabledReason == .build && !config.isSupported)

    config = UpdateConfiguration(enabled: true,
                                 publicKey: "test-key",
                                 currentVersionString: "1.0.0",
                                 isReadOnlyVolume: true,
                                 downloadsDirectory: directory,
                                 fallbackUpdatesDirectory: directory)
    check("read-only volumes are gated", config.disabledReason == .readOnlyVolume)

    config = UpdateConfiguration(enabled: true,
                                 publicKey: "",
                                 currentVersionString: "1.0.0",
                                 downloadsDirectory: directory,
                                 fallbackUpdatesDirectory: directory)
    check("missing public keys are gated", config.disabledReason == .configuration)

    config = UpdateConfiguration(enabled: true,
                                 publicKey: "test-key",
                                 currentVersionString: "1.0.0",
                                 downloadsDirectory: directory,
                                 fallbackUpdatesDirectory: directory)
    check("supported releases are enabled", config.disabledReason == nil && config.isSupported)
}

@Test @MainActor func testUpdateServiceDefersNotificationDuringBreak() async throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let (suite, defaults) = makeDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let release = makeRelease(version: "1.1.0")
    let config = makeConfiguration(publicKey: "test-key", downloads: directory, fallback: directory)
    var breakActive = true
    var notifications: [String] = []
    let service = UpdateService(
        configuration: config,
        installer: UpdateInstaller(configuration: config),
        api: StubAPI(release: release),
        downloader: StubDownloader(fileURL: directory.appendingPathComponent("unused.dmg")),
        defaults: defaults,
        notificationsAllowed: { true },
        isBreakActive: { breakActive },
        notify: { notifications.append($0.version.description) }
    )
    service.start(autoCheckEnabled: true)
    await service.checkTask?.value

    check("finds the update", service.state.release?.version == release.version)
    check("does not notify during a break", notifications.isEmpty)

    breakActive = false
    service.breakDidEnd()
    check("notifies after the break", notifications == ["1.1.0"])
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["UPDATE_SMOKE_DMG"] != nil))
func testUpdateDmgSmoke() async throws {
    let environment = ProcessInfo.processInfo.environment
    let path = try #require(environment["UPDATE_SMOKE_DMG"])
    let versionString = try #require(environment["UPDATE_SMOKE_VERSION"])
    let bundleID = try #require(environment["UPDATE_SMOKE_BUNDLE_ID"])
    let publicKey = try #require(environment["UPDATE_SMOKE_PUBLIC_KEY"])
    let signature = try String(contentsOfFile: path + ".sig", encoding: .utf8)
    let release = makeRelease(version: versionString)
    let config = UpdateConfiguration(
        enabled: true,
        publicKey: publicKey,
        currentVersionString: versionString,
        bundleIdentifier: bundleID,
        downloadsDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
        fallbackUpdatesDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
    )
    let installer = UpdateInstaller(configuration: config)
    try installer.verify(fileURL: URL(fileURLWithPath: path), signature: signature, release: release)
    let mounted = try await Task.detached(priority: .userInitiated) {
        try installer.mountAndValidate(URL(fileURLWithPath: path), release: release)
    }.value
    check("mounts the app bundle", FileManager.default.fileExists(atPath: mounted.appURL.path))
    installer.detach(mounted.mountURL)
}
