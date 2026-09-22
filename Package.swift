// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppSwitcher",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AppSwitcherCore", targets: ["AppSwitcherCore"]),
        .library(name: "AppSwitcherKit", targets: ["AppSwitcherKit"]),
        .executable(name: "AppSwitcherApp", targets: ["AppSwitcherApp"]),
    ],
    targets: [
        .target(name: "AppSwitcherCore"),
        .target(name: "AppSwitcherKit", dependencies: ["AppSwitcherCore"]),
        // 无 Xcode 时 XCTest/Swift Testing 不可用，用最小测试运行器（可执行目标）替代。
        .executableTarget(name: "CoreTests", dependencies: ["AppSwitcherCore", "AppSwitcherKit"]),
        // 主应用（菜单栏 agent + 覆盖层）；Carbon 事件处理器需 Swift 5 语言模式。
        .executableTarget(
            name: "AppSwitcherApp",
            dependencies: ["AppSwitcherCore", "AppSwitcherKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
