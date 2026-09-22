import AppKit
import SwiftUI
import AppSwitcherCore

/// 覆盖层窗口：无边框 NSPanel + NSHostingView(SwiftUI)。显示时短暂成为前台以接收按键。
final class OverlayPanel {
    private final class KeyablePanel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private let panel: KeyablePanel
    private var hostingView: NSHostingView<OverlayView>?
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?

    private(set) var keyMap: [Key: Candidate] = [:]
    var onKey: ((Key) -> Void)?
    var onCancel: (() -> Void)?

    var isVisible: Bool { panel.isVisible }

    init() {
        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 300),
            styleMask: [.borderless],
            backing: .buffered, defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.hidesOnDeactivate = false
        panel = p
        installKeyMonitor()
    }

    func show(keyMap: [Key: Candidate]) {
        self.keyMap = keyMap
        previousApp = NSWorkspace.shared.frontmostApplication

        let view = OverlayView(keyMap: keyMap)
        if let hv = hostingView {
            hv.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            panel.contentView = hv
            hostingView = hv
        }

        sizeToScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide(restorePrevious: Bool) {
        panel.orderOut(nil)
        if restorePrevious, let prev = previousApp {
            _ = prev.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func sizeToScreen() {
        let screen = screenUnderMouse()
        let sw = screen.frame.width
        let panelWidth = min(sw * 0.9, 1600)
        let gap: CGFloat = 10
        let keySize = (panelWidth - 9 * gap) / 10
        let panelHeight = 3 * (keySize + gap) + 40
        let x = screen.frame.midX - panelWidth / 2
        let y = screen.frame.minY + (screen.frame.height - panelHeight) * 0.45
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }

    private func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main!
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            if event.keyCode == 53 { // Esc
                self.onCancel?()
                return nil
            }
            if let chars = event.charactersIgnoringModifiers?.uppercased(), let c = chars.first, c >= "A", c <= "Z" {
                let key = Key(String(c), letter: true)
                if self.keyMap[key] != nil {
                    self.onKey?(key)
                }
                return nil
            }
            return event
        }
    }
}
