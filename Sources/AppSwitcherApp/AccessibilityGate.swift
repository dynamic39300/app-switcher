import AppKit
import ApplicationServices

/// 辅助功能权限检测与引导。
enum AccessibilityGate {
    static func requestIfNeeded() {
        let trusted = AXIsProcessTrusted()
        print("[permission] 辅助功能 = \(trusted)")
        if !trusted {
            print("[permission] 未授权，打开「系统设置 → 隐私与安全性 → 辅助功能」")
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
