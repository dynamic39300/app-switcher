import AppKit
import AppSwitcherCore

/// AppKit 留在主线程，可能阻塞的辅助功能调用交给独立 actor。
@MainActor
public final class RunningAppsProvider {
    private let windowAccess = WindowAccess()
    private var snapshotGeneration = 0

    public init() {}

    public func runningApps(excluding pid: Int) -> [AppDescriptor] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && Int($0.processIdentifier) != pid && !$0.isTerminated }
            .map { app in
                let processID = Int(app.processIdentifier)
                let identity = app.bundleIdentifier ?? "process:\(processID)"
                return AppDescriptor(
                    pid: processID,
                    bundleIdentifier: identity,
                    displayName: app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "应用"
                )
            }
    }

    /// 不依赖 AX 或屏幕录制权限，regular 应用即使没有可枚举的窗口仍然可用。
    public func candidates(excluding pid: Int, usage: [String: UsageStats]) -> [Candidate] {
        let apps = runningApps(excluding: pid)
        return bindProcessInstances(
            CandidateFactory.makeApplicationCandidates(apps: apps, usage: usage),
            dates: launchDates(for: apps)
        )
    }

    public func windowCandidates(excluding pid: Int, usage: [String: UsageStats]) async -> [Candidate] {
        await windowCandidates(for: runningApps(excluding: pid), usage: usage)
    }

    /// 明确进程名单入口，供隔离探测使用；不会枚举名单之外的窗口或标题。
    public func windowCandidates(for apps: [AppDescriptor], usage: [String: UsageStats]) async -> [Candidate] {
        snapshotGeneration += 1
        let generation = snapshotGeneration
        let validApps = apps.filter { descriptor in
            guard let pid = pid_t(exactly: descriptor.pid), pid > 0,
                  let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return false }
            return (app.bundleIdentifier ?? "process:\(descriptor.pid)") == descriptor.bundleIdentifier
        }
        let dates = launchDates(for: validApps)
        let candidates = await windowAccess.candidates(apps: validApps, usage: usage)
        guard generation == snapshotGeneration, !Task.isCancelled else { return [] }
        return bindProcessInstances(candidates, dates: dates)
    }

    public func invalidateWindowSnapshot() async {
        snapshotGeneration += 1
        await windowAccess.invalidate()
    }

    public func activate(_ candidate: Candidate) async -> ActivationResult {
        guard !Task.isCancelled else { return .failure("切换已取消。") }
        let pid = candidate.target.pid
        let activationGeneration = snapshotGeneration
        guard let nativePID = pid_t(exactly: pid), nativePID > 0,
              let app = NSRunningApplication(processIdentifier: nativePID), !app.isTerminated,
              (app.bundleIdentifier ?? "process:\(pid)") == candidate.groupID else {
            return .failure("这个应用已退出，请重新打开切换器。")
        }
        if let expected = candidate.processLaunchDate, app.launchDate != expected {
            return .failure("这个应用已重新启动，请重新打开切换器。")
        }
        guard !Task.isCancelled else { return .failure("切换已取消。") }
        if case .window(_, let token) = candidate.target {
            let preparation = await windowAccess.prepare(token: token, pid: pid)
            guard preparation == .success else { return preparation }
        } else {
            let reopening = await reopenApplicationIfPossible(app)
            guard reopening == .success else { return reopening }
        }
        guard !Task.isCancelled else { return .failure("切换已取消。") }
        guard !candidate.isWindow || activationGeneration == snapshotGeneration else {
            return .failure("窗口列表已更新，请重新选择目标。")
        }
        guard !app.isTerminated else {
            return .failure("这个应用已退出，请重新打开切换器。")
        }
        NSApp.yieldActivation(to: app)
        guard app.activate(options: []) else {
            return .failure("暂时无法激活这个应用，请重试。")
        }
        let activationDeadline = ContinuousClock.now.advanced(by: .seconds(1.2))
        while NSWorkspace.shared.frontmostApplication?.processIdentifier != nativePID {
            guard !Task.isCancelled else { return .failure("切换已取消。") }
            guard ContinuousClock.now < activationDeadline else {
                return .failure("未能确认应用已切到前台，请重试。")
            }
            do { try await Task.sleep(for: .milliseconds(50)) }
            catch { return .failure("切换已取消。") }
        }
        guard !Task.isCancelled else { return .failure("切换已取消。") }
        guard !candidate.isWindow || activationGeneration == snapshotGeneration else {
            return .failure("窗口列表已更新，请重新选择目标。")
        }
        if case .window(_, let token) = candidate.target {
            let result = await windowAccess.raise(token: token, pid: pid)
            guard result == .success else { return result }
        }

        // 应用目标核对重开后的原进程身份与前台 PID；具体窗口目标还需核对 AX 焦点对象。
        let deadline = ContinuousClock.now.advanced(by: .seconds(1.2))
        while ContinuousClock.now < deadline, !Task.isCancelled {
            let frontmostMatches = NSWorkspace.shared.frontmostApplication?.processIdentifier == nativePID
            switch candidate.target {
            case .application:
                if frontmostMatches { return .success }
            case .window(_, let token):
                switch await windowAccess.focusState(token: token, pid: pid) {
                case .focused:
                    guard !Task.isCancelled else { return .failure("切换已取消。") }
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier == nativePID { return .success }
                case .invalid:
                    return .failure("这个窗口已关闭或不可用，请重新打开切换器。")
                case .waiting: break
                }
            }
            do { try await Task.sleep(for: .milliseconds(50)) }
            catch { return .failure("切换已取消。") }
        }
        if Task.isCancelled { return .failure("切换已取消。") }
        return candidate.isWindow
            ? .failure("未能确认目标窗口已获得焦点。请重试，或切到应用模式。")
            : .failure("未能确认应用已切到前台，请重试。")
    }

    /// 应用入口采用 Dock/Finder 的重开语义，让应用自己恢复或重建其主窗口。
    /// 窗口入口不会走这里，也不会循环还原其他最小化窗口。
    private func reopenApplicationIfPossible(_ app: NSRunningApplication) async -> ActivationResult {
        guard let bundleURL = app.bundleURL, bundleURL.pathExtension.lowercased() == "app" else {
            return .success // 裸进程没有可重开的 bundle，仍可按精确 PID 激活。
        }
        let targetURL = bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let targetExecutable = app.executableURL?.resolvingSymlinksInPath().standardizedFileURL
        let instances = NSWorkspace.shared.runningApplications.filter { other in
            guard !other.isTerminated,
                  other.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == targetURL else { return false }
            // Helpers such as WeChat's wxplayer share the main app's bundle URL.
            // Only a known different executable rules out another main instance;
            // missing identity stays ambiguous, regardless of activation policy.
            guard let targetExecutable,
                  let executable = other.executableURL?.resolvingSymlinksInPath().standardizedFileURL else { return true }
            return executable == targetExecutable
        }
        guard instances.count == 1, instances[0].processIdentifier == app.processIdentifier else {
            return .failure("这个应用有多个运行实例，无法确认要恢复哪一个。请直接选择目标窗口。")
        }
        guard !Task.isCancelled else { return .failure("切换已取消。") }
        let expectedPID = app.processIdentifier
        let expectedLaunch = app.launchDate
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = false
        configuration.allowsRunningApplicationSubstitution = false
        configuration.promptsUserIfNeeded = false
        configuration.addsToRecentItems = false
        let pending = ApplicationOpenReplyBox()
        NSWorkspace.shared.openApplication(at: targetURL, configuration: configuration) { reopened, error in
            let reply = ApplicationOpenReply(
                pid: reopened?.processIdentifier, launchDate: reopened?.launchDate, failed: error != nil
            )
            // 迟到回调只写结果，绝不触发激活。已发出的系统重开请求本身无法撤销。
            Task { @MainActor in pending.reply = reply }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while pending.reply == nil {
            guard !Task.isCancelled else { return .failure("切换已取消。") }
            guard ContinuousClock.now < deadline else {
                return .failure("应用恢复窗口超时，请重试。")
            }
            do { try await Task.sleep(for: .milliseconds(30)) }
            catch { return .failure("切换已取消。") }
        }
        guard !Task.isCancelled else { return .failure("切换已取消。") }
        guard let reply = pending.reply, !reply.failed else {
            return .failure("暂时无法恢复这个应用的窗口，请重试。")
        }
        guard reply.pid == expectedPID, reply.launchDate == expectedLaunch, !app.isTerminated else {
            return .failure("应用运行实例已变化，请重新打开切换器。")
        }
        return .success
    }

    private func launchDates(for apps: [AppDescriptor]) -> [Int: Date] {
        var dates: [Int: Date] = [:]
        for app in apps {
            guard let pid = pid_t(exactly: app.pid),
                  let date = NSRunningApplication(processIdentifier: pid)?.launchDate else { continue }
            dates[app.pid] = date
        }
        return dates
    }

    private func bindProcessInstances(_ candidates: [Candidate], dates: [Int: Date]) -> [Candidate] {
        candidates.map { candidate in
            Candidate(
                id: candidate.id, groupID: candidate.groupID, displayName: candidate.displayName,
                title: candidate.title, activationCount: candidate.activationCount,
                lastActivatedAt: candidate.lastActivatedAt, target: candidate.target,
                windowCount: candidate.windowCount, processLaunchDate: dates[candidate.target.pid]
            )
        }
    }
}

private struct ApplicationOpenReply: Sendable {
    let pid: pid_t?
    let launchDate: Date?
    let failed: Bool
}

@MainActor
private final class ApplicationOpenReplyBox {
    var reply: ApplicationOpenReply?
}
