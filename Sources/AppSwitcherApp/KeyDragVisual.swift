import AppKit
import SwiftUI
import AppSwitcherCore

struct KeyFramePreference: PreferenceKey {
    static var defaultValue: [Key: CGRect] = [:]
    static func reduce(value: inout [Key: CGRect], nextValue: () -> [Key: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct KeyViewportPreference: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        // Siblings without a viewport contribute the default zero rectangle.
        if !next.isEmpty { value = next }
    }
}

struct KeyDragSnapshot {
    let source: Key
    let candidateID: String
    let candidate: Candidate
    var location: CGPoint
}

struct KeyGuideSample {
    let source: Key
    let destination: Key
    let candidate: Candidate
    let start: CGPoint
    let end: CGPoint
    let size: CGFloat
}

struct KeyGuideRequest: Equatable {
    let enabled: Bool
    let revision: Int
    let mode: OverlayMode
}

/// A visual copy only; it never participates in hit testing or target activation.
struct KeyDragVisual: View {
    let icon: NSImage?
    let size: CGFloat
    let location: CGPoint
    let palette: OverlayPalette
    var showsPointer = false
    var landed = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
                } else {
                    Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(palette.text)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: landed ? 2 : 9, y: landed ? 1 : 7)
            if showsPointer {
                Image(systemName: landed ? "checkmark.circle.fill" : "cursorarrow")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(landed ? palette.primary : palette.text)
                    .shadow(color: palette.base, radius: 2)
                    .offset(x: 12, y: 12)
            }
        }
        .position(location)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
