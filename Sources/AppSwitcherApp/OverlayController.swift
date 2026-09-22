import Foundation
import AppSwitcherCore
import AppSwitcherKit

/// 编排：热键 → 收集候选 → rank → 分配键位 → 显示覆盖层；按键 → 激活；取消 → 收起。
final class OverlayController {
    private let provider: RunningAppsProvider
    private let usage: UsageStore
    private let panel = OverlayPanel()

    init(provider: RunningAppsProvider, usage: UsageStore) {
        self.provider = provider
        self.usage = usage
        panel.onKey = { [weak self] key in self?.activate(key) }
        panel.onCancel = { [weak self] in self?.panel.hide(restorePrevious: true) }
    }

    func toggle() {
        if panel.isVisible {
            panel.hide(restorePrevious: true)
        } else {
            show()
        }
    }

    private func show() {
        let stats = usage.load()
        let candidates = provider.candidates(
            excluding: Int(ProcessInfo.processInfo.processIdentifier),
            usage: stats
        )
        let ranked = AppRanker.rank(candidates)
        let keyMap = KeyAssigner.assign(ranked)
        print("[overlay] 候选 \(ranked.count) 条，键位 \(keyMap.count) 个")
        panel.show(keyMap: keyMap)
    }

    private func activate(_ key: Key) {
        guard let candidate = panel.keyMap[key] else { return }
        panel.hide(restorePrevious: false)
        AppActivator.activate(candidate)
    }
}
