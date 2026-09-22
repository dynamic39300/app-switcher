/// 候选工厂（纯函数）：由 App 列表 + 窗口列表构建候选条目。
///
/// 规则：
/// - 只保留拥有至少一个「内容窗口」的 App（无内容窗口的后台/菜单栏 App 被排除）。
/// - 每个内容窗口展开为一个候选；同 App（groupID = bundleIdentifier）多窗口相邻。
/// - 窗口标题为空且同 App 多窗口时，副标题降级为「窗口 N」序号。
/// - 使用统计（activationCount/lastActivatedAt）按 bundleIdentifier 合并。
public enum CandidateFactory {
    public static func makeCandidates(
        apps: [AppDescriptor],
        windows: [WindowDescriptor],
        usage: [String: UsageStats] = [:]
    ) -> [Candidate] {
        let contentWindows = windows.filter { WindowFilter.isContent($0) }
        var result: [Candidate] = []

        for app in apps {
            let appWindows = contentWindows.filter { $0.pid == app.pid }
            guard !appWindows.isEmpty else { continue }

            for (index, window) in appWindows.enumerated() {
                let title: String
                if !window.title.isEmpty {
                    title = window.title
                } else if appWindows.count > 1 {
                    title = "窗口 \(index + 1)"
                } else {
                    title = ""
                }
                let stats = usage[app.bundleIdentifier]
                result.append(
                    Candidate(
                        id: "\(app.bundleIdentifier)#\(window.windowNumber)",
                        groupID: app.bundleIdentifier,
                        displayName: app.displayName,
                        title: title,
                        activationCount: stats?.activationCount ?? 0,
                        lastActivatedAt: stats?.lastActivatedAt ?? .distantPast
                    )
                )
            }
        }
        return result
    }
}
