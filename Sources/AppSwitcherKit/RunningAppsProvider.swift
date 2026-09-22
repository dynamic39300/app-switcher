import AppKit
import CoreGraphics
import AppSwitcherCore

/// 运行态枚举适配器：NSWorkspace + CGWindowList → 纯值类型。
/// 把 spike 里验证过的逻辑落成正式实现；本身很薄，纯逻辑在 Core 的 WindowFilter/CandidateFactory。
public struct RunningAppsProvider {
    public init() {}

    /// 当前运行中的 `.regular` App（排除指定 pid，通常为本应用自身）。
    public func runningApps(excluding pid: Int) -> [AppDescriptor] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && Int($0.processIdentifier) != pid }
            .compactMap { app -> AppDescriptor? in
                guard let bundle = app.bundleIdentifier else { return nil }
                return AppDescriptor(
                    pid: Int(app.processIdentifier),
                    bundleIdentifier: bundle,
                    displayName: app.localizedName ?? bundle
                )
            }
    }

    /// 全系统窗口（CGWindowList，归一化为 WindowDescriptor）。
    public func windows() -> [WindowDescriptor] {
        guard let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { info -> WindowDescriptor? in
            guard let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let number = (info[kCGWindowNumber as String] as? NSNumber)?.intValue else {
                return nil
            }
            let title = info[kCGWindowName as String] as? String ?? ""
            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0
            var width = 0.0, height = 0.0
            if let bounds = info[kCGWindowBounds as String] as? [String: Any] {
                width = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
                height = (bounds["Height"] as? NSNumber)?.doubleValue ?? 0
            }
            return WindowDescriptor(
                pid: Int(pid), title: title, windowNumber: number,
                layer: layer, alpha: alpha, width: width, height: height
            )
        }
    }

    /// 组合：App 列表 + 窗口列表 + 使用统计 → 候选条目。
    public func candidates(excluding pid: Int, usage: [String: UsageStats]) -> [Candidate] {
        let apps = runningApps(excluding: pid)
        let windows = self.windows()
        return CandidateFactory.makeCandidates(apps: apps, windows: windows, usage: usage)
    }
}
