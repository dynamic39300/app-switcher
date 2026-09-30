import AppKit
import SwiftUI
import AppSwitcherCore
import AppSwitcherKit

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
    private let iconOverrides: [String: NSImage]
    private var mode: OverlayMode = .applications
    private var isLoading = false
    private var message: String?
    private var feedbackIsSuccess = false
    private var selectedKey: Key?
    private var presentationScreen: NSScreen?
    private let appearance: OverlayAppearanceStore
    private let mappingStore: KeyMappingStore
    private var isDraggingKey = false
    private var guideRevision = 0
    private var interactionRevision = 0
    var style: OverlayStyle { appearance.style }

    private(set) var keyMap: [Key: Candidate] = [:]
    var onKey: ((Key) -> Void)?
    var onCancel: ((Bool) -> Void)?
    var onToggleMode: (() -> Void)?
    var onSettings: (() -> Void)?
    var onQuit: ((Key) -> Void)?
    var onRemap: ((Key, Key, String) -> Bool)?
    var onResetBindings: ((String?) -> Void)?
    var isVisible: Bool { panel.isVisible }

    init(appearance: OverlayAppearanceStore = OverlayAppearanceStore(), mappingStore: KeyMappingStore = KeyMappingStore(),
         iconOverrides: [String: NSImage] = [:]) {
        self.appearance = appearance
        self.mappingStore = mappingStore
        self.iconOverrides = iconOverrides
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 478),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.title = "AppSwitcher"
        panel.isMovable = true
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
        let isNewPresentation = !panel.isVisible
        if rememberPrevious, !panel.isVisible {
            previousApp = NSWorkspace.shared.frontmostApplication
            let mouse = NSEvent.mouseLocation
            presentationScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        }
        update(keyMap: keyMap, mode: mode, isLoading: isLoading, message: message)
        if isNewPresentation { sizeToScreen() }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func update(keyMap: [Key: Candidate], mode: OverlayMode, isLoading: Bool = false, message: String? = nil, isSuccess: Bool = false) {
        let selectedID = selectedKey.flatMap { self.keyMap[$0]?.id }
        self.keyMap = keyMap
        self.mode = mode
        self.isLoading = isLoading
        self.message = message
        feedbackIsSuccess = isSuccess
        let available = Set(keyMap.keys)
        if let selectedID, let movedKey = keyMap.first(where: { $0.value.id == selectedID })?.key {
            selectedKey = movedKey
        }
        if selectedKey == nil || !available.contains(selectedKey!) {
            selectedKey = KeyNavigation.ordered(available).first
        }
        icons = Dictionary(NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bundle = app.bundleIdentifier, let icon = app.icon else { return nil }
            return (bundle, AppIconImage.prepared(icon))
        }, uniquingKeysWith: { first, _ in first })
        icons.merge(iconOverrides, uniquingKeysWith: { _, preview in preview })
        render()
    }

    func hide(restorePrevious: Bool, clear: Bool = true) {
        isDraggingKey = false
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
        let notices = [appearance.notice, mappingStore.notice].compactMap { $0 }.joined(separator: " ")
        let view = OverlayView(
            keyMap: keyMap, icons: icons, mode: mode, selectedKey: selectedKey,
            isLoading: isLoading, message: message,
            onSelect: { [weak self] key in self?.select(key) },
            onActivate: { [weak self] key in self?.activate(key) },
            onToggleMode: { [weak self] in self?.onToggleMode?() },
            onCancel: { [weak self] in self?.onCancel?(true) },
            onSettings: { [weak self] in self?.onSettings?() },
            onQuit: { [weak self] key in self?.onQuit?(key) },
            onMoveEnded: { [weak self] in self?.finishMoving() },
            style: appearance.style,
            onChangeStyle: { [weak self] style in self?.changeStyle(style) },
            appearanceNotice: notices.isEmpty ? nil : notices,
            onRemap: onRemap,
            onDragStateChanged: { [weak self] dragging in self?.isDraggingKey = dragging },
            savedBindings: mappingStore.preferences.bindings,
            showsDragGuide: mappingStore.preferences.showsDragGuide,
            onChangeDragGuide: { [weak self] enabled in self?.setDragGuide(enabled) },
            guideRevision: guideRevision,
            interactionRevision: interactionRevision,
            onResetBindings: onResetBindings,
            feedbackIsSuccess: feedbackIsSuccess
        )
        panel.appearance = NSAppearance(named: appearance.style == .porcelain ? .aqua : .darkAqua)
        if let hostingView { hostingView.rootView = view }
        else {
            let host = NSHostingView(rootView: view)
            panel.contentView = host
            hostingView = host
        }
    }

    private func select(_ key: Key) {
        guard !isLoading, !isDraggingKey, keyMap[key] != nil, selectedKey != key else { return }
        selectedKey = key
        render()
    }

    func changeStyle(_ style: OverlayStyle) {
        appearance.select(style)
        // Render only: never rebuild the snapshot, move the frame, or change the selection.
        if panel.isVisible { render() }
    }

    private func activate(_ key: Key) {
        guard !isLoading, !isDraggingKey, keyMap[key] != nil else { return }
        onKey?(key)
    }

    private func setDragGuide(_ enabled: Bool) {
        var next = mappingStore.preferences
        next.showsDragGuide = enabled
        if mappingStore.save(next) { guideRevision += 1 }
        render()
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

    private func finishMoving() {
        guard panel.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? panel.screen else { return }
        presentationScreen = screen
        panel.setFrame(OverlayPlacement.fittedFrame(panel.frame, in: screen.visibleFrame), display: true)
    }

    private func installEventMonitors() {
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard let self, self.panel.isVisible, self.panel.isKeyWindow else { return event }
            if self.isDraggingKey && event.keyCode != 53 { return nil }
            self.interactionRevision += 1
            self.render()
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if modifiers == .command, let index = [UInt16(18), 19, 20].firstIndex(of: event.keyCode) {
                if !event.isARepeat { self.changeStyle(OverlayStyle.allCases[index]) }
                return nil
            }
            if modifiers == .command, event.keyCode == 43 {
                if !event.isARepeat { self.onSettings?() }
                return nil
            }
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
