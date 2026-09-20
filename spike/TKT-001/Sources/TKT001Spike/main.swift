import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Darwin

// stdout 设为无缓冲，避免重定向到文件时 print 不落盘。
setvbuf(stdout, nil, _IONBF, 0)

// TKT-001 可行性 spike：一次性原型，验证四个风险点。
// 1) 辅助功能权限检测与引导  2) Carbon 全局热键  3) 运行 app 枚举/名称/图标
// 4) NSPanel 非激活覆盖层 + 按键激活 app（activate + AX 兜底）
// 注：此为 Swift 5 语言模式的快速验证代码，正式工程按 Swift 6 并发规范重写。

// MARK: - 全局状态
var hotKeyRef: EventHotKeyRef?
var hotKeyHandlerRef: EventHandlerRef?
var panel: OverlayPanel?
var keyMonitor: Any?
var appList: [(name: String, bundleID: String, pid: pid_t, app: NSRunningApplication)] = []
var previousApp: NSRunningApplication?

let myPid = ProcessInfo.processInfo.processIdentifier

// 无标题栏的 panel 默认不能成为 key window，需子类放开。
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - 1. 权限检测与引导
func reportPermissions() {
    let trusted = AXIsProcessTrusted()
    print("[permission] AXIsProcessTrusted = \(trusted)")
    if !trusted {
        print("[permission] 未授权辅助功能。正在打开「系统设置 → 隐私与安全性 → 辅助功能」，")
        print("[permission] 请把 build/Spike.app 拖入授权列表并勾选，然后重启本进程。")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 2. 运行 app 枚举
func refreshApps() {
    appList = NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular && $0.processIdentifier != myPid }
        .map { ($0.localizedName ?? "?", $0.bundleIdentifier ?? "?", $0.processIdentifier, $0) }
    print("[apps] 运行中的 regular apps 数量 = \(appList.count)")
    for a in appList.prefix(12) {
        print("      \(a.name) | \(a.bundleID) | pid=\(a.pid)")
    }
}

// MARK: - 3. 激活 app（activate + AX 兜底）
func activate(_ app: NSRunningApplication) {
    print("[activate] 目标: \(app.localizedName ?? "?") pid=\(app.processIdentifier)")
    let ok = app.activate(options: [.activateIgnoringOtherApps])
    print("[activate] NSRunningApplication.activate -> \(ok)")

    let ax = AXUIElementCreateApplication(app.processIdentifier)
    let err = AXUIElementPerformAction(ax, kAXRaiseAction as CFString)
    if err == .success {
        print("[activate] AX kAXRaiseAction -> 成功")
    } else {
        print("[activate] AX kAXRaiseAction -> 失败(\(err.rawValue))，通常表示辅助功能未授权")
    }
}

// MARK: - 4. 覆盖层面板（简化键盘形状）
final class KeyboardView: NSView {
    let rows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"],
    ]
    var assignments: [String: String] = [:]

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.12, alpha: 0.92).setFill()
        bounds.fill()
        let keySize = NSSize(width: 44, height: 44)
        let gap: CGFloat = 6
        for (rowIndex, row) in rows.enumerated() {
            let rowWidth = CGFloat(row.count) * (keySize.width + gap) - gap
            var x = (bounds.width - rowWidth) / 2
            let y = bounds.height - CGFloat(rowIndex + 1) * (keySize.height + gap) - 8
            for key in row {
                let rect = NSRect(x: x, y: y, width: keySize.width, height: keySize.height)
                let assigned = assignments[key] != nil
                (assigned ? NSColor.controlAccentColor : NSColor(calibratedWhite: 0.3, alpha: 1)).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
                let keyAttr: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.white]
                NSAttributedString(string: key, attributes: keyAttr).draw(at: NSPoint(x: rect.minX + 6, y: rect.minY + 5))
                if let name = assignments[key] {
                    let truncated = name.count > 6 ? String(name.prefix(6)) + "…" : name
                    let nameAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.white]
                    NSAttributedString(string: truncated, attributes: nameAttr).draw(at: NSPoint(x: rect.minX + 4, y: rect.minY + keySize.height - 14))
                }
                x += keySize.width + gap
            }
        }
    }
}

func makePanel() {
    let p = OverlayPanel(
        contentRect: NSRect(x: 0, y: 0, width: 560, height: 210),
        styleMask: [.borderless],
        backing: .buffered, defer: false
    )
    p.isFloatingPanel = true
    p.level = .floating
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    p.backgroundColor = .clear
    p.isOpaque = false
    p.hasShadow = true
    p.hidesOnDeactivate = false
    let view = KeyboardView(frame: p.contentView!.bounds)
    view.autoresizingMask = [.width, .height]
    p.contentView = view
    panel = p
}

func showPanel() {
    previousApp = NSWorkspace.shared.frontmostApplication
    refreshApps()
    var assign: [String: String] = [:]
    for a in appList {
        guard let first = a.name.first else { continue }
        let k = String(first).uppercased()
        if k.count == 1, k >= "A", k <= "Z", assign[k] == nil { assign[k] = a.name }
    }
    (panel?.contentView as? KeyboardView)?.assignments = assign
    panel?.contentView?.needsDisplay = true
    if let screen = NSScreen.main {
        panel?.setFrameOrigin(NSPoint(x: screen.frame.midX - (panel?.frame.width ?? 0) / 2,
                                      y: screen.frame.midY - 80))
    }
    NSApp.activate(ignoringOtherApps: true)
    panel?.makeKeyAndOrderFront(nil)
    print("[overlay] 面板已显示（本进程成为前台以接收按键），原前台 = \(previousApp?.localizedName ?? "?")")
}

func cancelOverlay() {
    panel?.orderOut(nil)
    if let prev = previousApp {
        prev.activate(options: [.activateIgnoringOtherApps])
    }
    print("[overlay] 已取消，恢复前台 = \(previousApp?.localizedName ?? "?")")
}

func hidePanel() {
    panel?.orderOut(nil)
    print("[overlay] 面板已收起")
}

// MARK: - 热键
func registerHotKey() {
    let target = GetApplicationEventTarget()
    print("[hotkey] event target = \(String(describing: target))")
    let hotKeyID = EventHotKeyID(signature: OSType(0x53574954), id: 1) // "SWIT"
    let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), hotKeyID,
                                     target, 0, &hotKeyRef)
    print("[hotkey] RegisterEventHotKey(⌃⌥+Space) status=\(status)（0=noErr）")

    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let upp: EventHandlerUPP = { _, _, _ in
        print("[hotkey] handler fired")
        DispatchQueue.main.async {
            if let p = panel, p.isVisible { cancelOverlay() } else { showPanel() }
        }
        return noErr
    }
    let installStatus = InstallEventHandler(target, upp, 1, &eventType, nil, &hotKeyHandlerRef)
    print("[hotkey] InstallEventHandler status=\(installStatus)（0=noErr）")
}

// MARK: - 按键处理（面板可见时）
func installKeyMonitor() {
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        guard let p = panel, p.isVisible else { return event }
        if event.keyCode == 53 { // Esc
            cancelOverlay()
            return nil
        }
        if let chars = event.charactersIgnoringModifiers?.uppercased(), let c = chars.first, c >= "A", c <= "Z" {
            if let match = appList.first(where: { $0.name.first.map { String($0).uppercased() } == String(c) }) {
                print("[key] 按键 \(c) -> 匹配 \(match.name)")
                hidePanel()
                activate(match.app)
            } else {
                print("[key] 按键 \(c) -> 无匹配（没有首字母为 \(c) 的 app）")
            }
            return nil
        }
        return event
    }
}

// MARK: - 入口
reportPermissions()
refreshApps()
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
makePanel()
installKeyMonitor()
DispatchQueue.main.async {
    registerHotKey()
}
print("[main] spike 运行中：按 ⌃⌥+Space 唤出/收起覆盖层；覆盖层可见时按字母键激活对应 app，Esc 收起；Ctrl+C 退出。")
app.run()
