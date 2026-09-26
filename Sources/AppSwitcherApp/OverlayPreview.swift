import AppKit
import SwiftUI
import AppSwitcherCore

/// 离屏验收样本：候选与标题均为合成数据，不枚举或截取用户窗口。
@MainActor
enum OverlayPreview {
    private struct ExampleApp {
        let key: String
        let name: String
        let iconPath: String?
        let symbol: String
        let color: NSColor
        let count: Int
        var groupID: String { "preview.\(key)" }
    }

    private static let examples: [ExampleApp] = [
        .init(key: "Q", name: "ClassIn", iconPath: nil, symbol: "video.fill", color: .systemBlue, count: 6),
        .init(key: "W", name: "微信", iconPath: nil, symbol: "bubble.left.and.bubble.right.fill", color: .systemGreen, count: 2),
        .init(key: "E", name: "Mail", iconPath: "/System/Applications/Mail.app", symbol: "envelope.fill", color: .systemBlue, count: 1),
        .init(key: "T", name: "Terminal", iconPath: "/System/Applications/Utilities/Terminal.app", symbol: "terminal.fill", color: .darkGray, count: 2),
        .init(key: "P", name: "Photos", iconPath: "/System/Applications/Photos.app", symbol: "photo.fill", color: .systemPink, count: 1),
        .init(key: "A", name: "Calendar", iconPath: "/System/Applications/Calendar.app", symbol: "calendar", color: .systemRed, count: 1),
        .init(key: "S", name: "Safari", iconPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app", symbol: "safari.fill", color: .systemBlue, count: 3),
        .init(key: "D", name: "提醒事项", iconPath: "/System/Applications/Reminders.app", symbol: "checklist", color: .systemOrange, count: 1),
        .init(key: "F", name: "Finder", iconPath: "/System/Library/CoreServices/Finder.app", symbol: "folder.fill", color: .systemBlue, count: 2),
        .init(key: "C", name: "Visual Studio Code", iconPath: nil, symbol: "chevron.left.forwardslash.chevron.right", color: .systemBlue, count: 2),
        .init(key: "N", name: "Notes", iconPath: "/System/Applications/Notes.app", symbol: "note.text", color: .systemYellow, count: 2),
        .init(key: "M", name: "Music", iconPath: "/System/Applications/Music.app", symbol: "music.note", color: .systemPink, count: 1),
    ]

    static func render(to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let icons = Dictionary(uniqueKeysWithValues: examples.map { ($0.groupID, icon(for: $0)) })
        let applications = applicationMap()
        let windows = windowMap()
        var urls: [URL] = []
        urls.append(try save("01-applications", directory: directory, keyMap: applications, icons: icons,
                             mode: .applications, selectedKey: Key("S", letter: true)))
        urls.append(try save("02-windows", directory: directory, keyMap: windows, icons: icons,
                             mode: .windows, selectedKey: Key("S", letter: true)))
        urls.append(try save("03-empty", directory: directory, keyMap: [:], icons: [:], mode: .applications))
        urls.append(try save("04-failure", directory: directory, keyMap: applications, icons: icons, mode: .applications,
                             selectedKey: Key("S", letter: true), message: "未能确认目标窗口已获得焦点，请重新选择应用后重试。"))
        urls.append(try save("05-narrow", directory: directory, keyMap: windows, icons: icons,
                             mode: .windows, selectedKey: Key("S", letter: true), width: 760))
        urls.append(try save("06-overflow", directory: directory, keyMap: overflowMap(), icons: icons,
                             mode: .applications, selectedKey: Key("1", letter: false)))
        urls.append(try save("07-loading", directory: directory, keyMap: [:], icons: [:], mode: .windows, isLoading: true))
        urls.append(try save("08-overflow-narrow", directory: directory, keyMap: overflowMap(), icons: icons,
                             mode: .applications, selectedKey: Key("1", letter: false), width: 760))
        urls.append(try save("09-short-screen", directory: directory, keyMap: overflowMap(), icons: icons,
                             mode: .applications, selectedKey: Key("1", letter: false), height: 520))
        urls.append(try save("10-laptop", directory: directory, keyMap: applications, icons: icons,
                             mode: .applications, selectedKey: Key("S", letter: true), screenSize: CGSize(width: 1280, height: 720)))
        urls.append(try save("11-large-screen", directory: directory, keyMap: windows, icons: icons,
                             mode: .windows, selectedKey: Key("S", letter: true), screenSize: CGSize(width: 1920, height: 1040)))
        urls.append(try save("12-ultrawide", directory: directory, keyMap: overflowMap(), icons: icons,
                             mode: .applications, selectedKey: Key("1", letter: false), screenSize: CGSize(width: 2560, height: 1080)))
        let crowdedWindows = overflowMap().mapValues { candidate in
            Candidate(id: candidate.id, groupID: candidate.groupID, displayName: candidate.displayName,
                      title: "设计评审与窗口切换方案", target: .window(pid: candidate.target.pid, token: candidate.id))
        }
        urls.append(try save("13-windows-narrow-short", directory: directory, keyMap: crowdedWindows, icons: icons,
                             mode: .windows, selectedKey: Key("1", letter: false), width: 760, height: 430))
        urls.append(try save("14-windows-medium-short", directory: directory, keyMap: crowdedWindows, icons: icons,
                             mode: .windows, selectedKey: Key("1", letter: false), width: 1040, height: 520))
        urls.append(try save("15-applications-large", directory: directory, keyMap: applications, icons: icons,
                             mode: .applications, selectedKey: Key("S", letter: true), screenSize: CGSize(width: 2560, height: 1440)))
        urls.append(try save("16-missing-icons", directory: directory, keyMap: applications, icons: [:],
                             mode: .applications, selectedKey: Key("S", letter: true)))
        return urls
    }

    private static func applicationMap() -> [Key: Candidate] {
        Dictionary(uniqueKeysWithValues: examples.enumerated().map { index, app in
            (Key(app.key, letter: true), Candidate(id: app.groupID, groupID: app.groupID, displayName: app.name,
                                                target: .application(pid: index + 100), windowCount: 0))
        })
    }

    private static func windowMap() -> [Key: Candidate] {
        var result = applicationMap()
        let safari = examples.first { $0.key == "S" }!
        let titles = ["AppSwitcher — 设计评审与窗口切换方案", "WWDC — Apple Developer", "API 文档与集成说明"]
        for (index, key) in ["S", "D", "G"].enumerated() {
            result[Key(key, letter: true)] = Candidate(id: "preview.safari.\(index)", groupID: safari.groupID,
                displayName: "Safari", title: titles[index], target: .window(pid: 106, token: "preview.safari.\(index)"), windowCount: 3)
        }
        let notes = examples.first { $0.key == "N" }!
        result[Key("N", letter: true)] = Candidate(id: "preview.notes.1", groupID: notes.groupID,
            displayName: "Notes", title: "产品迭代计划 · 2026 秋季", target: .window(pid: 110, token: "preview.notes.1"), windowCount: 2)
        result[Key("B", letter: true)] = Candidate(id: "preview.notes.2", groupID: notes.groupID,
            displayName: "Notes", title: "周会记录", target: .window(pid: 110, token: "preview.notes.2"), windowCount: 2)
        return result
    }

    private static func overflowMap() -> [Key: Candidate] {
        Dictionary(uniqueKeysWithValues: Key.all.enumerated().map { index, key in
            let app = examples[index % examples.count]
            return (key, Candidate(id: "preview.overflow.\(index)", groupID: app.groupID,
                                   displayName: index < examples.count ? app.name : "示例应用 \(index + 1)",
                                   target: .application(pid: index + 200), windowCount: 0))
        })
    }

    private static func icon(for example: ExampleApp) -> NSImage {
        if let path = example.iconPath, FileManager.default.fileExists(atPath: path) {
            return AppIconImage.prepared(NSWorkspace.shared.icon(forFile: path))
        }
        return NSImage(size: NSSize(width: 64, height: 64), flipped: false) { bounds in
            example.color.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 14, yRadius: 14).fill()
            if let symbol = NSImage(systemSymbolName: example.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 28, weight: .medium)) {
                let tinted = NSImage(size: symbol.size, flipped: false) { _ in
                    symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
                    NSColor.white.setFill()
                    NSRect(origin: .zero, size: symbol.size).fill(using: .sourceIn)
                    return true
                }
                let ratio = min(32 / tinted.size.width, 32 / tinted.size.height)
                let size = NSSize(width: tinted.size.width * ratio, height: tinted.size.height * ratio)
                tinted.draw(in: NSRect(x: (64 - size.width) / 2, y: (64 - size.height) / 2, width: size.width, height: size.height))
            }
            return true
        }
    }

    private static func save(_ name: String, directory: URL, keyMap: [Key: Candidate], icons: [String: NSImage],
                             mode: OverlayMode, selectedKey: Key? = nil, message: String? = nil,
                             width: CGFloat? = nil, isLoading: Bool = false, height: CGFloat? = nil,
                             screenSize: CGSize = CGSize(width: 1440, height: 860)) throws -> URL {
        let preferred = OverlayView.preferredSize(in: screenSize)
        let size = CGSize(width: width ?? preferred.width, height: height ?? preferred.height)
        let view = OverlayView(keyMap: keyMap, icons: icons, mode: mode, selectedKey: selectedKey,
                               isLoading: isLoading, message: message, onSelect: { _ in }, onActivate: { _ in },
                               onToggleMode: {}, onCancel: {}, onSettings: {})
            .frame(width: size.width, height: size.height)
        let png: Data
        let minimumHeight: CGFloat = keyMap.keys.contains { !$0.isLetter } ? 604 : 492
        if size.height < minimumHeight || isLoading {
            // ImageRenderer omits native ScrollView and ProgressView content; render only this synthetic
            // hosting view into a bitmap. This window is never ordered onto the user's screen.
            png = try renderHosted(view, size: size, name: name)
        } else {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let cgImage = renderer.cgImage,
                  let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
                throw renderingError(name)
            }
            png = data
        }
        let url = directory.appendingPathComponent(name).appendingPathExtension("png")
        try png.write(to: url, options: .atomic)
        return url
    }

    private static func renderHosted<Content: View>(_ content: Content, size: CGSize, name: String) throws -> Data {
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        defer {
            window.contentView = nil
            window.close()
        }
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw renderingError(name)
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw renderingError(name)
        }
        return data
    }

    private static func renderingError(_ name: String) -> NSError {
        NSError(domain: "OverlayPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法渲染 \(name)"])
    }

}
