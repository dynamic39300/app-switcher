import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// F→J 组合热键（CGEventTap 实现）。
///
/// 设计目标：无修饰键、双手食指位（F/J）先后按下即视为“同时按下”唤起覆盖层，同时把对打字的干扰降到最低。
/// - 仅当「键盘空闲 ≥ idleMs（120ms）」时按下的 F 才会被暂扣进入 armed；打字中途的 F 完全直通（零延迟零干扰）。
/// - armed 后 windowMs（300ms）内按下 J（无修饰键）→ 吞掉 J 并触发。
/// - armed 后按下其他键 / 超时 → 把暂扣的 F 回放给前台 App（保持字符顺序），正常输入不丢字。
/// - 覆盖层显示期间 `suspended = true`：F/J 是覆盖层内切 App 的键位，必须直通。
/// - 已知代价：空闲后输入以 f 开头且 300ms 内接 j 的词（如 fjord）会误触发。
/// - 权限：监听键盘需「输入监控」；回放事件走辅助功能（已授权）。
///
/// 只输出启动与权限状态，不记录全局按键或窗口内容。
final class SequenceHotKey {
    static let shared = SequenceHotKey()

    var onTrigger: (() -> Void)?
    /// 覆盖层显示期间挂起序列检测。
    var suspended = false {
        didSet { if suspended { triggerGeneration &+= 1 } }
    }
    /// 录制和覆盖层分别管理暂停原因，结束录制不能意外解除覆盖层暂停。
    var recordingSuspended = false {
        didSet {
            if recordingSuspended { triggerGeneration &+= 1 }
            if recordingSuspended, armed { disarm(reinject: true) }
        }
    }
    var isRunning: Bool { tap != nil }

    private let fCode = CGKeyCode(kVK_ANSI_F) // 3
    private let jCode = CGKeyCode(kVK_ANSI_J) // 38
    private let idleMs: Double = 120
    private let windowMs: Double = 300

    private var tap: CFMachPort?
    private var runSource: CFRunLoopSource?
    private var armed = false
    private var armedAt = 0.0
    private var armedFEvent: CGEvent?
    private var lastKeyAt = 0.0
    private var timer: DispatchSourceTimer?
    private var triggerGeneration: UInt64 = 0


    private init() {}

    private static let callback: CGEventTapCallBack = { _, type, event, _ in
        SequenceHotKey.shared.handle(type: type, event: event)
    }

    func start() {
        guard tap == nil else { return }
        let pre = CGPreflightListenEventAccess()
        if !pre {
            _ = CGRequestListenEventAccess()
        }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: Self.callback,
            userInfo: nil
        ) else {
            print("[seq] ❌ CGEventTap 创建失败：请到 系统设置→隐私与安全性→输入监控 允许 AppSwitcher")
            return
        }
        tap = t
        runSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runSource, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        print("[seq] F→J 序列热键已启用（空闲 \(Int(idleMs))ms 后按 F，\(Int(windowMs))ms 内接 J 唤起）")
    }

    func stop() {
        triggerGeneration &+= 1
        disarm(reinject: true)
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runSource, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        runSource = nil
        tap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 系统超时禁用 tap 时重新启用（标准防御）
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }

        let now = Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
        defer { lastKeyAt = now }

        if recordingSuspended { return Unmanaged.passUnretained(event) }
        if suspended {
            if armed { disarm(reinject: false) } // 丢弃暂扣的 F，避免漏进覆盖层
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let hasModifiers = flags.contains(.maskCommand) || flags.contains(.maskAlternate)
            || flags.contains(.maskControl) || flags.contains(.maskNumericPad) || flags.contains(.maskSecondaryFn)

        if armed {
            if type == .keyDown {
                let elapsedMs = (now - armedAt) * 1000
                if !hasModifiers && keyCode == jCode && elapsedMs <= windowMs {
                    disarm(reinject: false)
                    let generation = triggerGeneration
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.triggerGeneration == generation, self.tap != nil,
                              !self.recordingSuspended, !self.suspended else { return }
                        self.onTrigger?()
                    }
                    return nil // 吞掉 J
                }
                // 其他键（含带修饰键、超时的 J）：先回放暂扣的 F，再放行当前键，保持字符顺序
                disarm(reinject: true)
                return Unmanaged.passUnretained(event)
            }
            // keyUp 直通；armed 继续等待（F 松开后再按 J 的 tap-tap 也算序列）
            return Unmanaged.passUnretained(event)
        }

        // 未 armed：仅「空闲 + 无修饰 + F keyDown」才暂扣进入 armed
        if type == .keyDown && keyCode == fCode && !hasModifiers {
            let idleNow = (now - lastKeyAt) * 1000
            if idleNow >= idleMs {
                armed = true
                armedAt = now
                armedFEvent = event.copy()
                scheduleTimeout()
                return nil
            } else {
            }
        }
        return Unmanaged.passUnretained(event)
    }

    private func scheduleTimeout() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + windowMs / 1000)
        t.setEventHandler { [weak self] in
            guard let self, self.armed else { return }
            self.disarm(reinject: true)
        }
        t.resume()
        timer = t
    }

    private func disarm(reinject: Bool) {
        timer?.cancel()
        timer = nil
        armed = false
        let e = armedFEvent
        armedFEvent = nil
        if reinject, let e {
            // 回放到会话（前台 App 收到原字符）；回放事件经 tap 时 idle 不足阈值，不会被再次暂扣
            e.post(tap: .cgSessionEventTap)
        }
    }
}
