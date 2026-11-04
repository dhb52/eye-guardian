// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EyeGuardian",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "EyeGuardian", targets: ["EyeGuardian"]),
    ],
    targets: [
        .target(
            name: "EyeGuardianKit",
            path: "Sources/EyeGuardian",
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "EyeGuardian",
            dependencies: ["EyeGuardianKit"],
            path: "Sources/EyeGuardianApp"
        ),
        .testTarget(
            name: "EyeGuardianKitTests",
            dependencies: ["EyeGuardianKit"],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
