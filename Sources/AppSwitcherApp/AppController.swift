import AppKit
import Carbon.HIToolbox
import AppSwitcherCore
import AppSwitcherKit

/// 应用控制器：菜单栏 agent、权限、热键、覆盖层编排。
final class AppController: NSObject {
    private let usage: UsageStore
    private let tracker: UsageTracker
    private let overlay: OverlayController
    private var statusItem: NSStatusItem?

    private static let version = "0.1.0"

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("AppSwitcher", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let usage = UsageStore(fileURL: dir.appendingPathComponent("usage.json"))
        self.usage = usage
        self.tracker = UsageTracker(store: usage)
        self.overlay = OverlayController(provider: RunningAppsProvider(), usage: usage)
        super.init()
    }

    func start() {
        AccessibilityGate.requestIfNeeded()
        setupStatusItem()
        tracker.start()

        GlobalHotKey.shared.onTrigger = { [weak self] in
            self?.overlay.toggle()
        }
        let ok = GlobalHotKey.shared.register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(controlKey | optionKey)
        )
        print("[main] AppSwitcher \(Self.version) 启动，热键 ⌃⌥+Space 注册=\(ok)")
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "AppSwitcher")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "AppSwitcher \(Self.version)", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 AppSwitcher", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
