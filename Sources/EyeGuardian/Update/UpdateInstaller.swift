import AppKit
import Foundation

protocol CommandRunning {
    func run(executable: String, arguments: [String]) throws -> String
}

struct ProcessRunner: CommandRunning {
    func run(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            _ = String(decoding: error, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdateError.commandFailed
        }
        return String(decoding: output, as: UTF8.self)
    }
}

struct UpdateInstaller {
    let configuration: UpdateConfiguration
    private let fileManager: FileManager
    private let runner: CommandRunning

    init(configuration: UpdateConfiguration,
         fileManager: FileManager = .default,
         runner: CommandRunning = ProcessRunner()) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.runner = runner
    }

    func fileURL(for version: UpdateVersion, in directory: URL) -> URL {
        directory.appendingPathComponent("EyeGuardian-\(version).dmg")
    }

    func verify(fileURL: URL, signature: String, release: UpdateRelease) throws {
        if let digest = release.dmg.digest, !digest.isEmpty {
            let expected = digest.lowercased()
                .replacingOccurrences(of: "sha256:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let actual = try UpdateSignature.sha256(fileURL: fileURL)
            guard actual == expected else { throw UpdateError.digestMismatch }
        }
        try UpdateSignature.verify(fileURL: fileURL,
                                   signatureBase64: signature,
                                   publicKeyBase64: configuration.publicKey)
    }

    func moveToInstallLocation(_ tempURL: URL, version: UpdateVersion) throws -> URL {
        let preferred = fileURL(for: version, in: configuration.downloadsDirectory)
        do {
            return try move(tempURL, to: preferred)
        } catch {
            let fallback = fileURL(for: version, in: configuration.fallbackUpdatesDirectory)
            return try move(tempURL, to: fallback)
        }
    }

    private func move(_ source: URL, to destination: URL) throws -> URL {
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: source, to: destination)
        return destination
    }

    func removeDownloadedFile(_ url: URL, version: UpdateVersion) {
        let expected = [
            fileURL(for: version, in: configuration.downloadsDirectory).standardizedFileURL,
            fileURL(for: version, in: configuration.fallbackUpdatesDirectory).standardizedFileURL,
        ]
        guard expected.contains(url.standardizedFileURL) else { return }
        try? fileManager.removeItem(at: url)
    }

    func mountAndValidate(_ dmgURL: URL, release: UpdateRelease) throws -> MountedUpdate {
        _ = try? runner.run(executable: "/usr/bin/xattr",
                            arguments: ["-dr", "com.apple.quarantine", dmgURL.path])

        let output: String
        do {
            output = try runner.run(executable: "/usr/bin/hdiutil",
                                    arguments: ["attach", "-nobrowse", "-readonly", "-plist", dmgURL.path])
        } catch {
            throw UpdateError.mountFailed
        }
        guard let mountURL = Self.mountPoint(from: output) else {
            throw UpdateError.mountFailed
        }

        do {
            let appURL = try appBundle(in: mountURL)
            let info = try infoPlist(at: appURL)
            guard (info["CFBundleIdentifier"] as? String) == configuration.bundleIdentifier else {
                throw UpdateError.invalidBundle
            }
            guard (info["CFBundleShortVersionString"] as? String) == release.version.description else {
                throw UpdateError.invalidBundle
            }
            let minimum = (info["LSMinimumSystemVersion"] as? String) ?? "13.0"
            guard Self.isSystemVersion(configuration.osVersion, atLeast: minimum) else {
                throw UpdateError.incompatibleSystem(minimum)
            }
            do {
                _ = try runner.run(executable: "/usr/bin/codesign",
                                   arguments: ["--verify", "--strict", appURL.path])
            } catch {
                throw UpdateError.invalidBundle
            }
            return MountedUpdate(mountURL: mountURL, appURL: appURL)
        } catch {
            _ = try? runner.run(executable: "/usr/bin/hdiutil",
                                arguments: ["detach", mountURL.path])
            throw error
        }
    }

    func open(_ mountURL: URL) -> Bool {
        NSWorkspace.shared.open(mountURL)
    }

    func detach(_ mountURL: URL) {
        _ = try? runner.run(executable: "/usr/bin/hdiutil",
                            arguments: ["detach", mountURL.path])
    }

    static func mountPoint(from plistOutput: String) -> URL? {
        guard let data = plistOutput.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let entities = dictionary["system-entities"] as? [[String: Any]] else {
            return nil
        }
        return entities
            .compactMap { $0["mount-point"] as? String }
            .first
            .map(URL.init(fileURLWithPath:))
    }

    static func isSystemVersion(_ current: OperatingSystemVersion, atLeast required: String) -> Bool {
        let parts = required
            .split(separator: ".")
            .compactMap { Int($0) }
        guard !parts.isEmpty else { return false }
        let major = parts[0]
        let minor = parts.count > 1 ? parts[1] : 0
        let patch = parts.count > 2 ? parts[2] : 0
        if current.majorVersion != major { return current.majorVersion > major }
        if current.minorVersion != minor { return current.minorVersion > minor }
        return current.patchVersion >= patch
    }

    private func appBundle(in mountURL: URL) throws -> URL {
        let contents = try fileManager.contentsOfDirectory(at: mountURL,
                                                          includingPropertiesForKeys: nil)
        guard let app = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.invalidBundle
        }
        return app
    }

    private func infoPlist(at appURL: URL) throws -> [String: Any] {
        let url = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any] else {
            throw UpdateError.invalidBundle
        }
        return dictionary
    }
}
