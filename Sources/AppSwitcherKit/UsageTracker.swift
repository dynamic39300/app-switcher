import AppKit
import AppSwitcherCore

/// 低频轮询前台下 App，累计激活次数/最近激活时间。
@MainActor
public final class UsageTracker {
    private let store: UsageStore
    private var stats: [String: UsageStats]
    private var timer: Timer?
    private var lastBundleIdentifier: String?

    public init(store: UsageStore) {
        self.store = store
        self.stats = store.load()
    }

    public func start(interval: TimeInterval = 1.0) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              let bundle = front.bundleIdentifier else { return }
        guard bundle != lastBundleIdentifier else { return }

        var current = stats[bundle] ?? UsageStats()
        current.activationCount += 1
        current.lastActivatedAt = Date()
        stats[bundle] = current
        lastBundleIdentifier = bundle
        try? store.save(stats)
    }
}
