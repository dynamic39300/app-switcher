import AppKit
import ApplicationServices
import AppSwitcherCore

/// 激活候选（App 前置 + 最小化还原 + 按标题抬起指定窗口）。
enum AppActivator {
    static func activate(_ candidate: Candidate) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == candidate.groupID
        }) else {
            print("[activate] 找不到 app: \(candidate.groupID)")
            return
        }

        let sub = candidate.title.isEmpty ? "" : " | \(candidate.title)"
        print("[activate] \(candidate.displayName)\(sub) pid=\(app.processIdentifier)")

        _ = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])

        let ax = AXUIElementCreateApplication(app.processIdentifier)
        _ = AXUIElementSetAttributeValue(ax, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        // 还原最小化窗口
        var minimized: CFTypeRef?
        if AXUIElementCopyAttributeValue(ax, "AXMinimizedWindows" as CFString, &minimized) == .success,
           let mins = minimized as? [AXUIElement] {
            for w in mins {
                AXUIElementSetAttributeValue(w, "AXMinimized" as CFString, kCFBooleanFalse)
            }
        }

        // 按标题抬起指定窗口（best-effort；「窗口 N」兜底标题匹配不到时仅激活前台）
        if !candidate.title.isEmpty {
            var windows: CFTypeRef?
            if AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &windows) == .success,
               let list = windows as? [AXUIElement] {
                for w in list {
                    var t: CFTypeRef?
                    if AXUIElementCopyAttributeValue(w, "AXTitle" as CFString, &t) == .success,
                       let s = t as? String, s == candidate.title {
                        AXUIElementPerformAction(w, kAXRaiseAction as CFString)
                        AXUIElementSetAttributeValue(w, "AXMain" as CFString, kCFBooleanTrue)
                        break
                    }
                }
            }
        }
    }
}
