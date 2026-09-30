import AppKit
import SwiftUI

/// A non-activating notice leaves the target app and its save dialog in control.
@MainActor
final class QuitNoticePanel {
    private let panel: NSPanel
    var isVisible: Bool { panel.isVisible }
    private var dismissTask: Task<Void, Never>?
    private var revision = 0

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 82),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
    }

    func show(_ text: String, onViewApplication: (() -> Void)? = nil, duration: Duration = .seconds(7)) {
        revision += 1
        let current = revision
        dismissTask?.cancel()
        panel.contentView = NSHostingView(rootView: QuitNoticeView(message: text, onViewApplication: onViewApplication))
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let screen {
            let bounds = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: bounds.maxX - panel.frame.width - 24,
                                         y: bounds.maxY - panel.frame.height - 24))
        }
        panel.orderFront(nil)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, self?.revision == current else { return }
            self?.panel.orderOut(nil)
        }
    }

    func hide() {
        revision += 1
        dismissTask?.cancel()
        panel.orderOut(nil)
    }
}

private struct QuitNoticeView: View {
    let message: String
    let onViewApplication: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "power")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 13))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onViewApplication {
                Button("查看应用", action: onViewApplication)
                    .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 380, height: 82)
        .foregroundStyle(.primary)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.12)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
    }
}
