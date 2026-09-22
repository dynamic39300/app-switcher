// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppSwitcher",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AppSwitcherCore", targets: ["AppSwitcherCore"]),
    ],
    targets: [
        .target(name: "AppSwitcherCore"),
        // 无 Xcode 时 XCTest/Swift Testing 不可用，用最小测试运行器（可执行目标）替代，
        // 装 Xcode 后可无缝换成 Swift Testing。
        .executableTarget(name: "CoreTests", dependencies: ["AppSwitcherCore"]),
    ]
)
