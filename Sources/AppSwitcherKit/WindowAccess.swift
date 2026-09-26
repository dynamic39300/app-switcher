import ApplicationServices
import Foundation
import AppSwitcherCore

/// AX 对象不跨 actor 传递、不写入磁盘，也不由标题重新查找。
/// 每次探测总预算 2 秒、每个进程 0.4 秒；在途 IPC 最多追加 0.12 秒，超限进程保留应用入口。
actor WindowAccess {
    enum FocusState: Sendable { case focused, waiting, invalid }

    private struct Handle {
        let pid: Int
        let application: AXUIElement
        let window: AXUIElement
    }

    private var handles: [String: Handle] = [:]
    private let timeout: Float = 0.12
    private let maxWindowsPerApp = 64
    private let maxWindowsPerSnapshot = 256
    private var probeDeadline: ContinuousClock.Instant?

    func invalidate() { handles.removeAll() }

    func candidates(apps: [AppDescriptor], usage: [String: UsageStats]) -> [Candidate] {
        invalidate()
        defer { probeDeadline = nil }
        guard AXIsProcessTrusted(), !Task.isCancelled else {
            return CandidateFactory.makeApplicationCandidates(apps: apps, usage: usage)
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        var descriptors: [WindowDescriptor] = []
        var unavailable: Set<Int> = []
        for app in apps {
            guard !Task.isCancelled, ContinuousClock.now < deadline,
                  descriptors.count < maxWindowsPerSnapshot else {
                unavailable.insert(app.pid)
                continue
            }
            let appDeadline = min(deadline, ContinuousClock.now.advanced(by: .milliseconds(400)))
            probeDeadline = appDeadline
            let application = AXUIElementCreateApplication(pid_t(app.pid))
            guard AXUIElementSetMessagingTimeout(application, timeout) == .success,
                  let windows = windows(of: application), !windows.isEmpty,
                  windows.count <= maxWindowsPerApp,
                  descriptors.count + windows.count <= maxWindowsPerSnapshot else {
                unavailable.insert(app.pid)
                continue
            }
            var appDescriptors: [WindowDescriptor] = []
            for window in windows {
                guard ContinuousClock.now < appDeadline, !Task.isCancelled,
                      AXUIElementSetMessagingTimeout(window, timeout) == .success,
                      string(window, kAXRoleAttribute) == kAXWindowRole as String,
                      let title = string(window, kAXTitleAttribute),
                      title.utf8.count <= 2048,
                      supportsRaise(window),
                      isSettable(window, kAXMainAttribute),
                      let minimized = boolean(window, kAXMinimizedAttribute),
                      !minimized || isSettable(window, kAXMinimizedAttribute) else {
                    unavailable.insert(app.pid)
                    break
                }
                guard ContinuousClock.now < appDeadline else {
                    unavailable.insert(app.pid)
                    break
                }
                let token = UUID().uuidString
                handles[token] = Handle(pid: app.pid, application: application, window: window)
                appDescriptors.append(WindowDescriptor(
                    pid: app.pid, title: title, windowNumber: 0,
                    layer: 0, alpha: 1, width: 0, height: 0,
                    targetToken: token, canRaise: true, canSetMain: true
                ))
            }
            descriptors.append(contentsOf: appDescriptors)
        }
        let result = CandidateFactory.makeWindowCandidates(
            apps: apps, windows: descriptors, unavailablePIDs: unavailable, usage: usage
        )
        // 不可展示的对象立即释放，不把同名/无标题窗口藏在缓存中。
        let visibleTokens = Set(result.compactMap { candidate -> String? in
            if case .window(_, let token) = candidate.target { return token }
            return nil
        })
        handles = handles.filter { visibleTokens.contains($0.key) }
        return result
    }

    func prepare(token: String, pid: Int) async -> ActivationResult {
        guard !Task.isCancelled else { return .failure("切换已取消。") }
        guard AXIsProcessTrusted() else {
            return .failure("窗口切换需要辅助功能权限，请在系统设置中允许 AppSwitcher。")
        }
        guard let handle = handles[token], handle.pid == pid,
              let liveWindows = windows(of: handle.application),
              liveWindows.contains(where: { CFEqual($0, handle.window) }) else {
            return .failure("这个窗口已关闭或不可用，请重新打开切换器。")
        }
        guard supportsRaise(handle.window),
              let minimized = boolean(handle.window, kAXMinimizedAttribute) else {
            return .failure("这个窗口暂不支持精确切换，请切到应用模式。")
        }
        if minimized {
            guard isSettable(handle.window, kAXMinimizedAttribute),
                  !Task.isCancelled,
                  AXUIElementSetAttributeValue(handle.window, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else {
                return .failure("无法恢复这个最小化窗口，请重试。")
            }
        }
        // 已入选的窗口可能在按键前被最小化。原生窗口最小化时 AXMain 不可写，
        // 仅恢复这个已验证的对象后再检查，不能据此放宽新快照的能力门槛。
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(600))
        while !isSettable(handle.window, kAXMainAttribute) {
            guard minimized, ContinuousClock.now < deadline, !Task.isCancelled else {
                return .failure("这个窗口暂不支持精确切换，请切到应用模式。")
            }
            do { try await Task.sleep(for: .milliseconds(40)) }
            catch { return .failure("切换已取消。") }
            guard let current = handles[token], current.pid == pid,
                  CFEqual(current.window, handle.window) else {
                return .failure("窗口列表已更新，请重新选择目标。")
            }
        }
        return .success
    }

    func raise(token: String, pid: Int) -> ActivationResult {
        guard !Task.isCancelled else { return .failure("切换已取消。") }
        guard let handle = handles[token], handle.pid == pid else {
            return .failure("窗口列表已更新，请重新选择目标。")
        }
        guard AXUIElementSetAttributeValue(handle.window, kAXMainAttribute as CFString, kCFBooleanTrue) == .success,
              !Task.isCancelled,
              AXUIElementPerformAction(handle.window, kAXRaiseAction as CFString) == .success else {
            return .failure("目标窗口未能切到前台，请重试或切到应用模式。")
        }
        return .success
    }

    func focusState(token: String, pid: Int) -> FocusState {
        guard let handle = handles[token], handle.pid == pid else { return .invalid }
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(handle.application, kAXFocusedWindowAttribute as CFString, &focused)
        if result == .invalidUIElement { return .invalid }
        guard result == .success, let focused else { return .waiting }
        return CFEqual(focused, handle.window) ? .focused : .waiting
    }

    private func windows(of application: AXUIElement) -> [AXUIElement]? {
        var count = 0
        guard withinProbeBudget,
              AXUIElementGetAttributeValueCount(application, kAXWindowsAttribute as CFString, &count) == .success,
              count <= maxWindowsPerApp else { return nil }
        var value: CFTypeRef?
        guard withinProbeBudget,
              AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], windows.count == count else { return nil }
        return windows
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard withinProbeBudget,
              AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func boolean(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard withinProbeBudget,
              AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    private func supportsRaise(_ window: AXUIElement) -> Bool {
        var actions: CFArray?
        guard withinProbeBudget,
              AXUIElementCopyActionNames(window, &actions) == .success,
              let actions = actions as? [String] else { return false }
        return actions.contains(kAXRaiseAction as String)
    }

    private func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        return withinProbeBudget
            && AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success
            && settable.boolValue
    }

    private var withinProbeBudget: Bool {
        !Task.isCancelled && (probeDeadline.map { ContinuousClock.now < $0 } ?? true)
    }
}
