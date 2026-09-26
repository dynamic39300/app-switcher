import AppKit
import AppSwitcherCore
import AppSwitcherKit

/// 设置提交先保留旧注册，落盘成功才切换；录制只临时释放已保存的组合。
@MainActor
final class ShortcutController {
    private let store: ShortcutStore
    private let hotKey = GlobalHotKey.shared
    private var configurationWarning: String?
    private(set) var preferences: ShortcutPreferences = .default
    private(set) var statusMessage: String?
    private(set) var isRecording = false
    var onChange: (() -> Void)?

    init(fileURL: URL) {
        store = ShortcutStore(fileURL: fileURL)
    }

    func start() {
        do {
            preferences = try store.load() ?? .default
        } catch {
            configurationWarning = "快捷键配置无法读取，暂用默认设置。保存后可修复配置。"
        }
        do {
            try hotKey.replace(with: preferences.hotKey)
        } catch {
            statusMessage = "\(preferences.hotKey.displayName) 暂不可用：\(error.localizedDescription) 可从菜单栏打开快捷键设置。"
        }
        applySequencePreference()
    }

    var menuSummary: String {
        let combination = hotKey.isSuspended ? "快捷键已暂停" : (hotKey.currentShortcut?.displayName ?? "快捷键不可用")
        return preferences.sequenceEnabled && SequenceHotKey.shared.isRunning ? "F → J 或 \(combination) 唤出" : "\(combination) 唤出"
    }

    var availabilityWarning: String? {
        guard preferences.sequenceEnabled, !SequenceHotKey.shared.isRunning else { return nil }
        return "F → J 尚不可用，请在系统设置的输入监控中允许 AppSwitcher，随后重启。组合快捷键不受影响。"
    }

    var settingsStatus: String? {
        let messages = [configurationWarning, statusMessage, availabilityWarning].compactMap { $0 }
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }

    func beginRecording() -> String? {
        guard !isRecording else { return nil }
        do {
            try hotKey.suspend()
            SequenceHotKey.shared.recordingSuspended = true
            isRecording = true
            return nil
        } catch {
            return "暂时无法开始录制：\(error.localizedDescription)"
        }
    }

    func endRecording() -> String? {
        guard isRecording else { return statusMessage }
        isRecording = false
        SequenceHotKey.shared.recordingSuspended = false
        do {
            try hotKey.resume()
            if hotKey.currentShortcut != nil { statusMessage = nil }
        } catch {
            statusMessage = "原快捷键恢复失败：\(error.localizedDescription) 请保存一个可用的新组合。"
        }
        onChange?()
        return statusMessage
    }

    func save(_ proposed: ShortcutPreferences) -> String? {
        guard !isRecording else { return "请先完成或取消快捷键录制。" }
        do {
            try hotKey.replace(with: proposed.hotKey, persist: { try store.save(proposed) })
            preferences = proposed
            configurationWarning = nil
            statusMessage = nil
            applySequencePreference()
            onChange?()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func applySequencePreference() {
        if preferences.sequenceEnabled { SequenceHotKey.shared.start() }
        else { SequenceHotKey.shared.stop() }
    }
}
