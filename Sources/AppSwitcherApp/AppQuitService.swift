import AppKit
import AppSwitcherCore
import AppSwitcherKit

/// A quit request is bound to the process in the displayed snapshot. Never resolve
/// another instance by its name or bundle identifier after the user clicks the X.
@MainActor
final class AppQuitService {
    enum Result {
        case invalid(String)
        case requested(NSRunningApplication)
    }

    func request(_ candidate: Candidate) async -> Result {
        guard case .application(let pid) = candidate.target,
              let nativePID = pid_t(exactly: pid), nativePID > 0,
              pid != Int(ProcessInfo.processInfo.processIdentifier),
              let app = NSRunningApplication(processIdentifier: nativePID),
              !app.isTerminated,
              app.activationPolicy == .regular,
              matchesProcess(candidate, app: app),
              (app.bundleIdentifier ?? "process:\(pid)") == candidate.groupID else {
            return .invalid("应用已变化，请重新打开切换器选择。")
        }
        // Finder owns the desktop; quitting it here would look like a desktop action.
        guard app.bundleIdentifier != "com.apple.finder" else {
            return .invalid("不能从切换器退出访达。")
        }

        NSApp.yieldActivation(to: app)
        guard app.activate(options: []) else {
            return .invalid("未能切换到「\(candidate.displayName)」，请在应用中手动退出。")
        }
        let foregroundDeadline = ContinuousClock.now.advanced(by: .seconds(1.2))
        while NSWorkspace.shared.frontmostApplication?.processIdentifier != nativePID {
            guard ContinuousClock.now < foregroundDeadline else {
                return .invalid("未能确认「\(candidate.displayName)」已到前台，请在应用中手动退出。")
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard !app.isTerminated, matchesProcess(candidate, app: app),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == nativePID else {
            return .invalid("应用已变化，请重新打开切换器选择。")
        }
        guard app.terminate() else {
            return .invalid("未能请求退出「\(candidate.displayName)」，请在应用中手动退出。")
        }
        return .requested(app)
    }

    private func matchesProcess(_ candidate: Candidate, app: NSRunningApplication) -> Bool {
        guard let expectedStart = candidate.processStartTimestamp,
              ProcessStartTimestamp.read(pid: candidate.target.pid) == expectedStart else { return false }
        if let expectedLaunch = candidate.processLaunchDate {
            return app.launchDate == expectedLaunch
        }
        return true
    }
}
