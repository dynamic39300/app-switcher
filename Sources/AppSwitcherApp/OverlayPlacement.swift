import Foundation

/// Keep a dropped panel reachable, including displays with negative or vertically offset origins.
enum OverlayPlacement {
    static func fittedFrame(_ frame: CGRect, in visibleFrame: CGRect, hasNumberRow: Bool = false) -> CGRect {
        let inset = min(OverlayTheme.screenInset, max(0, min(visibleFrame.width, visibleFrame.height) / 2 - 1))
        let bounds = visibleFrame.insetBy(dx: inset, dy: inset)
        let preferred = OverlayView.preferredSize(in: visibleFrame.size, hasNumberRow: hasNumberRow)
        let size = CGSize(width: min(frame.width, preferred.width), height: min(frame.height, preferred.height))
        // Preserve the top-left while shrinking, then move only as much as visibility requires.
        return CGRect(
            x: min(max(frame.minX, bounds.minX), bounds.maxX - size.width),
            y: min(max(frame.maxY - size.height, bounds.minY), bounds.maxY - size.height),
            width: size.width, height: size.height
        )
    }
}
