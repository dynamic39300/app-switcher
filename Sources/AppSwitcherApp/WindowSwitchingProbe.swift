import AppKit
import ApplicationServices
import AppSwitcherCore
import AppSwitcherKit
import Darwin

/// 跨进程隔离验证：父进程只管理合成窗口，子进程只通过公开 AX 操作父进程。
/// AX 自查询在本机返回空列表，因此不能用同进程窗口证明跨应用切换可用。
@MainActor
enum WindowSwitchingProbe {
    private enum ProbeFailure: Error { case failed(String) }

    static func run() async -> Int {
        signal(SIGPIPE, SIG_IGN)
        guard AXIsProcessTrusted() else {
            print("SKIP window-switching: 辅助功能未授权；未创建窗口、未申请权限。")
            return 2
        }
        if let index = CommandLine.arguments.firstIndex(of: "--probe-driver") {
            guard CommandLine.arguments.count > index + 1,
                  let pid = pid_t(CommandLine.arguments[index + 1]), pid == getppid() else {
                print("FAIL window-switching: 驱动进程只能连接创建它的合成父进程。")
                return 1
            }
            return await runDriver(parentPID: pid)
        }
        guard NSApp.windows.isEmpty else {
            print("FAIL window-switching: 请从独立验证入口运行，不能混入已有应用窗口。")
            return 1
        }
        return await runFixture()
    }

    private static func runFixture() async -> Int {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        let first = makeWindow(title: "AppSwitcher Probe Alpha", x: 180)
        let second = makeWindow(title: "AppSwitcher Probe Beta", x: 620)
        let child = Process()
        let requests = Pipe()
        let responses = Pipe()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        child.arguments = ["--verify-window-switching", "--probe-driver", String(getpid())]
        child.standardOutput = requests
        child.standardInput = responses
        defer {
            if child.isRunning { child.terminate() }
            try? responses.fileHandleForWriting.close()
            try? requests.fileHandleForReading.close()
            first.close()
            second.close()
            NSApp.setActivationPolicy(previousPolicy)
        }
        do {
            first.makeKeyAndOrderFront(nil)
            second.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await settle()
            try child.run()
            // 父进程不再持有管道的子端，使 EOF 能真实反映子进程退出。
            try requests.fileHandleForWriting.close()
            try responses.fileHandleForReading.close()
            let reader = ProbeLineReader(handle: requests.fileHandleForReading)
            while let line = await reader.readLine() {
                if line.hasPrefix("@FIXTURE ") {
                    let command = String(line.dropFirst("@FIXTURE ".count))
                    let result = await fixtureCommand(command, first: first, second: second)
                    try responses.fileHandleForWriting.write(contentsOf: Data((result ? "OK\n" : "FAIL\n").utf8))
                } else {
                    print(line)
                }
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(1))
            while child.isRunning, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(30))
            }
            guard !child.isRunning else {
                print("FAIL window-switching: 验证子进程无响应，已停止合成验证。")
                return 1
            }
            return Int(child.terminationStatus)
        } catch {
            print("FAIL window-switching: 无法完成合成窗口验证通信。")
            return 1
        }
    }

    private static func runDriver(parentPID: pid_t) async -> Int {
        guard let parent = NSRunningApplication(processIdentifier: parentPID), !parent.isTerminated else {
            print("FAIL window-switching: 合成窗口父进程已退出。")
            return 1
        }
        let descriptor = AppDescriptor(
            pid: Int(parentPID),
            bundleIdentifier: parent.bundleIdentifier ?? "process:\(parentPID)",
            displayName: "AppSwitcher Synthetic Probe"
        )
        let reader = ProbeLineReader(handle: .standardInput)
        let provider = RunningAppsProvider()
        let foregroundWindow = makeWindow(title: "AppSwitcher Probe Driver", x: 380)
        defer { foregroundWindow.close() }
        var exitCode = 0
        do {
            let launchDeadline = ContinuousClock.now.advanced(by: .seconds(2))
            while !NSRunningApplication.current.isFinishedLaunching {
                guard ContinuousClock.now < launchDeadline else { throw ProbeFailure.failed("验证驱动未完成启动。") }
                try await Task.sleep(for: .milliseconds(30))
            }
            try require(await request("ready", reader: reader), "初始焦点落在第二个合成窗口")
            var candidates = await provider.windowCandidates(for: [descriptor], usage: [:])
            try require(candidates.count == 2 && candidates.allSatisfy(\.isWindow), "独立AX对象与唯一标题可展开")
            let initialTarget = try target(in: candidates, title: "AppSwitcher Probe Alpha")
            NSApp.setActivationPolicy(.regular)
            foregroundWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await settle()
            try require(NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid(), "驱动进程已前台，模拟覆盖层抢焦点")
            let initialResult = await provider.activate(initialTarget)
            let initialFocus = await request("assert-alpha-focused", reader: reader)
            if case .failure(let reason) = initialResult { print("INFO window-switching: \(reason)") }
            try require(initialResult == .success && initialFocus, "后台目标窗口获得真实键盘焦点")
            foregroundWindow.orderOut(nil)

            try require(await request("rename-alpha", reader: reader), "改变目标标题并把另一窗口置前")
            let renamedResult = await provider.activate(initialTarget)
            let renamedFocus = await request("assert-alpha-focused", reader: reader)
            try require(renamedResult == .success && renamedFocus, "标题改变后旧token仍准确切换原对象")

            try require(await request("duplicate", reader: reader), "构造同名合成窗口")
            candidates = await provider.windowCandidates(for: [descriptor], usage: [:])
            try require(isApplicationFallback(candidates), "同名窗口整应用回退")
            try require(await request("untitled", reader: reader), "构造无标题合成窗口")
            candidates = await provider.windowCandidates(for: [descriptor], usage: [:])
            try require(isApplicationFallback(candidates), "无标题窗口整应用回退")

            try require(await request("unique", reader: reader), "恢复唯一合成标题")
            candidates = await provider.windowCandidates(for: [descriptor], usage: [:])
            let minimizedTarget = try target(in: candidates, title: "AppSwitcher Probe Alpha")
            let otherTarget = try target(in: candidates, title: "AppSwitcher Probe Beta")
            try require(await request("minimize", reader: reader), "已入选的两个合成窗口随后被最小化")
            let cancellation = Task { await provider.activate(minimizedTarget) }
            cancellation.cancel()
            let cancelledResult = await cancellation.value
            let stillMinimized = await request("assert-both-minimized", reader: reader)
            try require(isFailure(cancelledResult) && stillMinimized, "取消不恢复或激活窗口")

            let wrongProcess = Candidate(
                id: minimizedTarget.id, groupID: minimizedTarget.groupID,
                displayName: minimizedTarget.displayName, title: minimizedTarget.title,
                target: minimizedTarget.target, processLaunchDate: .distantPast
            )
            let wrongProcessResult = await provider.activate(wrongProcess)
            let unchanged = await request("assert-both-minimized", reader: reader)
            try require(isFailure(wrongProcessResult) && unchanged, "旧进程启动身份被拒绝")
            let restoredResult = await provider.activate(minimizedTarget)
            let onlyTargetRestored = await request("assert-only-alpha-restored", reader: reader)
            try require(restoredResult == .success && onlyTargetRestored, "只恢复目标最小化窗口并验证焦点")

            try require(await request("close-alpha", reader: reader), "关闭选定合成窗口")
            let closedResult = await provider.activate(minimizedTarget)
            let otherStillMinimized = await request("assert-beta-minimized", reader: reader)
            try require(isFailure(closedResult) && otherStillMinimized, "关闭后的token明确失败且不改切其他窗口")

            await provider.invalidateWindowSnapshot()
            let invalidatedResult = await provider.activate(otherTarget)
            let remainedMinimized = await request("assert-beta-minimized", reader: reader)
            try require(isFailure(invalidatedResult) && remainedMinimized, "过期快照token不可再次激活")
            candidates = await provider.windowCandidates(for: [descriptor], usage: [:])
            try require(isApplicationFallback(candidates), "扫描时已最小化且主窗口不可写则保守回退")
        } catch ProbeFailure.failed(let message) {
            print("FAIL window-switching: \(message)")
            exitCode = 1
        } catch {
            print("FAIL window-switching: 验证被取消或等待超时。")
            exitCode = 1
        }
        await provider.invalidateWindowSnapshot()
        if exitCode == 0 { print("PASS window-switching: 全部跨进程隔离AX验证通过。") }
        return exitCode
    }

    private static func fixtureCommand(_ command: String, first: NSWindow, second: NSWindow) async -> Bool {
        switch command {
        case "ready":
            first.makeKeyAndOrderFront(nil)
            second.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            let deadline = ContinuousClock.now.advanced(by: .seconds(2))
            while NSApp.keyWindow !== second || NSWorkspace.shared.frontmostApplication?.processIdentifier != getpid() {
                guard ContinuousClock.now < deadline else { return false }
                try? await Task.sleep(for: .milliseconds(30))
            }
        case "rename-alpha":
            first.title = "AppSwitcher Probe Alpha Renamed"
            second.makeKeyAndOrderFront(nil)
        case "assert-alpha-focused": return NSApp.keyWindow === first
        case "duplicate":
            first.title = "AppSwitcher Probe Duplicate"
            second.title = "AppSwitcher Probe Duplicate"
        case "untitled":
            first.title = ""
            second.title = "AppSwitcher Probe Beta"
        case "unique":
            first.title = "AppSwitcher Probe Alpha"
            second.title = "AppSwitcher Probe Beta"
        case "minimize":
            first.title = "AppSwitcher Probe Alpha"
            second.title = "AppSwitcher Probe Beta"
            first.miniaturize(nil)
            second.miniaturize(nil)
            let deadline = ContinuousClock.now.advanced(by: .seconds(2))
            while !first.isMiniaturized || !second.isMiniaturized {
                guard ContinuousClock.now < deadline else { return false }
                try? await Task.sleep(for: .milliseconds(50))
            }
        case "assert-both-minimized": return first.isMiniaturized && second.isMiniaturized
        case "assert-only-alpha-restored": return !first.isMiniaturized && second.isMiniaturized && NSApp.keyWindow === first
        case "assert-beta-minimized": return second.isMiniaturized
        case "close-alpha": first.close()
        default: return false
        }
        try? await settle()
        return true
    }

    private static func request(_ command: String, reader: ProbeLineReader) async -> Bool {
        print("@FIXTURE \(command)")
        return await reader.readLine() == "OK"
    }

    private static func makeWindow(title: String, x: CGFloat) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: x, y: 260, width: 400, height: 230),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        let label = NSTextField(labelWithString: "AppSwitcher 合成验证窗口\n完成后会自动关闭。")
        label.frame = NSRect(x: 28, y: 80, width: 340, height: 60)
        label.font = .systemFont(ofSize: 20)
        label.maximumNumberOfLines = 2
        window.contentView?.addSubview(label)
        return window
    }

    private static func target(in candidates: [Candidate], title: String) throws -> Candidate {
        // 这里只从已知合成数据选择测试用例；生产激活始终使用候选的AX token。
        guard let candidate = candidates.first(where: { $0.isWindow && $0.title == title }) else {
            throw ProbeFailure.failed("合成目标没有获得可操作的窗口token。")
        }
        return candidate
    }

    private static func isApplicationFallback(_ candidates: [Candidate]) -> Bool {
        candidates.count == 1 && !candidates[0].isWindow
    }

    private static func isFailure(_ result: ActivationResult) -> Bool {
        if case .failure = result { return true }
        return false
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ProbeFailure.failed(message) }
        print("PASS window-switching: \(message)")
    }

    private static func settle() async throws { try await Task.sleep(for: .milliseconds(200)) }
}

/// 只供合成验证使用的有界管道读取；不能阻塞 AppKit 主线程。
private actor ProbeLineReader {
    private let handle: FileHandle
    private var buffered = Data()

    init(handle: FileHandle) { self.handle = handle }

    func readLine() -> String? {
        while true {
            if let newline = buffered.firstIndex(of: 10) {
                let line = String(data: buffered[..<newline], encoding: .utf8)
                buffered.removeSubrange(...newline)
                return line
            }
            guard buffered.count < 4096 else { return nil }
            var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN | POLLHUP), revents: 0)
            guard poll(&descriptor, 1, 8_000) > 0 else { return nil }
            var bytes = [UInt8](repeating: 0, count: 4096)
            let count = Darwin.read(handle.fileDescriptor, &bytes, bytes.count)
            guard count > 0 else { return nil }
            buffered.append(contentsOf: bytes.prefix(count))
        }
    }
}
