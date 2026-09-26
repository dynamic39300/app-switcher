import AppSwitcherCore
import AppSwitcherKit

/// 激活统一交给持有当前窗口快照的 provider；此处不按标题重新查找窗口。
@MainActor
enum AppActivator {
    static func activate(_ candidate: Candidate, using provider: RunningAppsProvider) async -> ActivationResult {
        await provider.activate(candidate)
    }
}
