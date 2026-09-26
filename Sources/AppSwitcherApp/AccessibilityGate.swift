import AppKit
import ApplicationServices

/// App 模式无需 AX 权限；窗口模式在界面说明缺失权限，设置入口由用户主动打开。
@MainActor
enum AccessibilityGate {
    static func logStatus() {
        print("[permission] 辅助功能 = \(AXIsProcessTrusted())")
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
