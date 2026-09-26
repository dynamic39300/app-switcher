import AppKit
import Carbon.HIToolbox
import AppSwitcherCore
import AppSwitcherKit

/// 应用控制器：菜单栏 agent、权限、热键、覆盖层编排。
@MainActor
final class AppController: NSObject {
    private let usage: UsageStore
    private let tracker: UsageTracker
    private let overlay: OverlayController
    private let shortcuts: ShortcutController
    private var statusItem: NSStatusItem?
    private var shortcutMenuItem: NSMenuItem?
    private var settingsWindow: ShortcutSettingsWindow?
    private let commerce = CommerceController()
    private let isIsolatedUITest: Bool

    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.0"

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir: URL
        #if DEBUG
        if let path = Bundle.main.object(forInfoDictionaryKey: "AppSwitcherUITestSupportDirectory") as? String,
           path.hasPrefix("/"), !path.isEmpty {
            dir = URL(fileURLWithPath: path, isDirectory: true)
            isIsolatedUITest = true
        } else {
            dir = support.appendingPathComponent("AppSwitcher", isDirectory: true)
            isIsolatedUITest = false
        }
        #else
        dir = support.appendingPathComponent("AppSwitcher", isDirectory: true)
        isIsolatedUITest = false
        #endif
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let usage = UsageStore(fileURL: dir.appendingPathComponent("usage.json"))
        self.usage = usage
        self.tracker = UsageTracker(store: usage)
        self.overlay = OverlayController(provider: RunningAppsProvider(), usage: usage)
        self.shortcuts = ShortcutController(fileURL: dir.appendingPathComponent("shortcuts.json"))
        super.init()
    }

    func start() {
        AccessibilityGate.logStatus()
        if !isIsolatedUITest { tracker.start() }
        commerce.onShortcutSettings = { [weak self] in self?.showShortcutSettings() }
        commerce.start()
        if commerce.shouldShowAtLaunch { DispatchQueue.main.async { [weak self] in self?.showAccount() } }
        overlay.canBeginSwitch = { [weak self] in self?.commerce.canBeginSwitch() ?? false }

        GlobalHotKey.shared.onTrigger = { [weak self] in
            guard let self, !self.shortcuts.isRecording else { return }
            self.overlay.toggle()
        }
        SequenceHotKey.shared.onTrigger = { [weak self] in
            guard let self, !self.shortcuts.isRecording else { return }
            self.overlay.toggle()
        }
        shortcuts.onChange = { [weak self] in self?.refreshShortcutMenu() }
        overlay.onSettings = { [weak self] in self?.showShortcutSettings() }
        if !isIsolatedUITest { shortcuts.start() }
        setupStatusItem()
        print("[main] AppSwitcher \(Self.version) 启动，组合快捷键注册=\(GlobalHotKey.shared.currentShortcut != nil)")
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "AppSwitcher")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "AppSwitcher \(Self.version)", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let show = NSMenuItem(title: "显示切换器", action: #selector(showSwitcher), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let settings = NSMenuItem(title: "快捷键设置…", action: #selector(showShortcutSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let permission = NSMenuItem(title: "辅助功能设置…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)
        let summary = NSMenuItem(title: shortcuts.menuSummary, action: nil, keyEquivalent: "")
        menu.addItem(summary)
        shortcutMenuItem = summary
        if commerce.isCommercial {
            menu.addItem(.separator())
            for (title, action) in [
                ("账号与授权…", #selector(showAccount)),
                ("同步已购权益", #selector(syncEntitlement)),
                ("检查更新…", #selector(checkForUpdates)),
                ("帮助与反馈…", #selector(showSupport))
            ] {
                let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
                entry.target = self
                menu.addItem(entry)
            }
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 AppSwitcher", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc func showSwitcher() { overlay.toggle() }

    @objc func showAccount() {
        overlay.dismissForSettings()
        commerce.showAccount()
    }
    @objc private func syncEntitlement() { showAccount(); commerce.synchronize() }
    @objc private func checkForUpdates() { overlay.dismissForSettings(); commerce.checkUpdates() }
    @objc private func showSupport() { commerce.openSupport() }

    @objc func showShortcutSettings() {
        overlay.dismissForSettings()
        if let settingsWindow {
            settingsWindow.show()
            return
        }
        let settings = ShortcutSettingsWindow(
            preferences: shortcuts.preferences, status: shortcuts.settingsStatus,
            onBeginRecording: { [weak self] in self?.shortcuts.beginRecording() },
            onEndRecording: { [weak self] in self?.shortcuts.endRecording() },
            onSave: { [weak self] preferences in
                guard let self else { return "设置窗口已失效，请重新打开。" }
                return self.shortcuts.save(preferences)
            },
            onSavedWarning: { [weak self] in self?.shortcuts.availabilityWarning },
            onClose: { [weak self] in
                _ = self?.shortcuts.endRecording()
                self?.settingsWindow = nil
            }
        )
        settingsWindow = settings
        settings.show()
    }

    private func refreshShortcutMenu() {
        shortcutMenuItem?.title = shortcuts.menuSummary
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityGate.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
