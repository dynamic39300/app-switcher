import AppKit
import Carbon.HIToolbox
import AppSwitcherCore

/// Carbon 注册与事件处理只在主线程运行；一个 handler 服务所有注册代次。
@MainActor
final class GlobalHotKey {
    static let shared = GlobalHotKey()
    private static let signature = OSType(0x41535748) // ASWH

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var registrationID: UInt32?
    private var nextID: UInt32 = 1
    private var retiredRefs: [EventHotKeyRef] = []
    private(set) var currentShortcut: AppShortcut?
    private(set) var isSuspended = false
    var onTrigger: (() -> Void)?

    private init() {}

    /// 新键与持久化均成功之后才放开旧键，失败时保留旧注册和配置。
    func replace(with shortcut: AppShortcut, persist: () throws -> Void = {}) throws {
        if let message = shortcut.validationMessage { throw HotKeyError.message(message) }
        if currentShortcut == shortcut, hotKeyRef != nil, !isSuspended {
            try persist()
            return
        }
        try checkSystemConflict(shortcut)
        try installHandlerIfNeeded()
        let identifier = nextRegistrationID()
        var replacement: EventHotKeyRef?
        let result = RegisterEventHotKey(
            UInt32(shortcut.keyCode), shortcut.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: identifier),
            GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &replacement
        )
        guard result == noErr, let replacement else { throw registrationError(result) }
        do { try persist() }
        catch {
            releaseOrRetain(replacement)
            throw error
        }
        let old = hotKeyRef
        hotKeyRef = replacement
        registrationID = identifier
        currentShortcut = shortcut
        isSuspended = false
        // 旧事件即使已排队也无法通过 registrationID 检查。
        if let old { releaseOrRetain(old) }
    }

    func suspend() throws {
        guard !isSuspended else { return }
        if let hotKeyRef {
            guard UnregisterEventHotKey(hotKeyRef) == noErr else {
                throw HotKeyError.message("暂时无法暂停当前快捷键，请关闭设置后重试。")
            }
            self.hotKeyRef = nil
        }
        registrationID = nil
        isSuspended = true
    }

    func resume() throws {
        guard isSuspended else { return }
        guard let shortcut = currentShortcut else { isSuspended = false; return }
        try replace(with: shortcut)
    }

    func stop() {
        registrationID = nil
        currentShortcut = nil
        isSuspended = false
        if let hotKeyRef { releaseOrRetain(hotKeyRef) }
        hotKeyRef = nil
        retiredRefs = retiredRefs.filter { UnregisterEventHotKey($0) != noErr }
        if let handlerRef { _ = RemoveEventHandler(handlerRef) }
        handlerRef = nil
    }

    /// 旧调用者的兼容入口；新设置流程使用 replace(with:persist:) 接收错误。
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        guard let code = UInt16(exactly: keyCode) else { return false }
        var flags: ShortcutModifiers = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        do { try replace(with: AppShortcut(keyCode: code, modifiers: flags)); return true }
        catch { return false }
    }

    private func installHandlerIfNeeded() throws {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var incoming = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &incoming)
            guard result == noErr, incoming.signature == OSType(0x41535748) else { return OSStatus(eventNotHandledErr) }
            let identifier = incoming.id
            DispatchQueue.main.async { GlobalHotKey.shared.deliver(identifier) }
            return noErr
        }
        let result = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &handlerRef)
        guard result == noErr else { throw HotKeyError.message("无法安装快捷键监听，请重启 AppSwitcher 后重试。") }
    }

    private func deliver(_ identifier: UInt32) {
        guard registrationID == identifier, hotKeyRef != nil, !isSuspended else { return }
        onTrigger?()
    }

    private func checkSystemConflict(_ shortcut: AppShortcut) throws {
        var values: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&values) == noErr,
              let keys = values?.takeRetainedValue() as? [[String: Any]] else {
            throw HotKeyError.message("无法检查系统快捷键，请稍后重试。")
        }
        for key in keys {
            guard (key[kHISymbolicHotKeyEnabled as String] as? NSNumber)?.boolValue == true,
                  let code = key[kHISymbolicHotKeyCode as String] as? NSNumber,
                  let modifiers = key[kHISymbolicHotKeyModifiers as String] as? NSNumber else { continue }
            if code.uint16Value == shortcut.keyCode, modifiers.uint32Value == shortcut.carbonModifiers {
                throw HotKeyError.message("这个组合已被系统快捷键使用，请换一个组合或先调整系统设置。")
            }
        }
    }

    private func nextRegistrationID() -> UInt32 {
        let result = nextID
        nextID &+= 1
        if nextID == 0 { nextID = 1 }
        return result
    }

    private func registrationError(_ status: OSStatus) -> HotKeyError {
        if status == eventHotKeyExistsErr {
            return .message("这个组合已被其他全局快捷键占用，请换一个组合。")
        }
        return .message("无法注册这个快捷键，请换一个组合后重试。")
    }

    private func releaseOrRetain(_ reference: EventHotKeyRef) {
        if UnregisterEventHotKey(reference) != noErr {
            // 不把已保存的新设置回滚到旧状态；失效代次绝不触发，退出时再释放。
            retiredRefs.append(reference)
        }
    }
}

extension AppShortcut {
    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }
}

enum HotKeyError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}
