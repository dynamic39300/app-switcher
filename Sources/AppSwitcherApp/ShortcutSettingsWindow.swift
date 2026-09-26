import AppKit
import SwiftUI
import AppSwitcherCore

/// The recorder sees only key-down events addressed to this key window.
/// Registration and persistence remain the owner's responsibility.
@MainActor
final class ShortcutSettingsWindow: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let model: ShortcutSettingsModel
    private let onBeginRecording: () -> String?
    private let onEndRecording: () -> String?
    private let onSave: (ShortcutPreferences) -> String?
    private let onSavedWarning: () -> String?
    private let onClose: () -> Void
    private var keyMonitor: Any?
    private var didClose = false

    init(
        preferences: ShortcutPreferences,
        status: String?,
        onBeginRecording: @escaping () -> String?,
        onEndRecording: @escaping () -> String?,
        onSave: @escaping (ShortcutPreferences) -> String?,
        onSavedWarning: @escaping () -> String? = { nil },
        onClose: @escaping () -> Void
    ) {
        self.model = ShortcutSettingsModel(preferences: preferences, status: status)
        self.onBeginRecording = onBeginRecording
        self.onEndRecording = onEndRecording
        self.onSave = onSave
        self.onSavedWarning = onSavedWarning
        self.onClose = onClose
        self.window = NSWindow(
            contentRect: NSRect(origin: .zero, size: ShortcutSettingsView.size),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false
        )
        super.init()
        window.title = "AppSwitcher 快捷键设置"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(OverlayTheme.background)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: ShortcutSettingsView(
            model: model,
            onRecord: { [weak self] in self?.toggleRecording() },
            onDefaults: { [weak self] in self?.restoreDefaults() },
            onSave: { [weak self] in self?.save() },
            onCancel: { [weak self] in self?.close() }
        ))
    }

    var isVisible: Bool { window.isVisible }

    func show() {
        guard !didClose else { return }
        if !window.isVisible { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard !didClose else { return }
        window.performClose(nil)
    }

    private func toggleRecording() {
        guard window.isKeyWindow, !didClose else { return }
        if model.isRecording {
            if endRecording() == nil { model.showFeedback("已取消录制，草稿保持不变。", isError: false) }
            return
        }
        if let error = onBeginRecording() {
            model.showFeedback(error, isError: true)
            return
        }
        model.feedback = nil
        model.isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.model.isRecording, self.window.isKeyWindow,
                  event.window === self.window else { return event }
            self.record(event)
            return nil
        }
        // A failed monitor must not leave the global shortcuts suspended.
        if keyMonitor == nil {
            let restorationError = endRecording()
            model.showFeedback(restorationError ?? "暂时无法开始录制，请重新打开设置后重试。", isError: true)
        }
    }

    private func record(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        if event.keyCode == 53 {
            if endRecording() == nil { model.showFeedback("已取消录制，草稿保持不变。", isError: false) }
            return
        }
        var modifiers: ShortcutModifiers = []
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        let shortcut = AppShortcut(keyCode: event.keyCode, modifiers: modifiers)
        if let validation = shortcut.validationMessage {
            model.showFeedback(validation, isError: true)
            return
        }
        model.draftShortcut = shortcut
        if endRecording() == nil { model.showFeedback("已录入草稿，保存后生效。", isError: false) }
    }

    @discardableResult
    private func endRecording() -> String? {
        guard model.isRecording else { return nil }
        model.isRecording = false
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        let error = onEndRecording()
        if let error { model.showFeedback(error, isError: true) }
        return error
    }

    private func restoreDefaults() {
        let restorationError = endRecording()
        model.draftShortcut = ShortcutPreferences.default.hotKey
        model.sequenceEnabled = ShortcutPreferences.default.sequenceEnabled
        if restorationError == nil { model.showFeedback("已恢复默认草稿，保存后生效。", isError: false) }
    }

    private func save() {
        guard !model.isRecording else { return }
        if let validation = model.draftShortcut.validationMessage {
            model.showFeedback(validation, isError: true)
            return
        }
        let preferences = model.draftPreferences
        if let error = onSave(preferences) {
            model.showFeedback(error, isError: true)
            return
        }
        model.savedPreferences = preferences
        if let warning = onSavedWarning() {
            model.showFeedback("设置已保存。\(warning)", isError: true)
        } else {
            model.showFeedback("已保存，新的唤出设置已生效。", isError: false)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if model.isRecording, endRecording() == nil {
            model.showFeedback("录制已停止。点击录制按钮可继续设置。", isError: false)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Keep the error visible instead of immediately discarding a failed restoration.
        endRecording() == nil
    }

    func windowWillClose(_ notification: Notification) {
        guard !didClose else { return }
        endRecording()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        didClose = true
        onClose()
    }
}

@MainActor
private final class ShortcutSettingsModel: ObservableObject {
    @Published var savedPreferences: ShortcutPreferences
    @Published var draftShortcut: AppShortcut
    @Published var sequenceEnabled: Bool
    @Published var isRecording = false
    @Published var feedback: String?
    @Published var feedbackIsError = false

    init(preferences: ShortcutPreferences, status: String?) {
        savedPreferences = preferences
        draftShortcut = preferences.hotKey
        sequenceEnabled = preferences.sequenceEnabled
        feedback = status
        feedbackIsError = status != nil
    }

    var draftPreferences: ShortcutPreferences {
        ShortcutPreferences(hotKey: draftShortcut, sequenceEnabled: sequenceEnabled)
    }

    var hasChanges: Bool {
        draftShortcut.keyCode != savedPreferences.hotKey.keyCode
            || draftShortcut.modifiers != savedPreferences.hotKey.modifiers
            || sequenceEnabled != savedPreferences.sequenceEnabled
    }

    func showFeedback(_ text: String, isError: Bool) {
        feedback = text
        feedbackIsError = isError
    }
}

@MainActor
private struct ShortcutSettingsView: View {
    static let size = CGSize(width: 560, height: 600)
    @ObservedObject var model: ShortcutSettingsModel
    let onRecord: () -> Void
    let onDefaults: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                Image(systemName: "keyboard")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(OverlayTheme.primary)
                    .frame(width: 48, height: 48)
                    .background(OverlayTheme.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("快捷键").font(.system(size: 23, weight: .semibold)).foregroundStyle(OverlayTheme.text)
                    Text("用顺手的组合唤出 AppSwitcher")
                        .font(.system(size: 12)).foregroundStyle(OverlayTheme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("唤出面板").font(.system(size: 13, weight: .semibold)).foregroundStyle(OverlayTheme.text)
                    Spacer()
                    Text("已保存  \(model.savedPreferences.hotKey.displayName)")
                        .font(.system(size: 11)).foregroundStyle(OverlayTheme.secondaryText)
                }
                Button(action: onRecord) {
                    VStack(spacing: 8) {
                        Text(model.isRecording ? "请按下新的组合键" : model.draftShortcut.displayName)
                            .font(.system(size: model.isRecording ? 20 : 29, weight: .medium, design: .rounded))
                            .foregroundStyle(model.isRecording ? OverlayTheme.primary : OverlayTheme.text)
                        HStack(spacing: 6) {
                            Image(systemName: model.isRecording ? "record.circle" : "pencil")
                            Text(model.isRecording ? "正在录制 · Esc 取消" : "点击录制新的快捷键")
                        }
                        .font(.system(size: 11)).foregroundStyle(OverlayTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(model.isRecording ? OverlayTheme.surfaceSelected : OverlayTheme.surface,
                                in: RoundedRectangle(cornerRadius: 13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(model.isRecording ? OverlayTheme.primary : (contrast == .increased ? Color.white.opacity(0.6) : OverlayTheme.border),
                                          lineWidth: model.isRecording ? 1.5 : 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isRecording ? "正在录制快捷键，点击或按 Esc 取消" : "录制唤出快捷键，当前草稿 \(model.draftShortcut.displayName)")
                Text("需包含 ⌘、⌃、⌥ 中至少一个修饰键，可同时使用 ⇧。")
                    .font(.system(size: 11)).foregroundStyle(OverlayTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("快速手势  F → J")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(OverlayTheme.text)
                    Text("依次按 F、J 唤出面板，需要输入监控权限。")
                        .font(.system(size: 11)).foregroundStyle(OverlayTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("启用 F → J", isOn: Binding(
                    get: { model.sequenceEnabled },
                    set: { value in
                        model.sequenceEnabled = value
                        if !model.feedbackIsError { model.feedback = nil }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(OverlayTheme.primary)
                .disabled(model.isRecording)
                .accessibilityLabel("启用 F 然后 J 唤出面板")
            }
            .padding(15)
            .background(OverlayTheme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: model.feedbackIsError ? "exclamationmark.circle" : "info.circle")
                Text(model.feedback ?? (model.hasChanges ? "有未保存的修改。保存后，新设置会立即生效。" : "修改仅保存在本机，关闭窗口不会保存草稿。"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 11))
            .foregroundStyle(model.feedbackIsError ? OverlayTheme.warning : OverlayTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)
            Rectangle().fill(OverlayTheme.border).frame(height: 1)
            HStack(spacing: 12) {
                Button(action: onDefaults) {
                    Label("恢复默认", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(OverlayTheme.secondaryText)
                .help("恢复默认草稿，保存后生效")
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("保存", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(OverlayTheme.primary)
                    .disabled(model.isRecording || model.draftShortcut.validationMessage != nil)
            }
            .controlSize(.regular)
            .font(.system(size: 12))
        }
        .padding(24)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(OverlayTheme.background)
        .preferredColorScheme(.dark)
    }
}

/// Synthetic settings states; no event monitors, hotkey registration, or user-window capture.
@MainActor
enum ShortcutSettingsPreview {
    static func render(to directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let normal = ShortcutSettingsModel(preferences: .default, status: nil)
        let recording = ShortcutSettingsModel(preferences: .default, status: nil)
        recording.isRecording = true
        let error = ShortcutSettingsModel(preferences: .default, status: "这个快捷键已被系统或其他应用使用，请录制其他组合。")
        error.draftShortcut = AppShortcut(keyCode: 40, modifiers: [.control, .option])
        let draft = ShortcutSettingsModel(preferences: .default, status: nil)
        draft.draftShortcut = AppShortcut(keyCode: 40, modifiers: [.control, .option])
        draft.sequenceEnabled = false
        return try [("01-settings", normal), ("02-recording", recording), ("03-conflict", error), ("04-draft", draft)].map { name, model in
            let view = ShortcutSettingsView(model: model, onRecord: {}, onDefaults: {}, onSave: {}, onCancel: {})
            let host = NSHostingView(rootView: view)
            host.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: ShortcutSettingsView.size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            host.frame = NSRect(origin: .zero, size: ShortcutSettingsView.size)
            defer { window.contentView = nil; window.close() }
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.08))
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                throw NSError(domain: "ShortcutSettingsPreview", code: 1)
            }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "ShortcutSettingsPreview", code: 2)
            }
            let url = directory.appendingPathComponent(name).appendingPathExtension("png")
            try png.write(to: url, options: .atomic)
            return url
        }
    }
}
