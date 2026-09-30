import AppKit
import AppSwitcherCore

/// Explicit, local UI verification. Only synthetic candidates; never activates another user's app.
@MainActor
enum OverlayDragProbe {
    private struct Failure: Error { let message: String }

    static func run() async -> Int {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AppSwitcher-theme-ui-\(UUID().uuidString)")
        let appearance = OverlayAppearanceStore(url: directory.appendingPathComponent("appearance.json"))
        let panel = OverlayPanel(appearance: appearance)
        let originalMouse = NSEvent.mouseLocation
        defer {
            panel.hide(restorePrevious: true)
            postMouse(.mouseMoved, at: originalMouse)
            try? FileManager.default.removeItem(at: directory)
        }
        do {
            try verifyPlacement()
            guard CGPreflightPostEventAccess() else {
                print("SKIP overlay-drag: event posting permission unavailable; no prompt requested")
                return 2
            }
            let q = Key("Q", letter: true)
            let w = Key("W", letter: true)
            let map = Dictionary(uniqueKeysWithValues: [q, w].enumerated().map { index, key in
                (key, Candidate(id: "drag-probe.\(index)", groupID: "drag-probe.\(index)",
                                displayName: "合成测试 \(key.label)", target: .application(pid: -1)))
            })
            var activations: [Key] = []
            var quitRequests: [Key] = []
            var settings = 0
            var toggles = 0
            panel.onKey = { activations.append($0) }
            panel.onQuit = { quitRequests.append($0) }
            panel.onSettings = { settings += 1 }
            panel.onCancel = { _ in panel.hide(restorePrevious: false) }
            panel.onToggleMode = {
                toggles += 1
                panel.update(keyMap: map, mode: toggles % 2 == 0 ? .applications : .windows)
            }
            guard await until({ NSRunningApplication.current.isFinishedLaunching }) else {
                throw Failure(message: "synthetic probe app did not finish launching")
            }
            panel.show(keyMap: map)
            await settle()
            var visiblePanel = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible })
            for _ in 0..<20 where visiblePanel == nil {
                try? await Task.sleep(for: .milliseconds(100))
                visiblePanel = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible })
            }
            guard let window = visiblePanel else {
                throw Failure(message: "synthetic panel missing")
            }
            guard await until({ window.isKeyWindow && NSApp.isActive }) else {
                throw Failure(message: "synthetic panel did not become active")
            }
            let start = window.frame
            try await drag(window, from: CGPoint(x: start.midX, y: start.maxY - 12),
                           to: CGPoint(x: start.midX + 24, y: start.maxY - 36))
            try require(abs(window.frame.minX - start.minX) > 8 || abs(window.frame.minY - start.minY) > 8,
                        "background mouse drag moves the native panel")
            let moved = window.frame
            panel.update(keyMap: [:], mode: .windows, isLoading: true)
            await settle()
            panel.update(keyMap: map, mode: .windows)
            await settle()
            try require(window.frame == moved, "loading and mode updates preserve the dragged frame")

            let beforeTitle = window.frame
            try await drag(window, from: CGPoint(x: beforeTitle.minX + 140, y: beforeTitle.maxY - 42),
                           to: CGPoint(x: beforeTitle.minX + 116, y: beforeTitle.maxY - 22))
            try require(window.frame != beforeTitle, "title text also allows dragging")
            let beforeEmptyKey = window.frame
            let keyWidth = (beforeEmptyKey.width - 40 - 9 * OverlayTheme.keyGap) / 10
            let emptyKey = CGPoint(x: beforeEmptyKey.minX + 20 + 2.5 * keyWidth + 2 * OverlayTheme.keyGap,
                                   y: beforeEmptyKey.maxY - 130)
            try await drag(window, from: emptyKey, to: CGPoint(x: emptyKey.x + 18, y: emptyKey.y - 18))
            try require(window.frame != beforeEmptyKey, "empty keycap allows dragging")
            let beforeFooter = window.frame
            let footer = CGPoint(x: beforeFooter.midX, y: beforeFooter.minY + 28)
            try await drag(window, from: footer, to: CGPoint(x: footer.x - 18, y: footer.y + 18))
            try require(window.frame != beforeFooter, "footer background allows dragging")
            try require(activations.isEmpty, "dragging never activates a candidate")

            panel.update(keyMap: map, mode: .applications)
            await settle()
            let quitKeyWidth = (window.frame.width - 40 - 9 * OverlayTheme.keyGap) / 10
            let quitPoint = CGPoint(x: window.frame.minX + 20 + quitKeyWidth - 22,
                                    y: window.frame.maxY - 96)
            postMouse(.mouseMoved, at: quitPoint)
            await settle()
            try await click(window, at: quitPoint)
            try require(quitRequests == [q] && activations.isEmpty,
                        "application X requests quit once without activating the card")

            // Q is the first populated key in the three-row synthetic keyboard.
            try await click(window, at: CGPoint(x: window.frame.minX + 52, y: window.frame.maxY - 130))
            try require(activations == [q], "candidate click still selects exactly its target")
            try await key(124, window: window)
            try await key(36, window: window)
            try require(activations == [q, w], "arrow selection and Enter remain usable after dragging")
            let frameBeforeTab = window.frame
            try await key(48, window: window)
            try require(toggles == 1 && window.frame == frameBeforeTab, "Tab switches mode without recentering")
            let quitCountInWindowMode = quitRequests.count
            postMouse(.mouseMoved, at: quitPoint)
            await settle()
            try await click(window, at: quitPoint)
            try require(quitRequests.count == quitCountInWindowMode,
                        "window mode never sends an application quit request")
            try await click(window, at: CGPoint(x: window.frame.maxX - 225, y: window.frame.maxY - 41))
            try require(toggles == 2, "mode button remains clickable")
            try await click(window, at: CGPoint(x: window.frame.maxX - 73, y: window.frame.maxY - 41))
            try require(settings == 1, "settings button remains clickable")
            try await key(43, window: window, modifiers: .maskCommand)
            try require(settings == 2, "Command-comma opens the same settings action")
            postMouse(.mouseMoved, at: CGPoint(x: window.frame.minX + 160, y: window.frame.maxY - 42))
            await settle()

            let beforeThemes = window.frame
            let previousActivations = activations
            for style in OverlayStyle.allCases {
                panel.changeStyle(style)
                await settle()
                try require(panel.style == style && panel.keyMap == map && window.frame == beforeThemes,
                            "\(style.rawValue) preserves mapping and frame")
                try await key(36, window: window)
                try require(activations.last == w, "\(style.rawValue) preserves selected target for Enter")
                try require(OverlayAppearanceStore(url: appearance.url).style == style, "\(style.rawValue) survives preference reload")
            }
            try require(activations.count == previousActivations.count + 3, "theme changes themselves never activate a candidate")
            panel.changeStyle(.graphite)
            try await key(19, window: window, modifiers: .maskCommand)
            try require(panel.style == .porcelain, "Command-2 switches to porcelain in the overlay")
            try await key(20, window: window, modifiers: .maskCommand)
            try require(panel.style == .smoke, "Command-3 switches to smoke in the overlay")
            try await key(18, window: window, modifiers: .maskCommand)
            try require(panel.style == .graphite, "Command-1 switches back to graphite")
            // Theme strip sits immediately left of the unchanged mode controls.
            try await click(window, at: CGPoint(x: window.frame.maxX - 320, y: window.frame.maxY - 41))
            try require(panel.style == .smoke && window.frame == beforeThemes, "theme button click changes style without dragging")
            panel.changeStyle(.graphite)

            let screens = NSScreen.screens.sorted { $0.visibleFrame.width > $1.visibleFrame.width }
            if let large = screens.first, let small = screens.last, screens.count > 1 {
                panel.hide(restorePrevious: false)
                postMouse(.mouseMoved, at: CGPoint(x: large.visibleFrame.midX, y: large.visibleFrame.midY))
                await settle()
                panel.show(keyMap: map)
                await settle()
                let largeFrame = window.frame
                let drop = CGPoint(x: small.visibleFrame.midX, y: small.visibleFrame.maxY - 100)
                try await drag(window, from: CGPoint(x: largeFrame.midX, y: largeFrame.maxY - 12), to: drop)
                try require(small.visibleFrame.contains(window.frame), "large-to-small display drag fits entirely on destination")
                try require(window.frame.width <= OverlayView.preferredSize(in: small.visibleFrame.size).width + 1,
                            "cross-display drop shrinks an oversized panel")
                let crossFrame = window.frame
                panel.update(keyMap: map, mode: .windows)
                await settle()
                try require(window.frame == crossFrame, "content update stays on the destination display")
                let returnDrop = CGPoint(x: large.visibleFrame.midX, y: large.visibleFrame.maxY - 100)
                try await drag(window, from: CGPoint(x: crossFrame.midX, y: crossFrame.maxY - 12), to: returnDrop)
                try require(large.visibleFrame.contains(window.frame), "small-to-large display drag lands on destination")
            } else {
                print("NOTE overlay-drag: only one display; real cross-display drag not exercised")
            }
            try await click(window, at: CGPoint(x: window.frame.maxX - 34, y: window.frame.maxY - 41))
            try require(!panel.isVisible, "close button remains clickable")
            panel.show(keyMap: map)
            await settle()
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
                try require(abs(window.frame.midX - screen.visibleFrame.midX) < 2
                            && abs(window.frame.midY - screen.visibleFrame.midY) < 2,
                            "next presentation recenters on the pointer display")
            }
            try await key(53, window: window)
            try require(!panel.isVisible, "Escape still dismisses the panel")
            return 0
        } catch {
            print("FAIL overlay-drag: \((error as? Failure)?.message ?? error.localizedDescription)")
            return 1
        }
    }

    private static func verifyPlacement() throws {
        let desktop = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let unchanged = CGRect(x: 100, y: 100, width: 900, height: 600)
        try require(OverlayPlacement.fittedFrame(unchanged, in: desktop) == unchanged,
                    "in-bounds local moves retain position and size")
        for visible in [desktop, CGRect(x: -1280, y: -200, width: 1280, height: 720),
                        CGRect(x: 1512, y: -458, width: 2560, height: 1440),
                        CGRect(x: 0, y: 1000, width: 760, height: 430)] {
            let fitted = OverlayPlacement.fittedFrame(CGRect(x: -2000, y: 2500, width: 2400, height: 1200), in: visible)
            try require(visible.insetBy(dx: 16, dy: 16).contains(fitted), "drop containment for synthetic display \(visible.size)")
        }
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message: message) }
        print("PASS overlay-drag: \(message)")
    }

    private static func settle() async { try? await Task.sleep(for: .milliseconds(250)) }

    private static func until(_ predicate: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !predicate() {
            guard ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return true
    }

    private static func validate(_ window: NSWindow, at point: CGPoint? = nil) throws {
        guard window.isVisible, window.isKeyWindow, NSApp.isActive,
              point.map({ window.frame.contains($0) }) ?? true else {
            throw Failure(message: "synthetic panel lost focus or pointer target; stopping input")
        }
    }

    private static func drag(_ window: NSWindow, from start: CGPoint, to end: CGPoint) async throws {
        try validate(window, at: start)
        postMouse(.leftMouseDown, at: start)
        await settle()
        for step in 1...18 {
            let fraction = CGFloat(step) / 18
            postMouse(.leftMouseDragged, at: CGPoint(x: start.x + (end.x - start.x) * fraction,
                                                   y: start.y + (end.y - start.y) * fraction))
            try? await Task.sleep(for: .milliseconds(25))
        }
        postMouse(.leftMouseUp, at: end)
        await settle()
    }

    private static func click(_ window: NSWindow, at point: CGPoint) async throws {
        try validate(window, at: point)
        postMouse(.leftMouseDown, at: point)
        postMouse(.leftMouseUp, at: point)
        await settle()
    }

    private static func postMouse(_ type: CGEventType, at point: CGPoint) {
        guard let main = NSScreen.screens.first else { return }
        let quartz = CGPoint(x: point.x, y: main.frame.maxY - point.y)
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: quartz, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }

    private static func key(_ code: CGKeyCode, window: NSWindow, modifiers: CGEventFlags = []) async throws {
        try validate(window)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
            event?.flags = modifiers
            event?.postToPid(ProcessInfo.processInfo.processIdentifier)
        }
        await settle()
    }
}
