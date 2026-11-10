import Foundation

struct UpdateConfiguration {
    let enabled: Bool
    let publicKey: String
    let currentVersionString: String
    let currentBuild: String
    let bundleIdentifier: String
    let repository: String
    let isReadOnlyVolume: Bool
    let osVersion: OperatingSystemVersion
    let downloadsDirectory: URL
    let fallbackUpdatesDirectory: URL
    let apiBaseURL: URL
    let userAgent: String

    init(enabled: Bool,
         publicKey: String,
         currentVersionString: String,
         currentBuild: String = "1",
         bundleIdentifier: String = "com.barry.eyeguardian",
         repository: String = "dhb52/eye-guardian",
         isReadOnlyVolume: Bool = false,
         osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion,
         downloadsDirectory: URL,
         fallbackUpdatesDirectory: URL,
         apiBaseURL: URL = URL(string: "https://api.github.com")!,
         userAgent: String? = nil) {
        self.enabled = enabled
        self.publicKey = publicKey
        self.currentVersionString = currentVersionString
        self.currentBuild = currentBuild
        self.bundleIdentifier = bundleIdentifier
        self.repository = repository
        self.isReadOnlyVolume = isReadOnlyVolume
        self.osVersion = osVersion
        self.downloadsDirectory = downloadsDirectory
        self.fallbackUpdatesDirectory = fallbackUpdatesDirectory
        self.apiBaseURL = apiBaseURL
        self.userAgent = userAgent
            ?? "EyeGuardian/\(currentVersionString) (macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion))"
    }

    var currentVersion: UpdateVersion? { UpdateVersion(currentVersionString) }

    var disabledReason: UpdateDisabledReason? {
        if !enabled { return .build }
        if isReadOnlyVolume { return .readOnlyVolume }
        if publicKey.isEmpty || currentVersion == nil || bundleIdentifier.isEmpty || repository.isEmpty {
            return .configuration
        }
        return nil
    }

    var isSupported: Bool { disabledReason == nil }

    static func live(bundle: Bundle = .main, fileManager: FileManager = .default) -> UpdateConfiguration {
        let info = bundle.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.barry.eyeguardian"
        let repository = info["UpdateRepository"] as? String ?? "dhb52/eye-guardian"
        let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let fallback = applicationSupport
            .appendingPathComponent("EyeGuardian", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
        let environmentURL = ProcessInfo.processInfo.environment["EYEGUARDIAN_UPDATE_API_BASE_URL"]
            .flatMap(URL.init(string:))
        let apiBaseURL = environmentURL ?? URL(string: "https://api.github.com")!

        return UpdateConfiguration(
            enabled: info["UpdateEnabled"] as? Bool ?? false,
            publicKey: info["UpdatePublicKey"] as? String ?? "",
            currentVersionString: version,
            currentBuild: build,
            bundleIdentifier: bundleIdentifier,
            repository: repository,
            isReadOnlyVolume: isReadOnlyVolume(bundle.bundleURL, fileManager: fileManager),
            downloadsDirectory: downloads,
            fallbackUpdatesDirectory: fallback,
            apiBaseURL: apiBaseURL
        )
    }

    static func isReadOnlyVolume(_ url: URL, fileManager: FileManager) -> Bool {
        if url.path.hasPrefix("/Volumes/") { return true }
        if url.path.contains("/AppTranslocation/") { return true }
        let values = try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey])
        return values?.volumeIsReadOnly == true
    }
}
