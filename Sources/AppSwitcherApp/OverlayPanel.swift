import AppKit
import SwiftUI
import AppSwitcherCore

/// Owns the keyboard snapshot and restores focus only for explicit cancellation.
@MainActor
final class OverlayPanel {
    private final class KeyablePanel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private let panel: KeyablePanel
    private var hostingView: NSHostingView<OverlayView>?
    private var previousApp: NSRunningApplication?
    private var monitors: [Any] = []
    private var deactivationObserver: NSObjectProtocol?
    private var icons: [String: NSImage] = [:]
    private var mode: OverlayMode = .applications
    private var isLoading = false
    private var message: String?
    private var selectedKey: Key?
    private var presentationScreen: NSScreen?

    private(set) var keyMap: [Key: Candidate] = [:]
    var onKey: ((Key) -> Void)?
    var onCancel: ((Bool) -> Void)?
    var onToggleMode: (() -> Void)?
    var onSettings: (() -> Void)?
    var isVisible: Bool { panel.isVisible }

    init() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 478),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        installEventMonitors()
    }

    func show(
        keyMap: [Key: Candidate], mode: OverlayMode = .applications,
        isLoading: Bool = false, message: String? = nil, rememberPrevious: Bool = true
    ) {
        if rememberPrevious, !panel.isVisible {
            previousApp = NSWorkspace.shared.frontmostApplication
            let mouse = NSEvent.mouseLocation
            presentationScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        }
        update(keyMap: keyMap, mode: mode, isLoading: isLoading, message: message)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func update(keyMap: [Key: Candidate], mode: OverlayMode, isLoading: Bool = false, message: String? = nil) {
        self.keyMap = keyMap
        self.mode = mode
        self.isLoading = isLoading
        self.message = message
        let available = Set(keyMap.keys)
        if selectedKey == nil || !available.contains(selectedKey!) {
            selectedKey = KeyNavigation.ordered(available).first
        }
        icons = Dictionary(NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bundle = app.bundleIdentifier, let icon = app.icon else { return nil }
            return (bundle, AppIconImage.prepared(icon))
        }, uniquingKeysWith: { first, _ in first })
        render()
        sizeToScreen()
    }

    func hide(restorePrevious: Bool, clear: Bool = true) {
        panel.orderOut(nil)
        if clear {
            keyMap = [:]
            icons = [:]
            selectedKey = nil
            message = nil
            // Drop the SwiftUI value snapshot too, including transient window titles.
            hostingView = nil
            panel.contentView = nil
        }
        if restorePrevious, let previousApp, !previousApp.isTerminated {
            _ = previousApp.activate(options: [])
        }
    }

    private func render() {
        let view = OverlayView(
            keyMap: keyMap, icons: icons, mode: mode, selectedKey: selectedKey,
            isLoading: isLoading, message: message,
            onSelect: { [weak self] key in self?.select(key) },
            onActivate: { [weak self] key in self?.activate(key) },
            onToggleMode: { [weak self] in self?.onToggleMode?() },
            onCancel: { [weak self] in self?.onCancel?(true) },
            onSettings: { [weak self] in self?.onSettings?() }
        )
        if let hostingView { hostingView.rootView = view }
        else {
            let host = NSHostingView(rootView: view)
            panel.contentView = host
            hostingView = host
        }
    }

    private func select(_ key: Key) {
        guard !isLoading, keyMap[key] != nil, selectedKey != key else { return }
        selectedKey = key
        render()
    }

    private func activate(_ key: Key) {
        guard !isLoading, keyMap[key] != nil else { return }
        onKey?(key)
    }

    private func sizeToScreen() {
        guard let screen = presentationScreen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = OverlayView.preferredSize(in: visible.size)
        panel.setFrame(NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width, height: size.height
        ), display: true)
    }

    private func installEventMonitors() {
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard let self, self.panel.isVisible, self.panel.isKeyWindow else { return event }
            if event.keyCode != 53 && !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return event }
            switch event.keyCode {
            case 53: self.onCancel?(true)
            case 48: if !event.isARepeat { self.onToggleMode?() }
            case 36, 76:
                if !event.isARepeat, let key = self.selectedKey { self.activate(key) }
            case 123, 124, 125, 126:
                let direction: KeyNavigation.Direction = [123: .left, 124: .right, 125: .down, 126: .up][Int(event.keyCode)]!
                if let key = KeyNavigation.move(from: self.selectedKey, direction: direction, available: Set(self.keyMap.keys)) { self.select(key) }
            default:
                if !event.isARepeat, let key = KeyInput.key(for: event.keyCode) { self.activate(key) }
            }
            return nil
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            if let self, self.panel.isVisible, event.window !== self.panel { self.onCancel?(false) }
            return event
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            self.onCancel?(false)
        }) { monitors.append(monitor) }
        deactivationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.panel.isVisible else { return }
                self.onCancel?(false)
            }
        }
    }
}
