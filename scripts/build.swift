import Foundation

enum BuildError: Error, CustomStringConvertible {
    case message(String)
    case failed(executable: String, arguments: [String], status: Int32)

    var description: String {
        switch self {
        case let .message(text):
            return text
        case let .failed(executable, arguments, status):
            return "command failed (\(status)): \(executable) \(arguments.joined(separator: " "))"
        }
    }
}

let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
var root = URL(fileURLWithPath: #filePath, relativeTo: currentDirectory)
    .standardizedFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
if !FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
    root = currentDirectory
}

let out = root.appendingPathComponent("build")
let app = out.appendingPathComponent("Eye Guardian.app")
let deployTarget = "13.0"
let triples = ["arm64", "x86_64"].map { "\($0)-apple-macos\(deployTarget)" }

let signingIdentity = "EyeGuardian Local Signing"
let signingPassword = "eyeguardian-local"
let signingKeychain = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Keychains/EyeGuardian.keychain-db")
let loginKeychain = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Keychains/login.keychain-db")

func path(_ components: String...) -> URL {
    components.reduce(root) { $0.appendingPathComponent($1) }
}

func warn(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

@discardableResult
func run(_ executable: String, _ arguments: [String], captureOutput: Bool = false, silent: Bool = false) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [executable] + arguments
    process.currentDirectoryURL = root
    let pipe = Pipe()
    if captureOutput {
        process.standardOutput = pipe
    } else if silent {
        process.standardOutput = FileHandle.nullDevice
    }
    if silent {
        process.standardError = FileHandle.nullDevice
    }
    try process.run()
    var data = Data()
    if captureOutput {
        data = pipe.fileHandleForReading.readDataToEndOfFile()
    }
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw BuildError.failed(executable: executable, arguments: arguments, status: process.terminationStatus)
    }
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

func lastLine(of text: String) -> String {
    text.split(separator: "\n").last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? text
}

func modificationDate(_ url: URL) -> Date? {
    (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
}

func isStale(_ output: URL, inputs: [URL]) -> Bool {
    guard let outputDate = modificationDate(output) else { return true }
    return inputs.contains { input in
        guard let inputDate = modificationDate(input) else { return true }
        return inputDate > outputDate
    }
}

func generateIcons() throws {
    let fileManager = FileManager.default
    let icns = out.appendingPathComponent("AppIcon.icns")
    let inputs = [
        path("Sources/EyeGuardian/Core/Models.swift"),
        path("Sources/EyeGuardian/Platform/IconArtwork.swift"),
        path("scripts/gen-icon.swift"),
    ]

    if !isStale(icns, inputs: inputs) {
        print("icons up to date: \(icns.path)")
        return
    }

    let tools = out.appendingPathComponent("tools")
    try fileManager.createDirectory(at: tools, withIntermediateDirectories: true)
    let generator = tools.appendingPathComponent("gen-icon")
    try run("swiftc", ["-O", "-parse-as-library"] + inputs.map(\.path) + ["-o", generator.path])

    let iconset = out.appendingPathComponent("AppIcon.iconset")
    try? fileManager.removeItem(at: iconset)
    try run(generator.path, [iconset.path, out.appendingPathComponent("icon-1024.png").path])
    try run("iconutil", ["-c", "icns", iconset.path, "-o", icns.path])
    print("wrote \(icns.path)")
}

/// Returns true only when the keychain holds a usable code-signing identity; `security find-certificate`
/// exits 0 even for a missing keychain, so read `find-identity` output instead.
func hasSigningIdentity(in keychain: String) -> Bool {
    guard FileManager.default.fileExists(atPath: keychain) else { return false }
    guard (try? run("security", ["unlock-keychain", "-p", signingPassword, keychain], silent: true)) != nil else {
        return false
    }
    guard let identities = try? run("security", ["find-identity", "-v", "-p", "codesigning", keychain],
                                    captureOutput: true, silent: true) else {
        return false
    }
    return identities.contains("\"\(signingIdentity)\"")
}

func userSearchList() -> [String] {
    guard let output = try? run("security", ["list-keychains", "-d", "user"], captureOutput: true, silent: true) else {
        return []
    }
    return output
        .split(separator: "\n")
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"")) }
        .filter { !$0.isEmpty }
}

/// codesign ignores `--keychain` when resolving an identity, so the keychain has to be in the search list
/// while signing. Restore the previous list afterwards.
@discardableResult
func withSigningKeychain<Result>(_ keychain: String, _ body: () throws -> Result) rethrows -> Result {
    let previous = userSearchList()
    if !previous.isEmpty, !previous.contains(keychain) {
        _ = try? run("security", ["list-keychains", "-d", "user", "-s"] + previous + [keychain], silent: true)
        defer {
            _ = try? run("security", ["list-keychains", "-d", "user", "-s"] + previous, silent: true)
        }
        return try body()
    }
    return try body()
}

/// Returns the identity name when a usable local signing keychain is present or can be created.
func localSigningIdentity() -> String? {
    let fileManager = FileManager.default
    let keychain = signingKeychain.path

    if hasSigningIdentity(in: keychain) {
        return signingIdentity
    }

    let tmp = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    guard (try? fileManager.createDirectory(at: tmp, withIntermediateDirectories: true)) != nil else {
        return nil
    }
    defer { try? fileManager.removeItem(at: tmp) }

    let key = tmp.appendingPathComponent("key.pem").path
    let cert = tmp.appendingPathComponent("cert.pem").path
    let bundle = tmp.appendingPathComponent("identity.p12").path

    do {
        try run("openssl", [
            "req", "-x509", "-newkey", "rsa:2048", "-keyout", key, "-out", cert,
            "-days", "3650", "-nodes", "-subj", "/CN=\(signingIdentity)",
            "-addext", "keyUsage=critical,digitalSignature",
            "-addext", "extendedKeyUsage=critical,codeSigning",
        ], silent: true)
        let legacy = try? run("openssl", [
            "pkcs12", "-export", "-legacy", "-out", bundle, "-inkey", key,
            "-in", cert, "-passout", "pass:\(signingPassword)",
        ], silent: true)
        if legacy == nil {
            try run("openssl", [
                "pkcs12", "-export", "-out", bundle, "-inkey", key,
                "-in", cert, "-passout", "pass:\(signingPassword)",
            ], silent: true)
        }

        _ = try? run("security", ["delete-keychain", keychain], silent: true)
        try run("security", ["create-keychain", "-p", signingPassword, keychain], silent: true)
        try run("security", ["set-keychain-settings", "-lut", "21600", keychain], silent: true)
        try run("security", ["unlock-keychain", "-p", signingPassword, keychain], silent: true)
        try run("security", [
            "import", bundle, "-k", keychain, "-P", signingPassword, "-T", "/usr/bin/codesign",
        ], silent: true)
        _ = try? run("security", [
            "set-key-partition-list", "-S", "apple-tool:,apple:", "-s", "-k", signingPassword, keychain,
        ], silent: true)
        // A self-signed certificate stays untrusted until it is marked trusted for code signing.
        if (try? run("security", [
            "add-trusted-cert", "-r", "trustRoot", "-p", "codeSign", "-k", loginKeychain.path, cert,
        ], silent: true)) == nil {
            warn("warning: could not trust the local signing certificate")
        }
        guard hasSigningIdentity(in: keychain) else {
            warn("warning: imported signing identity is not usable")
            return nil
        }
        return signingIdentity
    } catch {
        warn("warning: local signing identity setup failed: \(error)")
        return nil
    }
}

func buildApp() throws {
    let fileManager = FileManager.default
    let identity: String
    if let override = ProcessInfo.processInfo.environment["CODESIGN_ID"], !override.isEmpty {
        identity = override
    } else if let local = localSigningIdentity() {
        identity = local
    } else {
        warn("warning: could not create a local signing identity; falling back to ad-hoc")
        identity = "-"
    }

    try fileManager.createDirectory(at: out, withIntermediateDirectories: true)
    try generateIcons()

    // SwiftPM's link step records the deployment target as the linked SDK, which makes macOS render the
    // legacy appearance; pass the real SDK version so the binary matches a plain `swiftc` build.
    let sdkVersion = try run("xcrun", ["--show-sdk-version"], captureOutput: true)
    let platform = ["-Xlinker", "-platform_version", "-Xlinker", "macos",
                    "-Xlinker", deployTarget, "-Xlinker", sdkVersion]

    var slices: [URL] = []
    for triple in triples {
        let arch = String(triple.prefix { $0 != "-" })
        let scratch = out.appendingPathComponent("spm/\(arch)")
        let base = ["build", "-c", "release", "--scratch-path", scratch.path, "--triple", triple] + platform
        try run("swift", base)
        let binDir = lastLine(of: try run("swift", base + ["--show-bin-path"], captureOutput: true))
        let slice = out.appendingPathComponent("EyeGuardian-\(arch)")
        try? fileManager.removeItem(at: slice)
        try fileManager.copyItem(at: URL(fileURLWithPath: binDir).appendingPathComponent("EyeGuardian"), to: slice)
        slices.append(slice)
    }

    let binary = out.appendingPathComponent("EyeGuardian")
    try? fileManager.removeItem(at: binary)
    try run("lipo", ["-create"] + slices.map(\.path) + ["-output", binary.path])
    let archs = try run("lipo", ["-archs", binary.path], captureOutput: true)
        .split(whereSeparator: { $0.isWhitespace })
        .map(String.init)
    guard archs.contains("arm64"), archs.contains("x86_64") else {
        throw BuildError.message("unexpected architectures: \(archs.joined(separator: " "))")
    }

    try? fileManager.removeItem(at: app)
    let contents = app.appendingPathComponent("Contents")
    let macos = contents.appendingPathComponent("MacOS")
    let resources = contents.appendingPathComponent("Resources")
    try fileManager.createDirectory(at: macos, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
    try fileManager.copyItem(at: binary, to: macos.appendingPathComponent("EyeGuardian"))
    try fileManager.copyItem(at: path("Info.plist"), to: contents.appendingPathComponent("Info.plist"))
    for localization in ["en.lproj", "zh-Hans.lproj"] {
        try fileManager.copyItem(
            at: path("Sources/EyeGuardian/Resources/\(localization)"),
            to: resources.appendingPathComponent(localization)
        )
    }
    try fileManager.copyItem(
        at: out.appendingPathComponent("AppIcon.icns"),
        to: resources.appendingPathComponent("AppIcon.icns")
    )

    try run("xattr", ["-cr", app.path])
    do {
        try withSigningKeychain(signingKeychain.path) {
            try run("codesign", ["--force", "--keychain", signingKeychain.path, "--sign", identity, app.path])
        }
    } catch {
        guard identity != "-" else { throw error }
        warn("warning: signing with '\(identity)' failed; falling back to ad-hoc")
        try run("codesign", ["--force", "--sign", "-", app.path])
    }
    print("Built \(app.path)")
}

func buildDiskImage() throws {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: app.path) else {
        throw BuildError.message("missing \(app.path); run 'make' first")
    }

    let version = try run("/usr/libexec/PlistBuddy", [
        "-c", "Print :CFBundleShortVersionString",
        app.appendingPathComponent("Contents/Info.plist").path,
    ], captureOutput: true)
    let dmg = out.appendingPathComponent("Eye Guardian \(version).dmg")
    let stage = out.appendingPathComponent("dmg-stage")

    try? fileManager.removeItem(at: stage)
    try fileManager.createDirectory(at: stage, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: stage) }

    try run("ditto", [app.path, stage.appendingPathComponent("Eye Guardian.app").path])
    try fileManager.createSymbolicLink(
        atPath: stage.appendingPathComponent("Applications").path,
        withDestinationPath: "/Applications"
    )

    try? fileManager.removeItem(at: dmg)
    try run("hdiutil", [
        "create", "-volname", "Eye Guardian", "-srcfolder", stage.path,
        "-fs", "HFS+", "-format", "UDZO", "-ov", dmg.path,
    ])
    print("Built \(dmg.path)")
}

func usage() -> Never {
    warn("usage: swift scripts/build.swift <icons|build|dmg>")
    exit(64)
}

do {
    switch CommandLine.arguments.dropFirst().first {
    case "icons": try generateIcons()
    case "build": try buildApp()
    case "dmg": try buildDiskImage()
    default: usage()
    }
} catch {
    warn("error: \(error)")
    exit(1)
}
