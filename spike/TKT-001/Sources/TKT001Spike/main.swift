import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Darwin

// stdout 设为无缓冲，避免重定向到文件时 print 不落盘。
setvbuf(stdout, nil, _IONBF, 0)

// TKT-001 可行性 spike：一次性原型，验证关键风险点。
// 覆盖：权限/全局热键/窗口过滤/多窗口平铺+副标题/激活（含最小化还原）。
// 注：Swift 5 语言模式的快速验证代码，正式工程按 Swift 6 并发规范重写。

// MARK: - 数据模型
struct SwitchItem {
    let app: NSRunningApplication
    let name: String        // app 显示名
    let title: String       // 窗口标题（副标题），单窗口/无标题为空
    let windowNumber: Int   // kCGWindowNumber，标识具体窗口
}

let keyOrder: [String] = [
    "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
    "A", "S", "D", "F", "G", "H", "J", "K", "L",
    "Z", "X", "C", "V", "B", "N", "M",
]

// MARK: - 全局状态
var hotKeyRef: EventHotKeyRef?
var hotKeyHandlerRef: EventHandlerRef?
var panel: OverlayPanel?
var keyMonitor: Any?
var itemList: [SwitchItem] = []   // 展开后的候选（同一 app 多窗口会展开成多条）
var keyMap: [String: SwitchItem] = [:] // 键位 -> 条目
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

    let screen = CGPreflightScreenCaptureAccess()
    print("[permission] 屏幕录制权限 = \(screen)")
    if !screen {
        print("[permission] 正在请求屏幕录制权限（仅用于读取窗口标题，不录像）...")
        _ = CGRequestScreenCaptureAccess()
    }
}

// MARK: - 2. 窗口过滤（CGWindowList，零额外权限）
func isContentWindow(_ info: [String: Any]) -> Bool {
    guard let layerNum = info[kCGWindowLayer as String] as? NSNumber, layerNum.intValue == 0 else { return false }
    guard let alphaNum = info[kCGWindowAlpha as String] as? NSNumber, alphaNum.doubleValue > 0.05 else { return false }
    guard let b = info[kCGWindowBounds as String] as? [String: Any],
          let w = (b["Width"] as? NSNumber)?.doubleValue,
          let h = (b["Height"] as? NSNumber)?.doubleValue else { return false }
    if w < 100 || h < 100 { return false }
    if h <= 40 { return false }
    if w == 500 && h == 500 { return false }
    return true
}

// 内容窗口枚举：CGWindowList（窗口归属/尺寸）+ kCGWindowName 读标题（需屏幕录制）
func contentWindows() -> [(pid: pid_t, title: String, windowNumber: Int)] {
    guard let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else { return [] }
    var result: [(pid_t, String, Int)] = []
    for info in list where isContentWindow(info) {
        guard let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
              let num = (info[kCGWindowNumber as String] as? NSNumber)?.intValue else { continue }
        let title = info[kCGWindowName as String] as? String ?? ""
        result.append((pid, title, num))
    }
    return result
}

// MARK: - 4. 候选枚举 + 键位分配
func refreshApps() {
    let wins = contentWindows()
    let apps = NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular && $0.processIdentifier != myPid }
    let sorted = apps.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

    var items: [SwitchItem] = []
    for app in sorted {
        let name = app.localizedName ?? "?"
        let pid = app.processIdentifier
        let appWins = wins.filter { $0.pid == pid }
        for (i, w) in appWins.enumerated() {
            let title: String
            if !w.title.isEmpty {
                title = w.title
            } else if appWins.count > 1 {
                title = "窗口 \(i + 1)"   // 无屏幕录制时用序号兜底，便于区分
            } else {
                title = ""
            }
            items.append(SwitchItem(app: app, name: name, title: title, windowNumber: w.windowNumber))
        }
    }
    itemList = items
    assignKeys()

    print("[apps] 候选 app=\(sorted.count)，展开窗口条目=\(itemList.count)")
    for k in keyOrder where keyMap[k] != nil {
        let item = keyMap[k]!
        let sub = item.title.isEmpty ? "" : " | \(item.title)"
        print("      \(k) -> \(item.name)\(sub)")
    }
}

func assignKeys() {
    keyMap = [:]
    var used = Set<String>()
    var prevKeyByApp: [pid_t: String] = [:]

    for item in itemList {
        let pid = item.app.processIdentifier
        let first = item.name.first.map { String($0).uppercased() } ?? ""
        var key: String?

        if prevKeyByApp[pid] == nil {
            // 该 app 第一个窗口：首字母优先，冲突则取最近空闲键
            if first.count == 1, first >= "A", first <= "Z", !used.contains(first) {
                key = first
            } else {
                key = keyOrder.first { !used.contains($0) }
            }
        } else {
            // 同一 app 的后续窗口：上一个键之后的下一个空闲键（相邻平铺）
            if let prev = prevKeyByApp[pid], let idx = keyOrder.firstIndex(of: prev) {
                for k in keyOrder.dropFirst(idx + 1) {
                    if !used.contains(k) { key = k; break }
                }
            }
            if key == nil { key = keyOrder.first { !used.contains($0) } }
        }

        if let k = key {
            used.insert(k)
            prevKeyByApp[pid] = k
            keyMap[k] = item
        }
    }
}

// MARK: - 5. 激活（app 前置 + 最小化还原 + 指定窗口抬起）
func activate(_ item: SwitchItem) {
    let app = item.app
    let sub = item.title.isEmpty ? "" : " | \(item.title)"
    print("[activate] 目标: \(item.name)\(sub) pid=\(app.processIdentifier)")
    let ok = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
    print("[activate] NSRunningApplication.activate -> \(ok)")

    let ax = AXUIElementCreateApplication(app.processIdentifier)
    let frontErr = AXUIElementSetAttributeValue(ax, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    print("[activate] AX setFrontmost -> \(frontErr == .success ? "成功" : "失败(\(frontErr.rawValue))")")

    var minimized: CFTypeRef?
    if AXUIElementCopyAttributeValue(ax, "AXMinimizedWindows" as CFString, &minimized) == .success,
       let mins = minimized as? [AXUIElement], !mins.isEmpty {
        for w in mins {
            AXUIElementSetAttributeValue(w, "AXMinimized" as CFString, kCFBooleanFalse)
        }
        print("[activate] AX 还原 \(mins.count) 个最小化窗口")
    }

    // 尝试按标题抬起具体窗口（AX 可读的 app 有效；Chromium 系 AX 返回 0 窗口，仅激活前台）
    if !item.title.isEmpty {
        var windows: CFTypeRef?
        if AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &windows) == .success,
           let list = windows as? [AXUIElement] {
            for w in list {
                var t: CFTypeRef?
                if AXUIElementCopyAttributeValue(w, "AXTitle" as CFString, &t) == .success,
                   let s = t as? String, s == item.title {
                    AXUIElementPerformAction(w, kAXRaiseAction as CFString)
                    AXUIElementSetAttributeValue(w, "AXMain" as CFString, kCFBooleanTrue)
                    print("[activate] 抬起指定窗口「\(item.title)」")
                    break
                }
            }
        }
    } else {
        var windows: CFTypeRef?
        if AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &windows) == .success,
           let list = windows as? [AXUIElement] {
            for w in list {
                AXUIElementPerformAction(w, kAXRaiseAction as CFString)
            }
            print("[activate] AX 抬起 \(list.count) 个窗口")
        }
    }
}

// MARK: - 6. 覆盖层面板（键盘形状）
final class KeyboardView: NSView {
    let rows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"],
    ]
    var keyMap: [String: SwitchItem] = [:]

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.12, alpha: 0.94).setFill()
        bounds.fill()

        let gap: CGFloat = 10
        let keyW = (bounds.width - 9 * gap) / 10.0
        let keyH = (bounds.height - CGFloat(rows.count - 1) * gap - 12) / CGFloat(rows.count)
        let keySize = min(keyW, keyH)

        for (rowIndex, row) in rows.enumerated() {
            let rowWidth = CGFloat(row.count) * (keySize + gap) - gap
            var x = (bounds.width - rowWidth) / 2
            let y = bounds.height - CGFloat(rowIndex + 1) * (keySize + gap) - 4
            for key in row {
                let rect = NSRect(x: x, y: y, width: keySize, height: keySize)
                let assigned = keyMap[key] != nil
                (assigned ? NSColor.controlAccentColor : NSColor(calibratedWhite: 0.28, alpha: 1)).setFill()
                NSBezierPath(roundedRect: rect, xRadius: keySize * 0.16, yRadius: keySize * 0.16).fill()

                if let item = keyMap[key] {
                    // 程序名：上部居中
                    let name = item.name.count > 9 ? String(item.name.prefix(9)) + "…" : item.name
                    let nameFont = NSFont.systemFont(ofSize: keySize * 0.15, weight: .semibold)
                    let nameAttr: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: NSColor.white]
                    let ns = NSAttributedString(string: name, attributes: nameAttr)
                    ns.draw(at: NSPoint(x: rect.midX - ns.size().width / 2, y: rect.minY + keySize * 0.66))

                    // 副标题（窗口标题）：中部，小字、浅色
                    if !item.title.isEmpty {
                        let t = item.title.count > 12 ? String(item.title.prefix(12)) + "…" : item.title
                        let titleFont = NSFont.systemFont(ofSize: keySize * 0.10)
                        let titleAttr: [NSAttributedString.Key: Any] = [
                            .font: titleFont,
                            .foregroundColor: NSColor(calibratedWhite: 0.82, alpha: 1),
                        ]
                        let ts = NSAttributedString(string: t, attributes: titleAttr)
                        ts.draw(at: NSPoint(x: rect.midX - ts.size().width / 2, y: rect.minY + keySize * 0.40))
                    }
                }

                // 键位字母：下部居中
                let keyFont = NSFont.boldSystemFont(ofSize: keySize * 0.22)
                let keyAttr: [NSAttributedString.Key: Any] = [.font: keyFont, .foregroundColor: NSColor.white]
                let ks = NSAttributedString(string: key, attributes: keyAttr)
                ks.draw(at: NSPoint(x: rect.midX - ks.size().width / 2, y: rect.minY + keySize * 0.08))
                x += keySize + gap
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

func screenUnderMouse() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
}

func showPanel() {
    previousApp = NSWorkspace.shared.frontmostApplication
    refreshApps()
    (panel?.contentView as? KeyboardView)?.keyMap = keyMap

    if let screen = screenUnderMouse() {
        let sw = screen.frame.width
        let panelWidth = min(sw * 0.9, 1600)
        let gap: CGFloat = 10
        let keySize = (panelWidth - 9 * gap) / 10
        let panelHeight = 3 * (keySize + gap) + 16
        let x = screen.frame.midX - panelWidth / 2
        let y = screen.frame.minY + (screen.frame.height - panelHeight) * 0.45
        panel?.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }

    panel?.contentView?.needsDisplay = true
    NSApp.activate(ignoringOtherApps: true)
    panel?.makeKeyAndOrderFront(nil)
    print("[overlay] 面板已显示，尺寸=\(Int(panel?.frame.width ?? 0))x\(Int(panel?.frame.height ?? 0))，原前台 = \(previousApp?.localizedName ?? "?")")
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
            if let item = keyMap[String(c)] {
                print("[key] 按键 \(c) -> \(item.name)\(item.title.isEmpty ? "" : " | \(item.title)")")
                hidePanel()
                activate(item)
            } else {
                print("[key] 按键 \(c) -> 无匹配")
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
