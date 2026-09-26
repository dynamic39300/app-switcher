import AppKit
import ApplicationServices
import AppSwitcherCore
import AppSwitcherKit

/// Session generation prevents late AX results from changing a newer keyboard snapshot.
@MainActor
final class OverlayController {
    private let provider: RunningAppsProvider
    private let usage: UsageStore
    private let panel = OverlayPanel()
    private var mode: OverlayMode = .applications
    private var appCandidates: [Candidate] = []
    private var loadTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var generation = 0
    private var isActivating = false
    private var isLoading = false
    private var pendingMessage: String?
    var onSettings: (() -> Void)?
    var canBeginSwitch: (() -> Bool)?

    init(provider: RunningAppsProvider, usage: UsageStore) {
        self.provider = provider
        self.usage = usage
        panel.onKey = { [weak self] key in self?.activate(key) }
        panel.onCancel = { [weak self] restore in self?.dismiss(restore: restore) }
        panel.onToggleMode = { [weak self] in self?.toggleMode() }
        panel.onSettings = { [weak self] in self?.onSettings?() }
    }

    func toggle() {
        guard !isActivating else { return }
        if panel.isVisible { dismiss(restore: true) }
        else if canBeginSwitch?() ?? true { show() }
    }

    func dismissForSettings() {
        if panel.isVisible { dismiss(restore: false) }
    }

    private func dismiss(restore: Bool) {
        generation += 1
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        SequenceHotKey.shared.suspended = false
        panel.hide(restorePrevious: restore)
        appCandidates = []
        invalidateSnapshot()
    }

    private func invalidateSnapshot() {
        let previous = cleanupTask
        cleanupTask = Task { [provider] in
            await previous?.value
            await provider.invalidateWindowSnapshot()
        }
    }

    private func show(message: String? = nil, rememberPrevious: Bool = true) {
        generation += 1
        mode = .applications
        isLoading = false
        SequenceHotKey.shared.suspended = true
        appCandidates = provider.candidates(excluding: Int(ProcessInfo.processInfo.processIdentifier), usage: usage.load())
        let feedback = message ?? pendingMessage
        pendingMessage = nil
        panel.show(keyMap: mapping(appCandidates), mode: mode, message: combinedMessage(feedback, candidates: appCandidates), rememberPrevious: rememberPrevious)
    }

    private func combinedMessage(_ message: String?, candidates: [Candidate]) -> String? {
        var messages = [message].compactMap { $0 }
        if candidates.count > Key.all.count {
            let suffix = mode == .windows ? "切换应用模式可减少窗口占位。" : "关闭暂不需要的应用可减少目标。"
            messages.append("当前显示前 38 个目标，共 \(candidates.count) 个。" + suffix)
        }
        return messages.isEmpty ? nil : messages.joined(separator: " ")
    }

    private func mapping(_ candidates: [Candidate]) -> [Key: Candidate] {
        KeyAssigner.assign(AppRanker.rank(candidates))
    }

    private func toggleMode() {
        guard panel.isVisible, !isActivating else { return }
        generation += 1
        loadTask?.cancel()
        if mode == .windows {
            mode = .applications
            isLoading = false
            appCandidates = provider.candidates(excluding: Int(ProcessInfo.processInfo.processIdentifier), usage: usage.load())
            panel.update(keyMap: mapping(appCandidates), mode: mode, message: combinedMessage(nil, candidates: appCandidates))
            invalidateSnapshot()
            return
        }
        mode = .windows
        isLoading = true
        // No live re-mapping while a user is choosing a target.
        panel.update(keyMap: [:], mode: mode, isLoading: true)
        let session = generation
        let cleanup = cleanupTask
        let stats = usage.load()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await cleanup?.value
            guard !Task.isCancelled, generation == session else { return }
            let candidates = await provider.windowCandidates(excluding: Int(ProcessInfo.processInfo.processIdentifier), usage: stats)
            guard !Task.isCancelled, generation == session, panel.isVisible else { return }
            isLoading = false
            let hint: String?
            if !AXIsProcessTrusted() {
                hint = "允许辅助功能后可选择窗口；当前仍可切换应用。"
            } else if !candidates.contains(where: \.isWindow) {
                hint = "暂时没有可单独切换的窗口，仍可按键切换应用。"
            } else { hint = nil }
            panel.update(keyMap: mapping(candidates), mode: .windows, message: combinedMessage(hint, candidates: candidates))
        }
    }

    private func activate(_ key: Key) {
        guard !isActivating, !isLoading, let candidate = panel.keyMap[key] else { return }
        guard canBeginSwitch?() ?? true else {
            dismiss(restore: false)
            return
        }
        isActivating = true
        loadTask?.cancel()
        panel.hide(restorePrevious: false)
        // Keep the F/J detector suspended until the focus operation is complete.
        Task { [weak self] in
            guard let self else { return }
            let result = await provider.activate(candidate)
            await provider.invalidateWindowSnapshot()
            isActivating = false
            switch result {
            case .success:
                appCandidates = []
                SequenceHotKey.shared.suspended = false
            case .failure(let reason):
                let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
                if frontmost == ProcessInfo.processInfo.processIdentifier || frontmost.map(Int.init) == candidate.target.pid {
                    show(message: reason, rememberPrevious: false)
                } else {
                    // A failed operation must not steal focus after the user has moved elsewhere.
                    pendingMessage = reason
                    appCandidates = []
                    SequenceHotKey.shared.suspended = false
                }
            }
        }
    }
}
