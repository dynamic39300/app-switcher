import Foundation
import SwiftUI

/// UI-only preference. Never participates in candidate identity, rank, or keyboard mapping.
enum OverlayStyle: String, Codable, CaseIterable {
    case graphite, porcelain, smoke

    var title: String {
        switch self { case .graphite: "石墨机械"; case .porcelain: "银瓷工作台"; case .smoke: "烟晶控制台" }
    }
    var shortTitle: String {
        switch self { case .graphite: "石墨"; case .porcelain: "银瓷"; case .smoke: "烟晶" }
    }
    var number: Int { Self.allCases.firstIndex(of: self)! + 1 }
    var colorScheme: ColorScheme { self == .porcelain ? .light : .dark }
    var travel: CGFloat { self == .porcelain ? 4 : (self == .smoke ? 2 : 3) }

    enum DetailPlacement { case none, top, side }
    func detailPlacement(in size: CGSize, hasNumberRow: Bool) -> DetailPlacement {
        if self == .smoke && size.width >= (hasNumberRow ? 1260 : 1080) && size.height >= 440 { return .side }
        if self != .graphite && size.width >= 760 && size.height >= (hasNumberRow ? 620 : 480) { return .top }
        return .none
    }
}

/// Atomic, independently versioned appearance file. A failed write keeps the active theme.
final class OverlayAppearanceStore {
    private struct Record: Codable { let version: Int; let style: OverlayStyle }
    let url: URL
    private(set) var style: OverlayStyle = .graphite
    private(set) var notice: String?

    init(url: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("AppSwitcher/appearance.json")) {
        self.url = url
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
            guard record.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
            style = record.style
        } catch {
            notice = "外观配置无法读取，暂用石墨；重新选择样式可保存修复。"
        }
    }

    @discardableResult
    func select(_ newStyle: OverlayStyle) -> Bool {
        do {
            let data = try JSONEncoder().encode(Record(version: 1, style: newStyle))
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            style = newStyle
            notice = nil
            return true
        } catch {
            notice = "外观未能保存，已保留原样式；请检查磁盘空间或配置目录权限后重试。"
            return false
        }
    }
}

/// Six material anchors from the accepted prototype; semantic colors vary with the surface.
struct OverlayPalette {
    let style: OverlayStyle
    private var light: Bool { style == .porcelain }
    private var glass: Bool { style == .smoke }
    var background: Color { color(light ? 0xDADDDF : (glass ? 0x192C33 : 0x202429)) }
    var panelTop: Color { color(light ? 0xF8F9FA : (glass ? 0x345661 : 0x262B30)) }
    var surface: Color { color(light ? 0xECEEF0 : (glass ? 0x24404C : 0x31363D)) }
    var surfaceHover: Color { color(light ? 0xD4DEE7 : (glass ? 0x365D6A : 0x3B4249)) }
    var surfaceSelected: Color { color(light ? 0xC2DDF3 : (glass ? 0x315566 : 0x364754)) }
    var topEdge: Color { Color.white.opacity(light ? 0.95 : (glass ? 0.5 : 0.32)) }
    var base: Color { color(light ? 0xA2AAB4 : (glass ? 0x102C38 : 0x11151B)) }
    var emptySurface: Color { surface.opacity(light ? 0.55 : 0.3) }
    var text: Color { color(light ? 0x26313D : 0xECEEF0) }
    var secondaryText: Color { color(light ? 0x526171 : (glass ? 0xAFC3CA : 0xB3BDC9)) }
    var mutedText: Color { secondaryText.opacity(0.7) }
    var border: Color { (light ? Color.black : Color.white).opacity(light ? 0.18 : 0.15) }
    var primary: Color { color(light ? 0x326693 : (glass ? 0x9CCFFF : 0xADC5D6)) }
    var warning: Color { color(light ? 0x8A420C : 0xFFC36B) }
    var strongBorder: Color { text.opacity(0.65) }
    var panelGradient: LinearGradient { LinearGradient(colors: [panelTop, background], startPoint: .topLeading, endPoint: .bottomTrailing) }
    func keyGradient(selected: Bool, hovered: Bool) -> LinearGradient {
        let face = selected ? surfaceSelected : (hovered ? surfaceHover : surface)
        return LinearGradient(colors: [face, face, face.opacity(style == .graphite ? 0.96 : 0.9)], startPoint: .top, endPoint: .bottom)
    }
    private func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct MaterialKeycapStyle: ButtonStyle {
    let style: OverlayStyle
    let selected: Bool
    var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let palette = OverlayPalette(style: style)
        let shape = RoundedRectangle(cornerRadius: OverlayTheme.keyRadius, style: .continuous)
        configuration.label
            .background(palette.keyGradient(selected: selected, hovered: hovered), in: shape)
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [palette.topEdge, palette.border], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .compositingGroup() // Shadow the solid keycap, not its text and application icon separately.
            .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.3), radius: configuration.isPressed ? 0 : 1, y: configuration.isPressed ? 0 : 3)
            .offset(y: configuration.isPressed && !reduceMotion ? style.travel : 0)
            .padding(.horizontal, 4)
            .padding(.top, 3)
            .padding(.bottom, 7)
            .background(palette.base, in: shape)
            .overlay {
                shape.strokeBorder(selected || configuration.isPressed ? palette.primary : (contrast == .increased ? palette.strongBorder : (hovered ? palette.secondaryText.opacity(0.55) : palette.border)), lineWidth: selected || configuration.isPressed ? 1.5 : 1)
            }
            .overlay(alignment: .bottom) {
                if selected { Capsule().fill(palette.primary).frame(width: 14, height: 2).padding(.bottom, 2).accessibilityHidden(true) }
            }
            .contentShape(shape)
            .animation(reduceMotion ? nil : .easeOut(duration: OverlayTheme.hoverDuration), value: hovered)
            .animation(reduceMotion ? nil : .easeOut(duration: configuration.isPressed ? 0.06 : 0.15), value: configuration.isPressed)
    }
}
