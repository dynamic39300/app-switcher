import Foundation

/// 候选策略不依赖平台 API。默认每个进程一个应用入口；窗口模式只展开完整、可辨认、可操作的快照。
public enum CandidateFactory {
    public static func makeApplicationCandidates(
        apps: [AppDescriptor],
        usage: [String: UsageStats] = [:]
    ) -> [Candidate] {
        apps.map { application($0, windowCount: 0, usage: usage) }
    }

    public static func makeWindowCandidates(
        apps: [AppDescriptor],
        windows: [WindowDescriptor],
        unavailablePIDs: Set<Int> = [],
        usage: [String: UsageStats] = [:]
    ) -> [Candidate] {
        apps.flatMap { app -> [Candidate] in
            let appWindows = windows.filter { $0.pid == app.pid }
            let titles = appWindows.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            let normalizedTitles = titles.map { $0.precomposedStringWithCanonicalMapping }
            let tokens = appWindows.compactMap(\.targetToken)
            let canExpand = !unavailablePIDs.contains(app.pid)
                && !appWindows.isEmpty
                && titles.allSatisfy { !$0.isEmpty }
                && Set(normalizedTitles).count == appWindows.count
                && tokens.count == appWindows.count
                && tokens.allSatisfy { !$0.isEmpty }
                && Set(tokens).count == appWindows.count
                && appWindows.allSatisfy { $0.canRaise && $0.canSetMain }

            guard canExpand else {
                return [application(app, windowCount: appWindows.count, usage: usage)]
            }
            let stats = usage[app.bundleIdentifier]
            // 不使用系统 z-order、随机 token 或重新编号作为展示顺序。
            return appWindows.sorted { $0.title < $1.title }.map { window in
                let token = window.targetToken!
                return Candidate(
                    id: "\(app.bundleIdentifier)#window:\(app.pid):\(token)",
                    groupID: app.bundleIdentifier,
                    displayName: app.displayName,
                    title: window.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    activationCount: stats?.activationCount ?? 0,
                    lastActivatedAt: stats?.lastActivatedAt ?? .distantPast,
                    target: .window(pid: app.pid, token: token),
                    windowCount: appWindows.count
                )
            }
        }
    }

    /// 保留旧入口；只有 CG 描述的窗口不会伪装为可精确切换的窗口。
    public static func makeCandidates(
        apps: [AppDescriptor],
        windows: [WindowDescriptor],
        usage: [String: UsageStats] = [:]
    ) -> [Candidate] {
        makeWindowCandidates(apps: apps, windows: windows, usage: usage)
    }

    private static func application(
        _ app: AppDescriptor, windowCount: Int, usage: [String: UsageStats]
    ) -> Candidate {
        let stats = usage[app.bundleIdentifier]
        return Candidate(
            id: "\(app.bundleIdentifier)#app:\(app.pid)",
            groupID: app.bundleIdentifier,
            displayName: app.displayName,
            activationCount: stats?.activationCount ?? 0,
            lastActivatedAt: stats?.lastActivatedAt ?? .distantPast,
            target: .application(pid: app.pid),
            windowCount: windowCount
        )
    }
}
