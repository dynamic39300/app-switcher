/// 隔离的应用恢复回归：临时 fixture bundle 接收真实 reopen 事件；不操作用户应用。
import AppKit
import AppSwitcherCore
import AppSwitcherKit
import Darwin
private actor ApplicationProbeLineReader {
    let handle: FileHandle
    var buffered = Data()
    init(_ handle: FileHandle) { self.handle = handle }
    func line() -> String? {
        while true {
            if let index = buffered.firstIndex(of: 10) {
                let result = String(data: buffered[..<index], encoding: .utf8)
                buffered.removeSubrange(...index)
                return result
            }
            guard buffered.count < 4096 else { return nil }
            var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN | POLLHUP), revents: 0)
            guard poll(&descriptor, 1, 8000) > 0 else { return nil }
            var bytes = [UInt8](repeating: 0, count: 4096)
            let count = Darwin.read(handle.fileDescriptor, &bytes, bytes.count)
            guard count > 0 else { return nil }
            buffered.append(contentsOf: bytes.prefix(count))
        }
    }
}

@MainActor
private final class ApplicationProbeFixtureDelegate: NSObject, NSApplicationDelegate {
    var target: NSWindow?
    var reopenCount = 0
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        reopenCount += 1
        if let target {
            if target.isMiniaturized { target.deminiaturize(nil) }
            target.makeKeyAndOrderFront(nil)
        }
        return false
    }
}

@MainActor
enum AppActivationProbe {
    static func run() async -> Int {
        signal(SIGPIPE, SIG_IGN)
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--app-probe-driver"), args.count > index + 1,
           let pid = pid_t(args[index + 1]), pid == getppid() {
            return Int(await driver(parentPID: pid))
        }
        if let index = args.firstIndex(of: "--app-probe-fixture"), args.count > index + 1 {
            return Int(await fixture(driverExecutable: args[index + 1]))
        }
        let processRole = args.contains("--app-probe-second-instance") ? "--app-probe-second-instance" : "--app-probe-helper"
        if let index = args.firstIndex(of: processRole), args.count > index + 1,
           let pid = pid_t(args[index + 1]), pid == getppid() {
            NSApp.setActivationPolicy(processRole == "--app-probe-helper" ? .prohibited : .regular)
            let deadline = ContinuousClock.now.advanced(by: .seconds(60))
            while ContinuousClock.now < deadline,
                  let parent = NSRunningApplication(processIdentifier: pid), !parent.isTerminated {
                try? await Task.sleep(for: .milliseconds(100))
            }
            return 0
        }
        return await launchFixtureBundle()
    }

    /// 新建的临时 bundle 与测试驱动不同，真实接收 LaunchServices reopen 事件。
    private static func launchFixtureBundle() async -> Int {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppSwitcher-activation-" + UUID().uuidString)
        let bundle = root.appendingPathComponent("Fixture.app")
        let executable = bundle.appendingPathComponent("Contents/MacOS/Fixture")
        let process = Process()
        let output = Pipe()
        defer {
            if process.isRunning { process.terminate() }
            try? output.fileHandleForReading.close()
            try? FileManager.default.removeItem(at: root)
        }
        do {
            let source = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: executable)
            try FileManager.default.copyItem(at: source, to: executable.deletingLastPathComponent().appendingPathComponent("Helper"))
            let info: [String: Any] = [
                "CFBundleIdentifier": "local.appswitcher.activationprobe." + UUID().uuidString.lowercased(),
                "CFBundleName": "AppSwitcher Synthetic Fixture", "CFBundleExecutable": "Fixture",
                "CFBundlePackageType": "APPL", "NSHighResolutionCapable": true
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try data.write(to: bundle.appendingPathComponent("Contents/Info.plist"))
            process.executableURL = executable
            process.arguments = ["--verify-app-activation", "--app-probe-fixture", source.path]
            process.standardOutput = output
            try process.run()
            try output.fileHandleForWriting.close()
            let reader = ApplicationProbeLineReader(output.fileHandleForReading)
            while let line = await reader.line() { print(line) }
            guard await until({ !process.isRunning }) else { return 2 }
            return Int(process.terminationStatus)
        } catch {
            print("FAIL app-activation: 无法创建隔离应用 fixture。")
            return 2
        }
    }

    static func window(_ title: String, x: CGFloat) -> NSWindow {
        let result = NSWindow(contentRect: NSRect(x: x, y: 240, width: 400, height: 230),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        result.title = title
        result.isReleasedWhenClosed = false
        result.tabbingMode = .disallowed
        result.contentView?.addSubview(NSTextField(labelWithString: "Synthetic App activation probe"))
        return result
    }

    static func until(_ predicate: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !predicate() {
            guard ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(30))
        }
        try? await Task.sleep(for: .milliseconds(150))
        return true
    }

    static func fixture(driverExecutable: String) async -> Int32 {
        let previousFrontmost = NSWorkspace.shared.frontmostApplication
        NSApp.setActivationPolicy(.regular)
        let target = window("Synthetic application fixture", x: 160)
        let secondary = window("Synthetic secondary window", x: 380)
        let delegate = ApplicationProbeFixtureDelegate()
        delegate.target = target
        NSApp.delegate = delegate
        let requests = Pipe(), responses = Pipe()
        let child = Process()
        let helper = Process()
        let secondInstance = Process()
        helper.executableURL = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/Helper")
        helper.arguments = ["--verify-app-activation", "--app-probe-helper", String(getpid())]
        helper.standardOutput = FileHandle.nullDevice
        child.executableURL = URL(fileURLWithPath: driverExecutable)
        child.arguments = ["--verify-app-activation", "--app-probe-driver", String(getpid())]
        child.standardOutput = requests
        child.standardInput = responses
        defer {
            let foregroundPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let mayRestore = foregroundPID == getpid() || foregroundPID == child.processIdentifier
            if child.isRunning { child.terminate() }
            if helper.isRunning { helper.terminate() }
            if secondInstance.isRunning { secondInstance.terminate() }
            target.close()
            secondary.close()
            if mayRestore { _ = previousFrontmost?.activate(options: []) }
            try? requests.fileHandleForReading.close()
            try? responses.fileHandleForWriting.close()
        }
        do {
            target.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            guard await until({ NSRunningApplication.current.isFinishedLaunching }) else { return 2 }
            try helper.run()
            let fixtureURL = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
            // 真实辅助进程必须出现在同一 bundle 下，不能用模拟数组掩盖系统枚举差异。
            guard await until({
                NSWorkspace.shared.runningApplications.contains { app in
                    app.processIdentifier == helper.processIdentifier
                        && app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == fixtureURL
                        && app.executableURL?.lastPathComponent == "Helper"
                        && app.activationPolicy == .prohibited
                        && app.bundleIdentifier == NSRunningApplication.current.bundleIdentifier
                }
            }) else {
                if let app = NSRunningApplication(processIdentifier: helper.processIdentifier) {
                    print("PROBE_ERROR helper metadata: inWorkspace=\(NSWorkspace.shared.runningApplications.contains { $0.processIdentifier == helper.processIdentifier }) bundle=\(app.bundleURL?.lastPathComponent ?? "nil") executable=\(app.executableURL?.lastPathComponent ?? "nil") policy=\(app.activationPolicy.rawValue) identity=\(app.bundleIdentifier ?? "nil") running=\(helper.isRunning)")
                }
                print("PROBE_ERROR same-bundle prohibited helper not registered as expected")
                return 2
            }
            print("PRECONDITION sameBundleHelper=true differentExecutable=true policy=prohibited sameBundleIdentifier=true")
            try child.run()
            try requests.fileHandleForWriting.close()
            try responses.fileHandleForReading.close()
            let reader = ApplicationProbeLineReader(requests.fileHandleForReading)
            while let line = await reader.line() {
                guard line.hasPrefix("@") else { print(line); continue }
                let response: String
                switch line {
                case "@visible":
                    if target.isMiniaturized { target.deminiaturize(nil) }
                    if secondary.isMiniaturized { secondary.deminiaturize(nil) }
                    secondary.orderFront(nil)
                    target.makeKeyAndOrderFront(nil)
                    response = await until({ target.isVisible && !target.isMiniaturized }) ? "OK" : "FAIL"
                case "@minimized":
                    secondary.miniaturize(nil)
                    target.miniaturize(nil)
                    response = await until({ target.isMiniaturized && secondary.isMiniaturized }) ? "OK" : "FAIL"
                case "@closed":
                    secondary.close()
                    target.close()
                    response = await until({ !target.isVisible && !target.isMiniaturized }) ? "OK" : "FAIL"
                case "@hidden":
                    target.makeKeyAndOrderFront(nil)
                    NSApp.hide(nil)
                    response = await until({ NSRunningApplication.current.isHidden }) ? "OK" : "FAIL"
                case "@same-executable-instance":
                    secondInstance.executableURL = NSRunningApplication.current.executableURL
                    secondInstance.arguments = ["--verify-app-activation", "--app-probe-second-instance", String(getpid())]
                    secondInstance.standardOutput = FileHandle.nullDevice
                    try secondInstance.run()
                    let expectedExecutable = NSRunningApplication.current.executableURL?.resolvingSymlinksInPath().standardizedFileURL
                    response = await until({
                        NSWorkspace.shared.runningApplications.contains { app in
                            app.processIdentifier == secondInstance.processIdentifier
                                && app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == fixtureURL
                                && app.executableURL?.resolvingSymlinksInPath().standardizedFileURL == expectedExecutable
                                && app.activationPolicy == .regular
                                && !app.isTerminated
                        }
                    }) ? "OK" : "FAIL"
                    if response == "FAIL", let app = NSRunningApplication(processIdentifier: secondInstance.processIdentifier) {
                        print("PROBE_ERROR second-instance metadata: inWorkspace=\(NSWorkspace.shared.runningApplications.contains { $0.processIdentifier == secondInstance.processIdentifier }) bundle=\(app.bundleURL?.lastPathComponent ?? "nil") executable=\(app.executableURL?.lastPathComponent ?? "nil") policy=\(app.activationPolicy.rawValue) launched=\(app.isFinishedLaunching) launchDate=\(app.launchDate != nil) running=\(secondInstance.isRunning)")
                    }
                case "@state":
                    let state: [String: Any] = [
                        "visibleWindows": [target, secondary].filter { $0.isVisible && !$0.isMiniaturized }.count,
                        "minimizedWindows": [target, secondary].filter(\.isMiniaturized).count,
                        "keyWindow": target.isKeyWindow,
                        "fixtureHidden": NSRunningApplication.current.isHidden,
                        "reopenCallbacks": delegate.reopenCount
                    ]
                    response = String(data: try JSONSerialization.data(withJSONObject: state, options: .sortedKeys), encoding: .utf8)!
                default: response = "FAIL"
                }
                try responses.fileHandleForWriting.write(contentsOf: Data((response + "\n").utf8))
            }
            guard await until({ !child.isRunning }) else { return 2 }
            return child.terminationStatus
        } catch {
            print("PROBE_ERROR fixture communication: \(error)")
            return 2
        }
    }

    static func driver(parentPID: pid_t) async -> Int32 {
        NSApp.setActivationPolicy(.regular)
        let overlay = window("Synthetic activation driver", x: 620)
        defer { overlay.close() }
        guard await until({ NSRunningApplication.current.isFinishedLaunching }),
              let app = NSRunningApplication(processIdentifier: parentPID) else { return 2 }
        let descriptor = AppDescriptor(pid: Int(parentPID), bundleIdentifier: app.bundleIdentifier ?? "process:\(parentPID)", displayName: "Synthetic application fixture")
        let coreCandidate = CandidateFactory.makeApplicationCandidates(apps: [descriptor])[0]
        let candidate = Candidate(id: coreCandidate.id, groupID: coreCandidate.groupID, displayName: coreCandidate.displayName,
                                  target: coreCandidate.target, processLaunchDate: app.launchDate)
        let provider = RunningAppsProvider()
        let reader = ApplicationProbeLineReader(.standardInput)
        var failures = 0
        for scenario in ["visible", "minimized", "closed", "hidden"] {
            print("@\(scenario)")
            guard await reader.line() == "OK" else { print("PROBE_ERROR fixture state=\(scenario)"); return 2 }
            overlay.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            guard await until({ NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid() }) else {
                print("PROBE_ERROR driver did not become frontmost")
                return 2
            }
            let beforePID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
            let result = await provider.activate(candidate)
            try? await Task.sleep(for: .milliseconds(250))
            let afterPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
            print("@state")
            guard let line = await reader.line(), let data = line.data(using: .utf8),
                  var record = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return 2 }
            let successful = result == .success
            let visible = (record["visibleWindows"] as? Int ?? 0) > 0
            let frontmost = afterPID == parentPID
            let correctReopenCount = (record["reopenCallbacks"] as? Int) == (["visible", "minimized", "closed", "hidden"].firstIndex(of: scenario)! + 1)
            let respectsOtherWindow = scenario != "minimized" || (record["minimizedWindows"] as? Int) == 1
            let recovered = successful && frontmost && visible && correctReopenCount && respectsOtherWindow && !(record["fixtureHidden"] as? Bool ?? true)
            record["scenario"] = scenario
            record["activationReturnedSuccess"] = successful
            record["frontmostIsFixture"] = frontmost
            record["fixturePID"] = parentPID
            record["driverPID"] = getpid()
            record["beforeFrontmostPID"] = beforePID
            record["afterFrontmostPID"] = afterPID
            record["verdict"] = recovered ? "PASS" : successful && !visible ? "FAIL_SUCCESS_WITHOUT_VISIBLE_WINDOW" : "FAIL_ACTIVATION"
            if case .failure(let message) = result { record["activationFailure"] = message }
            if !recovered { failures += 1 }
            print(String(data: try! JSONSerialization.data(withJSONObject: record, options: .sortedKeys), encoding: .utf8)!)
        }

        // 真正的同安装路径、同主程序多实例仍须拒绝重开，不能靠过滤辅助进程放宽身份约束。
        print("@same-executable-instance")
        guard await reader.line() == "OK" else {
            print("PROBE_ERROR same-executable regular instance not registered as expected")
            return 2
        }
        print("PRECONDITION sameBundleSecondInstance=true sameExecutable=true policy=regular")
        print("@state")
        guard let beforeLine = await reader.line(), let beforeData = beforeLine.data(using: .utf8),
              let beforeState = (try? JSONSerialization.jsonObject(with: beforeData)) as? [String: Any],
              let beforeReopenCount = beforeState["reopenCallbacks"] as? Int else { return 2 }
        overlay.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        guard await until({ NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid() }) else { return 2 }
        let ambiguousResult = await provider.activate(candidate)
        let afterAmbiguousPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        print("@state")
        guard let afterLine = await reader.line(), let afterData = afterLine.data(using: .utf8),
              let afterState = (try? JSONSerialization.jsonObject(with: afterData)) as? [String: Any] else { return 2 }
        let rejected = ambiguousResult == .failure("这个应用有多个运行实例，无法确认要恢复哪一个。请直接选择目标窗口。")
        let noReopen = afterState["reopenCallbacks"] as? Int == beforeReopenCount
        let noActivation = afterAmbiguousPID == getpid()
        let ambiguityPassed = rejected && noReopen && noActivation
        if !ambiguityPassed { failures += 1 }
        let ambiguityRecord: [String: Any] = [
            "scenario": "same-executable-multiple-instances", "rejectedAmbiguity": rejected,
            "targetReopenCountUnchanged": noReopen, "driverRemainsFrontmost": noActivation,
            "verdict": ambiguityPassed ? "PASS" : "FAIL_AMBIGUOUS_INSTANCE"
        ]
        print(String(data: try! JSONSerialization.data(withJSONObject: ambiguityRecord, options: .sortedKeys), encoding: .utf8)!)
        print("RESULT failures=\(failures)/5; success requires exact foreground PID and visible window; ambiguous instances remain rejected")
        return failures == 0 ? 0 : 1
    }
}
