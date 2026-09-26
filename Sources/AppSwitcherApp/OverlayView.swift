import AppKit
import SwiftUI
import AppSwitcherCore

enum OverlayMode: String {
    case applications
    case windows

    var title: String { self == .applications ? "应用" : "窗口" }
    var alternateTitle: String { self == .applications ? "窗口" : "应用" }
}

/// 仅呈现本次候选快照。目标枚举、图标读取及激活都由 controller 完成。
struct OverlayView: View {
    let keyMap: [Key: Candidate]
    let icons: [String: NSImage]
    let mode: OverlayMode
    let selectedKey: Key?
    let isLoading: Bool
    let message: String?
    let onSelect: (Key) -> Void
    let onActivate: (Key) -> Void
    let onToggleMode: () -> Void
    let onCancel: () -> Void
    var onSettings: (() -> Void)? = nil

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasNumberRow: Bool { keyMap.keys.contains { !$0.isLetter } }
    private var rows: [[Key]] {
        let letters = (0...2).map { y in Key.letters.filter { $0.y == y } }
        return hasNumberRow ? [Key.numberRow] + letters : letters
    }
    private var inspectedCandidate: Candidate? { selectedKey.flatMap { keyMap[$0] } }

    static func preferredSize(in availableSize: CGSize) -> CGSize {
        CGSize(
            width: max(1, min(availableSize.width * OverlayTheme.panelWidthFraction, availableSize.width - OverlayTheme.screenInset * 2)),
            height: max(1, min(availableSize.height * OverlayTheme.panelHeightFraction, availableSize.height - OverlayTheme.screenInset * 2))
        )
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .frame(height: 42)
                    .padding(.bottom, 12)
                if keyMap.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeometryReader { keyboardGeometry in
                        keyboardRegion(size: keyboardGeometry.size)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                footer
                    .padding(.top, 12)
            }
            .padding(OverlayTheme.panelPadding)
        }
        .background(OverlayTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: OverlayTheme.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OverlayTheme.panelRadius, style: .continuous)
                .strokeBorder(contrast == .increased ? Color.white.opacity(0.6) : Color.white.opacity(0.16), lineWidth: 1)
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("AppSwitcher，切换\(mode.title)")
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(OverlayTheme.primary)
                .frame(width: 36, height: 36)
                .background(OverlayTheme.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("AppSwitcher")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OverlayTheme.text)
                Text(headerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(OverlayTheme.secondaryText)
            }
            Spacer(minLength: 12)
            HStack(spacing: 3) {
                modeButton(.applications, symbol: "square.grid.2x2")
                modeButton(.windows, symbol: "macwindow.on.rectangle")
            }
            .padding(3)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
            if let onSettings {
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(OverlayTheme.secondaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("快捷键设置")
                .accessibilityLabel("快捷键设置")
            }
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OverlayTheme.secondaryText)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("关闭（Esc）")
            .accessibilityLabel("关闭切换器")
        }
    }

    private var headerSubtitle: String {
        if isLoading { return "正在读取可用\(mode.title)…" }
        if mode == .applications { return "切换应用 · \(keyMap.count) 个应用" }
        let windows = keyMap.values.filter(\.isWindow).count
        let applications = keyMap.count - windows
        if applications == 0 { return "切换窗口 · \(windows) 个窗口" }
        return "切换窗口 · \(windows) 个窗口 · \(applications) 个应用入口"
    }

    private func modeButton(_ buttonMode: OverlayMode, symbol: String) -> some View {
        Button {
            if buttonMode != mode { onToggleMode() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11))
                Text(buttonMode.title).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(buttonMode == mode ? OverlayTheme.text : OverlayTheme.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(buttonMode == mode ? OverlayTheme.surfaceHover : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换\(buttonMode.title)模式")
        .accessibilityAddTraits(buttonMode == mode ? .isSelected : [])
        .help("切换\(buttonMode.title)模式（Tab）")
    }

    @ViewBuilder
    private func keyboardRegion(size: CGSize) -> some View {
        let rowCount = CGFloat(rows.count)
        let rowHeight = (size.height - (rowCount - 1) * OverlayTheme.keyGap) / rowCount
        if rowHeight < OverlayTheme.minimumKeyHeight {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    keyboard(width: size.width, keyHeight: OverlayTheme.minimumKeyHeight)
                }
                .scrollIndicators(.visible)
                .onAppear { revealSelection(using: proxy) }
                .onChange(of: selectedKey) { _, _ in revealSelection(using: proxy) }
            }
        } else {
            keyboard(width: size.width, keyHeight: rowHeight)
        }
    }

    private func revealSelection(using proxy: ScrollViewProxy) {
        guard let selectedKey else { return }
        if reduceMotion {
            proxy.scrollTo(selectedKey.label, anchor: .center)
        } else {
            withAnimation(.easeOut(duration: OverlayTheme.hoverDuration)) {
                proxy.scrollTo(selectedKey.label, anchor: .center)
            }
        }
    }

    private func keyboard(width: CGFloat, keyHeight: CGFloat) -> some View {
        let widestRow = hasNumberRow ? 12 : 10
        let keyWidth = (width - CGFloat(widestRow - 1) * OverlayTheme.keyGap) / CGFloat(widestRow)
        return VStack(spacing: OverlayTheme.keyGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: OverlayTheme.keyGap) {
                    ForEach(row, id: \.label) { key in
                        keycap(key, width: keyWidth, height: keyHeight)
                            .id(key.label)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func keycap(_ key: Key, width: CGFloat, height: CGFloat) -> some View {
        if let candidate = keyMap[key] {
            Button { onActivate(key) } label: {
                populatedKeycap(key, candidate: candidate, width: width, height: height)
            }
            .buttonStyle(.plain)
            .onHover { inside in
                if inside { onSelect(key) }
            }
            .help(accessibilityTitle(candidate, key: key))
            .accessibilityLabel(accessibilityTitle(candidate, key: key))
            .accessibilityHint(candidate.isWindow ? "切换到这个窗口" : "切换到这个应用")
            .accessibilityAddTraits(selectedKey == key ? .isSelected : [])
        } else {
            VStack {
                HStack {
                    Spacer()
                    Text(key.label)
                        .font(.system(size: keyLabelSize(width: width), weight: .medium, design: .monospaced))
                        .foregroundStyle(contrast == .increased ? OverlayTheme.secondaryText : OverlayTheme.mutedText)
                }
                Spacer()
            }
            .padding(10)
            .frame(width: width, height: height)
            .background(OverlayTheme.emptySurface, in: RoundedRectangle(cornerRadius: OverlayTheme.keyRadius))
            .overlay {
                RoundedRectangle(cornerRadius: OverlayTheme.keyRadius)
                    .strokeBorder(contrast == .increased ? Color.white.opacity(0.25) : Color.white.opacity(0.045), lineWidth: 1)
            }
            .accessibilityHidden(true)
        }
    }

    private func populatedKeycap(_ key: Key, candidate: Candidate, width: CGFloat, height: CGFloat) -> some View {
        let isSelected = selectedKey == key
        let nameSize = max(11, min(16, width * 0.105, height * 0.105))
        let detailSize = max(10, min(12, nameSize - 1))
        let spacing: CGFloat = height > 140 ? 8 : 3
        // 先为两行名称、窗口说明留位，剩余空间再用于图标；不再按固定 64pt 封顶。
        let detailHeight = candidate.isWindow ? detailSize * 2.5 : (mode == .windows ? detailSize * 1.25 : 0)
        let textHeight = nameSize * 2.5 + detailHeight + spacing * (detailHeight > 0 ? 2 : 1)
        let preferredIconSize = max(18, min(width * 0.68, height * 0.52, height - 16 - textHeight))
        let inlineKeyLabel = width < 70 || (height - preferredIconSize - textHeight) / 2 < keyLabelSize(width: width) + 20
        let keyLabelWidth = ceil(keyLabelSize(width: width) * 0.75)
        let iconWidth = width - 14 - (inlineKeyLabel ? keyLabelWidth + 2 : 0)
        let iconSize = min(preferredIconSize, max(18, iconWidth))
        return VStack(spacing: spacing) {
            if inlineKeyLabel {
                // 图标接近右上角键标时改为并排，短屏和长标题也不互相遮挡。
                HStack(alignment: .top, spacing: 2) {
                    appIcon(candidate, size: iconSize).frame(maxWidth: .infinity)
                    Text(key.label)
                        .font(.system(size: keyLabelSize(width: width), weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? OverlayTheme.primary : OverlayTheme.secondaryText)
                        .frame(width: keyLabelWidth)
                }
            } else {
                appIcon(candidate, size: iconSize)
            }
            Text(candidate.displayName)
                .font(.system(size: nameSize, weight: .medium))
                .foregroundStyle(OverlayTheme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            if candidate.isWindow {
                Text(candidate.title)
                    .font(.system(size: detailSize))
                    .foregroundStyle(isSelected ? Color(red: 0.73, green: 0.83, blue: 0.95) : OverlayTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            } else if mode == .windows {
                Text("应用入口")
                    .font(.system(size: detailSize))
                    .foregroundStyle(OverlayTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
        .frame(width: width, height: height)
        .overlay(alignment: .topTrailing) {
            if !inlineKeyLabel {
                Text(key.label)
                    .font(.system(size: keyLabelSize(width: width), weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSelected ? OverlayTheme.primary : OverlayTheme.secondaryText)
                    .padding(10)
            }
        }
        .background(isSelected ? OverlayTheme.surfaceSelected : OverlayTheme.surface,
                    in: RoundedRectangle(cornerRadius: OverlayTheme.keyRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OverlayTheme.keyRadius, style: .continuous)
                .strokeBorder(isSelected ? OverlayTheme.primary : (contrast == .increased ? Color.white.opacity(0.5) : OverlayTheme.border),
                              lineWidth: isSelected ? 1.5 : 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: OverlayTheme.hoverDuration), value: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: OverlayTheme.keyRadius))
        .accessibilityElement(children: .ignore)
    }

    @ViewBuilder
    private func appIcon(_ candidate: Candidate, size: CGFloat) -> some View {
        if let icon = icons[candidate.groupID] {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: size - 3, weight: .light))
                .foregroundStyle(OverlayTheme.secondaryText)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    private func keyLabelSize(width: CGFloat) -> CGFloat {
        max(12, min(18, width * 0.12))
    }

    private var footer: some View {
        VStack(spacing: 7) {
            Rectangle().fill(OverlayTheme.border).frame(height: 1)
            HStack(spacing: 7) {
                if let message, !message.isEmpty {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(OverlayTheme.warning)
                    Text(message)
                        .foregroundStyle(OverlayTheme.warning)
                        .lineLimit(2)
                } else if let candidate = inspectedCandidate {
                    Image(systemName: candidate.isWindow ? "macwindow" : "app")
                        .foregroundStyle(OverlayTheme.secondaryText)
                    Text(candidate.isWindow ? "\(candidate.displayName) · \(candidate.title)" : candidate.displayName)
                        .foregroundStyle(OverlayTheme.text)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(candidate.isWindow ? "切换到此窗口" : "切换到应用")
                        .foregroundStyle(OverlayTheme.secondaryText)
                        .fixedSize()
                } else {
                    Text(keyMap.isEmpty ? (isLoading ? "可随时按 Esc 关闭" : "打开应用后再次唤出")
                         : (mode == .applications ? "按键或点击应用，即刻切换" : "可定位的窗口独立显示，其余保留应用入口"))
                        .foregroundStyle(OverlayTheme.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 11))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 28, alignment: .center)
            HStack(spacing: 17) {
                shortcut("Tab", text: "切换\(mode.alternateTitle)模式")
                shortcut("← ↑ ↓ →", text: "选择")
                shortcut("↵", text: "切换")
                Spacer(minLength: 8)
                shortcut("Esc", text: "关闭")
            }
        }
    }

    private func shortcut(_ key: String, text: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(OverlayTheme.secondaryText)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(OverlayTheme.border, lineWidth: 0.5))
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(OverlayTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: message == nil ? "rectangle.stack" : "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(message == nil ? OverlayTheme.secondaryText : OverlayTheme.warning)
            }
            Text(isLoading ? "正在读取可用\(mode.title)" : (message == nil ? "暂无可切换的应用" : "暂时无法切换"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OverlayTheme.text)
            Text(isLoading ? "请稍候，也可以按 Esc 关闭" : (message == nil ? "打开一个应用窗口后，再次唤出 AppSwitcher" : "按 Esc 关闭后重新唤出，或切换模式重试"))
                .font(.system(size: 12))
                .foregroundStyle(OverlayTheme.secondaryText)
        }
        .multilineTextAlignment(.center)
        .padding(30)
        .accessibilityElement(children: .combine)
    }

    private func accessibilityTitle(_ candidate: Candidate, key: Key) -> String {
        "\(key.label)，\(candidate.displayName)" + (candidate.isWindow ? "，\(candidate.title)" : "，应用入口")
    }
}
