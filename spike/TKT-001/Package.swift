// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TKT001Spike",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TKT001Spike",
            path: "Sources/TKT001Spike",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
