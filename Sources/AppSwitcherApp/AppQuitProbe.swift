import AppKit
import AppSwitcherCore
import AppSwitcherKit

@MainActor
private final class QuitProbeDelegate: NSObject, NSApplicationDelegate {
    private var requestCount = 0

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        requestCount += 1
        // The first request emulates a target app cancelling at its save dialog.
        return requestCount == 1 ? .terminateCancel : .terminateNow
    }
}

/// Uses a temporary, regular app bundle. No installed or user-owned app is targeted.
@MainActor
enum AppQuitProbe {
    private static var fixtureDelegate: QuitProbeDelegate?
    private static var fixtureWindow: NSWindow?

    static func startFixture() {
        NSApp.setActivationPolicy(.regular)
        let delegate = QuitProbeDelegate()
        fixtureDelegate = delegate
        NSApp.delegate = delegate
        let window = NSWindow(contentRect: NSRect(x: 180, y: 240, width: 430, height: 230),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Synthetic quit probe"
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(NSTextField(labelWithString: "Synthetic application; first quit cancels"))
        fixtureWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func run() async -> Int {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppSwitcher-quit-" + UUID().uuidString)
        let bundle = root.appendingPathComponent("QuitFixture.app")
        let executable = bundle.appendingPathComponent("Contents/MacOS/QuitFixture")
        let process = Process()
        let previous = NSWorkspace.shared.frontmostApplication
        defer {
            let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if process.isRunning { process.terminate() }
            if frontmost == process.processIdentifier || frontmost == getpid() {
                _ = previous?.activate(options: [])
            }
            try? FileManager.default.removeItem(at: root)
        }
        do {
            try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: URL(fileURLWithPath: CommandLine.arguments[0]), to: executable)
            let identity = "local.appswitcher.quitprobe." + UUID().uuidString.lowercased()
            let info: [String: Any] = [
                "CFBundleIdentifier": identity, "CFBundleName": "Synthetic Quit Fixture",
                "CFBundleExecutable": "QuitFixture", "CFBundlePackageType": "APPL"
            ]
            let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try plist.write(to: bundle.appendingPathComponent("Contents/Info.plist"))
            process.executableURL = executable
            process.arguments = ["--quit-probe-fixture"]
            process.standardOutput = FileHandle.nullDevice
            try process.run()
            guard await until({
                NSWorkspace.shared.runningApplications.contains { $0.processIdentifier == process.processIdentifier &&
                    $0.activationPolicy == .regular && $0.bundleIdentifier == identity && $0.isFinishedLaunching }
            }), let app = NSRunningApplication(processIdentifier: process.processIdentifier),
                  let start = ProcessStartTimestamp.read(pid: Int(process.processIdentifier)) else {
                if let app = NSRunningApplication(processIdentifier: process.processIdentifier) {
                    print("PROBE app-quit: running=\(process.isRunning) policy=\(app.activationPolicy.rawValue) bundle=\(app.bundleIdentifier ?? "nil") launch=\(app.launchDate != nil) inWorkspace=\(NSWorkspace.shared.runningApplications.contains { $0.processIdentifier == process.processIdentifier })")
                } else { print("PROBE app-quit: running=\(process.isRunning) app=nil") }
                print("FAIL app-quit: fixture did not register as a regular application")
                return 2
            }
            let candidate = Candidate(id: "quit-probe", groupID: identity, displayName: "Synthetic Quit Fixture",
                                      target: .application(pid: Int(process.processIdentifier)), processLaunchDate: app.launchDate,
                                      processStartTimestamp: start)
            let service = AppQuitService()
            let stale = Candidate(id: candidate.id, groupID: candidate.groupID, displayName: candidate.displayName,
                                  target: candidate.target, processLaunchDate: candidate.processLaunchDate,
                                  processStartTimestamp: start - 1)
            guard case .invalid = await service.request(stale), process.isRunning else {
                print("FAIL app-quit: stale process snapshot was not rejected")
                return 1
            }
            print("PASS app-quit: stale process start rejected without terminating target")
            let wrongIdentity = Candidate(id: candidate.id, groupID: "wrong.bundle", displayName: candidate.displayName,
                                          target: candidate.target, processLaunchDate: candidate.processLaunchDate,
                                          processStartTimestamp: start)
            guard case .invalid = await service.request(wrongIdentity), process.isRunning else {
                print("FAIL app-quit: wrong bundle identity was not rejected")
                return 1
            }
            print("PASS app-quit: wrong bundle identity rejected")
            let firstRequest = await service.request(candidate)
            guard case .requested = firstRequest else {
                if case .invalid(let reason) = firstRequest { print("PROBE app-quit: \(reason)") }
                print("FAIL app-quit: normal quit request was not accepted")
                return 1
            }
            try? await Task.sleep(for: .milliseconds(450))
            guard process.isRunning, !app.isTerminated else {
                print("FAIL app-quit: target did not cancel its first quit request")
                return 1
            }
            print("PASS app-quit: request accepted while application remains running after cancel")
            let notice = QuitNoticePanel()
            notice.show("合成应用尚未退出。", duration: .seconds(2))
            try? await Task.sleep(for: .milliseconds(150))
            let stillForeground = NSWorkspace.shared.frontmostApplication?.processIdentifier == process.processIdentifier
            let noticeVisible = notice.isVisible
            notice.hide()
            guard stillForeground, noticeVisible else {
                print("PROBE app-quit notice: visible=\(noticeVisible) frontmost=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1) target=\(process.processIdentifier)")
                print("FAIL app-quit: status notice was hidden or stole focus from the target application")
                return 1
            }
            print("PASS app-quit: status notice does not take focus from the target")
            guard case .requested = await service.request(candidate), await until({ !process.isRunning || app.isTerminated }) else {
                print("FAIL app-quit: second quit did not finish")
                return 1
            }
            print("PASS app-quit: second request terminated the exact process")
            return 0
        } catch {
            print("FAIL app-quit: unable to create isolated fixture: \(error.localizedDescription)")
            return 2
        }
    }

    private static func until(_ predicate: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !predicate() {
            guard ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return true
    }
}
