import AppKit
import SwiftUI
import AppSwitcherCore

@MainActor
final class CommerceAccountWindow {
    private let window: NSWindow
    init(model: CommerceController) {
        let view = CommerceAccountView(model: model)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 550, height: 610),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "AppSwitcher · 账号与授权"
        window.contentView = NSHostingView(rootView: view)
        window.minSize = NSSize(width: 470, height: 540)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("AppSwitcherAccountWindow")
        window.center()
        self.window = window
    }
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private enum CommerceTheme {
    static let spacing: CGFloat = 20
    static let corner: CGFloat = 16
    static let accent = Color.accentColor
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let secondary = Color.secondary
}

private struct CommerceAccountView: View {
    @ObservedObject var model: CommerceController

    private var status: (String, String, String) {
        switch model.access {
        case .local: return ("本地开发版", "当前安装包保持本地使用方式。正式版本会提供官网账号与购买入口。", "hammer")
        case .signedOut: return ("让切换成为习惯", "登录后可开启 14 天全功能试用。一个账号可在多台设备使用，无需绑定付款方式。", "keyboard")
        case .eligible: return ("准备好开始了吗？", "试用从你点击开始时连续计时 14 天。注册、下载和登录均不消耗试用时间。", "sparkles")
        case .trial: return ("正在试用全功能", "所有快捷键与窗口切换功能均已开放。提前购买会保留剩余试用时间。", "clock")
        case .paid: return ("授权已生效", "感谢支持 AppSwitcher。提前续费会保留剩余期限，无自动扣款。", "checkmark.seal")
        case .expired: return ("本期使用期限已结束", "购买后同步权益即可继续切换。快捷键、偏好与订单全部保留。", "calendar.badge.clock")
        case .needsVerification: return ("请联网同步授权", "本机授权需要重新验证。如已在网页购买，无需重复付款；同步后即可恢复。", "arrow.triangle.2.circlepath")
        case .unavailable: return ("账号服务暂不可用", "请检查安装包或系统钥匙串。你仍可保留现有快捷键设置，稍后重新启动。", "exclamationmark.shield")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CommerceTheme.spacing) {
                HStack(spacing: 12) {
                    Image(systemName: "keyboard").font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(CommerceTheme.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AppSwitcher").font(.title2.bold())
                        Text("少一点寻找，多一点专注").foregroundStyle(CommerceTheme.secondary)
                    }
                    Spacer()
                    if model.busy { ProgressView().controlSize(.small).accessibilityLabel("正在处理") }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Label(status.0, systemImage: status.2).font(.title2.bold())
                    Text(status.1).foregroundStyle(CommerceTheme.secondary).fixedSize(horizontal: false, vertical: true)
                    if let email = model.accountEmail {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前账号").font(.caption).foregroundStyle(CommerceTheme.secondary)
                            Text(email).font(.callout).lineLimit(3).truncationMode(.middle).textSelection(.enabled)
                        }
                    }
                    if let expiry = model.validUntil {
                        LabeledContent("权益到期", value: date(expiry)).textSelection(.enabled)
                    }
                    if let expiry = model.localUntil, model.access.allowsSwitching {
                        LabeledContent("本机验证有效至", value: date(expiry)).font(.callout).foregroundStyle(CommerceTheme.secondary)
                    }
                    mainActions
                    if let reminder = model.renewalHint {
                        Label(reminder, systemImage: "calendar").font(.callout)
                            .foregroundStyle(CommerceTheme.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CommerceTheme.surface, in: RoundedRectangle(cornerRadius: CommerceTheme.corner))

                if let message = model.message {
                    Text(message).font(.callout).foregroundStyle(CommerceTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("处理结果：" + message)
                }
                if let release = model.update {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("新版本 \(release.version ?? "")").font(.headline)
                        Text(String(release.notes.prefix(1500))).font(.callout).foregroundStyle(CommerceTheme.secondary)
                        Button("前往官网下载更新") { model.openDownload() }.disabled(model.busy)
                    }
                }
                if model.access == .eligible || model.access == .signedOut {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("开始使用前").font(.headline)
                        Text("选择一个顺手的唤出快捷键。需要精确切换应用内窗口时，再允许辅助功能访问；不会读取屏幕内容。")
                            .font(.callout).foregroundStyle(CommerceTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("快捷键设置") { model.openShortcutSettings() }
                            Button("辅助功能设置") { model.openAccessibilitySettings() }
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button("账号与订单") { model.openAccount() }
                        Button("帮助与反馈") { model.openSupport() }
                        Spacer()
                        Button("检查更新") { model.checkUpdates() }.disabled(model.busy)
                    }
                    .disabled(!model.isCommercial)
                    HStack {
                        Text("本地切换 · 不上传窗口标题或按键内容")
                            .font(.caption).foregroundStyle(CommerceTheme.secondary)
                        Spacer()
                        if model.isSignedIn {
                            Button("退出账号") { model.signOut() }.disabled(model.busy)
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 430, minHeight: 480)
    }

    @ViewBuilder private var mainActions: some View {
        HStack(spacing: 12) {
            if !model.isSignedIn && model.isCommercial {
                Button("浏览器登录 / 注册") { model.signIn() }.buttonStyle(.borderedProminent)
            } else if model.access == .eligible {
                Button("开始 14 天试用") { model.startTrial() }.buttonStyle(.borderedProminent)
                Button("查看套餐") { model.openPurchase() }
            } else if model.isSignedIn {
                Button("同步已购权益") { model.synchronize() }.buttonStyle(.borderedProminent)
                Button(model.access == .paid ? "提前续费" : "查看套餐") { model.openPurchase() }
            }
        }
        .controlSize(.large)
        .disabled(model.busy || model.access == .unavailable)
    }

    private func date(_ timestamp: Int64) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm（北京时间）"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}

#if DEBUG
/// Offscreen, synthetic account states; does not start login, touch Keychain, register keys or read apps.
@MainActor
enum CommerceAccountPreview {
    static func render(to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cases: [(String, CommerceAccess, CGFloat, Bool)] = [
            ("01-sign-in", .signedOut, 550, false), ("02-trial-ready", .eligible, 550, false),
            ("03-trial", .trial, 550, false), ("04-paid", .paid, 550, false),
            ("05-expired", .expired, 550, false), ("06-offline", .needsVerification, 550, false),
            ("07-unavailable", .unavailable, 550, false), ("08-narrow-long-email", .paid, 470, true)
        ]
        return try cases.map { name, access, width, longText in
            let model = CommerceController(preview: access, longText: longText)
            let size = NSSize(width: width, height: 610)
            let host = NSHostingView(rootView: CommerceAccountView(model: model))
            host.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = host
            host.frame = NSRect(origin: .zero, size: size)
            defer { window.contentView = nil; window.close() }
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.08))
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                throw CommerceFailure.response
            }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CommerceFailure.response }
            let url = directory.appendingPathComponent(name).appendingPathExtension("png")
            try png.write(to: url, options: .atomic)
            return url
        }
    }
}
#endif
