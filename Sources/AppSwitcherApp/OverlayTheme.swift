import SwiftUI

/// 覆盖层的语义设计值。界面固定为深色，避免透明度影响键位与标题的可读性。
enum OverlayTheme {
    static let background = Color(red: 0.075, green: 0.085, blue: 0.105)
    static let surface = Color(red: 0.13, green: 0.145, blue: 0.175)
    static let surfaceHover = Color(red: 0.17, green: 0.19, blue: 0.23)
    static let surfaceSelected = Color(red: 0.105, green: 0.19, blue: 0.30)
    static let emptySurface = Color.white.opacity(0.025)
    static let text = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let secondaryText = Color(red: 0.68, green: 0.72, blue: 0.79)
    static let mutedText = Color(red: 0.47, green: 0.51, blue: 0.58)
    static let border = Color.white.opacity(0.09)
    static let primary = Color(red: 0.40, green: 0.67, blue: 1.0)
    static let warning = Color(red: 1.0, green: 0.76, blue: 0.36)
    static let panelRadius: CGFloat = 22
    static let keyRadius: CGFloat = 12
    static let panelPadding: CGFloat = 20
    static let keyGap: CGFloat = 8
    static let minimumKeyHeight: CGFloat = 104
    static let panelWidthFraction: CGFloat = 0.92
    static let panelHeightFraction: CGFloat = 0.82
    static let screenInset: CGFloat = 16
    static let hoverDuration = 0.12
}
