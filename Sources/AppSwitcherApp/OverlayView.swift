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
    var onQuit: ((Key) -> Void)? = nil
    var onMoveEnded: (() -> Void)? = nil
    var style: OverlayStyle = .graphite
    var onChangeStyle: ((OverlayStyle) -> Void)? = nil
    var appearanceNotice: String? = nil
    var onRemap: ((Key, Key, String) -> Bool)? = nil
    var onDragStateChanged: ((Bool) -> Void)? = nil
    var savedBindings: [String: String] = [:]
    var showsDragGuide = false
    var onChangeDragGuide: ((Bool) -> Void)? = nil
    var guideRevision = 0
    var interactionRevision = 0
    var onResetBindings: ((String?) -> Void)? = nil
    var feedbackIsSuccess = false
    var previewQuitControls = false

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isMovingWindow = false
    @GestureState private var keyGestureActive = false
    @State private var keyFrames: [Key: CGRect] = [:]
    @State private var keyViewport: CGRect = .zero
    @State private var draggedKey: KeyDragSnapshot?
    @State private var landingKey: Key?
    @State private var guide: KeyGuideSample?
    @State private var guideProgress: CGFloat = 0
    @State private var guideLanded = false
    @State private var guideStopped = false
    @State private var lastGuideRevision: Int?
    @State private var confirmsReset = false
    @State private var hoveredKey: Key?
    @State private var hoveredQuitKey: Key?
    @AccessibilityFocusState private var accessibilityFocusedQuitKey: Key?
    @Namespace private var keyMotion

    private var hasNumberRow: Bool { keyMap.keys.contains { !$0.isLetter } }
    private var rows: [[Key]] {
        let letters = (0...2).map { y in Key.letters.filter { $0.y == y } }
        return hasNumberRow ? [Key.numberRow] + letters : letters
    }
    private var inspectedCandidate: Candidate? { selectedKey.flatMap { keyMap[$0] } }
    private var palette: OverlayPalette { OverlayPalette(style: style) }
    private var canRemap: Bool { mode == .applications && !isLoading && onRemap != nil }
    private var dropKey: Key? {
        guard let draggedKey else { return nil }
        return key(at: draggedKey.location)
    }

    static func preferredSize(in availableSize: CGSize, hasNumberRow: Bool = false) -> CGSize {
        let width = max(1, min(availableSize.width * OverlayTheme.panelWidthFraction,
                               availableSize.width - OverlayTheme.screenInset * 2,
                               OverlayTheme.maximumPanelWidth))
        let columns = CGFloat(hasNumberRow ? 12 : 10)
        let rows: CGFloat = hasNumberRow ? 4 : 3
        let keyboardWidth = max(1, width - OverlayTheme.panelPadding * 2)
        let keyWidth = max(1, (keyboardWidth - (columns - 1) * OverlayTheme.keyGap) / columns)
        let keyHeight = max(OverlayTheme.minimumKeyHeight, keyWidth * OverlayTheme.maximumKeyAspectRatio)
        let contentHeight = rows * keyHeight + (rows - 1) * OverlayTheme.keyGap + OverlayTheme.panelChromeHeight
        return CGSize(width: width, height: max(1, min(availableSize.height * OverlayTheme.panelHeightFraction,
                                                     availableSize.height - OverlayTheme.screenInset * 2,
                                                     contentHeight)))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .frame(height: 42)
                    .padding(.bottom, 12)
                if let appearanceNotice {
                    Text(appearanceNotice).font(.system(size: 11)).foregroundStyle(palette.warning)
                        .fixedSize(horizontal: false, vertical: true).padding(.bottom, 8)
                        .accessibilityLabel(appearanceNotice)
                }
                if canRemap && showsDragGuide && !keyMap.isEmpty { dragGuideBar.padding(.bottom, 8) }
                if keyMap.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeometryReader { keyboardGeometry in
                        themedKeyboard(size: keyboardGeometry.size)
                            .preference(key: KeyViewportPreference.self, value: keyboardGeometry.frame(in: .named("key-drag")))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                footer
                    .padding(.top, 12)
            }
            .padding(OverlayTheme.panelPadding)
        }
        .coordinateSpace(name: "key-drag")
        .onPreferenceChange(KeyFramePreference.self) { keyFrames = $0 }
        .onPreferenceChange(KeyViewportPreference.self) { keyViewport = $0 }
        .overlay { dragVisuals }
        .background {
            // Only the background participates: candidate and toolbar buttons keep their clicks.
            palette.panelGradient
                .gesture(moveGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: OverlayTheme.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OverlayTheme.panelRadius, style: .continuous)
                .strokeBorder(contrast == .increased ? palette.strongBorder : palette.border, lineWidth: 1)
        }
        .preferredColorScheme(style.colorScheme)
        .onChange(of: isMovingWindow) { wasMoving, isMoving in
            // Native window movement can cancel rather than end a SwiftUI gesture.
            // GestureState resets on both paths, after WindowServer releases the drag.
            if wasMoving && !isMoving { onMoveEnded?() }
            if isMoving { stopGuide() }
        }
        .onChange(of: keyGestureActive) { _, active in
            if !active { draggedKey = nil; onDragStateChanged?(false) }
        }
        .onChange(of: interactionRevision) { _, _ in stopGuide() }
        .onChange(of: keyViewport) { _, _ in if guide != nil { stopGuide() } }
        .onChange(of: keyFrames) { _, _ in if guide != nil { stopGuide() } }
        .onChange(of: style) { _, _ in stopGuide(); cancelDrag() }
        .onChange(of: mode) { _, _ in stopGuide(); cancelDrag(); hoveredKey = nil; hoveredQuitKey = nil }
        .onDisappear { cancelDrag(); stopGuide(); hoveredKey = nil }
        .task(id: KeyGuideRequest(enabled: showsDragGuide, revision: guideRevision, mode: mode)) { await playGuide() }
        .task(id: landingKey) {
            guard landingKey != nil else { return }
            try? await Task.sleep(for: .milliseconds(650))
            if !Task.isCancelled { landingKey = nil }
        }
        .confirmationDialog("恢复所有应用的默认键位？", isPresented: $confirmsReset) {
            Button("恢复默认键位") { stopGuide(); onResetBindings?(nil) }
            Button("取消", role: .cancel) {}
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("AppSwitcher，切换\(mode.title)")
    }

    private var header: some View {
        HStack(spacing: 11) {
            headerDragArea
            if canRemap { remappingMenu }
            appearanceButtons
            HStack(spacing: 3) {
                modeButton(.applications, symbol: "square.grid.2x2")
                modeButton(.windows, symbol: "macwindow.on.rectangle")
            }
            .padding(3)
            .background(palette.base.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            if let onSettings {
                Button(action: onSettings) {
                    Label("设置", systemImage: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("打开设置（⌘,）")
                .accessibilityLabel("设置，打开快捷键设置")
            }
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("关闭（Esc）")
            .accessibilityLabel("关闭切换器")
        }
    }

    private var moveGesture: some Gesture {
        WindowDragGesture().updating($isMovingWindow) { _, state, _ in state = true }
    }

    private var appearanceButtons: some View {
        HStack(spacing: 2) {
            ForEach(OverlayStyle.allCases, id: \.rawValue) { option in
                Button { onChangeStyle?(option) } label: {
                    Text(option.shortTitle)
                        .font(.system(size: 11, weight: option == style ? .semibold : .regular))
                        .foregroundStyle(option == style ? palette.text : palette.secondaryText)
                        .padding(.horizontal, 9).frame(height: 28)
                        .background(option == style ? palette.surfaceHover : .clear, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("外观：\(option.title)")
                .accessibilityAddTraits(option == style ? .isSelected : [])
                .help("\(option.title)（⌘\(option.number)）")
            }
        }
        .padding(3)
        .background(palette.base.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("外观样式")
    }

    @ViewBuilder
    private func themedKeyboard(size: CGSize) -> some View {
        let placement = style.detailPlacement(in: size, hasNumberRow: hasNumberRow)
        if placement == .side {
            HStack(spacing: 16) {
                targetDetail(vertical: true)
                    .frame(width: min(210, size.width * 0.17))
                GeometryReader { inner in keyboardRegion(size: inner.size) }
            }
        } else if placement == .top {
            VStack(spacing: 12) {
                targetDetail(vertical: false).frame(height: 68)
                GeometryReader { inner in keyboardRegion(size: inner.size) }
            }
        } else {
            keyboardRegion(size: size)
        }
    }

    private func targetDetail(vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18)) : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            if let candidate = inspectedCandidate {
                appIcon(candidate, size: vertical ? 96 : 58)
                VStack(alignment: .leading, spacing: 7) {
                    Text(candidate.displayName).font(.system(size: vertical ? 22 : 18, weight: .semibold))
                        .foregroundStyle(palette.text).lineLimit(2)
                    Text(candidate.isWindow ? candidate.title : (mode == .windows ? "应用入口" : "切换到应用"))
                        .font(.system(size: 12)).foregroundStyle(palette.secondaryText)
                        .lineLimit(vertical ? 4 : 2)
                }
                if !vertical { Spacer(minLength: 0) }
                if let selectedKey {
                    Text("\(selectedKey.label)  ↵")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.primary)
                }
            } else { Text("选择一个目标").foregroundStyle(palette.secondaryText) }
        }
        .padding(vertical ? 16 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: vertical ? .leading : .center)
        .contentShape(Rectangle()).gesture(moveGesture)
        .accessibilityElement(children: .combine)
    }

    private var headerDragArea: some View {
        HStack(spacing: 11) {
            AppBrandMark()
            VStack(alignment: .leading, spacing: 2) {
                Text("AppSwitcher")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(headerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 12)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(moveGesture)
        .help("按住空白区域拖动，可移至其他屏幕")
    }

    private var headerSubtitle: String {
        if isLoading { return "正在读取可用\(mode.title)…" }
        if mode == .applications { return "\(keyMap.count) 个应用" }
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
            .foregroundStyle(buttonMode == mode ? palette.text : palette.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(buttonMode == mode ? palette.surfaceHover : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换\(buttonMode.title)模式")
        .accessibilityAddTraits(buttonMode == mode ? .isSelected : [])
        .help("切换\(buttonMode.title)模式（Tab）")
    }

    @ViewBuilder
    private func keyboardRegion(size: CGSize) -> some View {
        let rowCount = CGFloat(rows.count)
        let columns = CGFloat(hasNumberRow ? 12 : 10)
        let keyWidth = max(1, (size.width - (columns - 1) * OverlayTheme.keyGap) / columns)
        let minimumHeight = max(OverlayTheme.minimumKeyHeight, keyWidth)
        let rowHeight = (size.height - (rowCount - 1) * OverlayTheme.keyGap) / rowCount
        if rowHeight < minimumHeight {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    keyboard(width: size.width, keyHeight: minimumHeight)
                }
                .scrollIndicators(.visible)
                .onAppear { revealSelection(using: proxy) }
                .onChange(of: selectedKey) { _, _ in revealSelection(using: proxy) }
            }
        } else {
            keyboard(width: size.width, keyHeight: min(rowHeight, keyWidth * OverlayTheme.maximumKeyAspectRatio))
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
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(key: KeyFramePreference.self,
                                        value: [key: geometry.frame(in: .named("key-drag"))])
                                }
                            }
                            .overlay {
                                if key == dropKey || key == guide?.destination || key == landingKey {
                                    RoundedRectangle(cornerRadius: OverlayTheme.keyRadius)
                                        .strokeBorder(palette.primary, style: StrokeStyle(lineWidth: 2.5,
                                            dash: guide != nil && !guideLanded ? [5, 4] : []))
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.15), value: keyMap)
    }

    @ViewBuilder
    private func keycap(_ key: Key, width: CGFloat, height: CGFloat) -> some View {
        if let candidate = keyMap[key] {
            ZStack(alignment: .topTrailing) {
                Button { if draggedKey == nil { stopGuide(); onActivate(key) } } label: {
                    populatedKeycap(key, candidate: candidate, width: max(1, width - 8), height: max(1, height - 10))
                }
                .buttonStyle(MaterialKeycapStyle(style: style, selected: selectedKey == key, hovered: hoveredKey == key))
                .onHover { hovering in hoveredKey = hovering ? key : (hoveredKey == key ? nil : hoveredKey) }
                .disabled(isLoading)
                .opacity(draggedKey?.source == key ? 0.3 : 1)
                .highPriorityGesture(keyDrag(from: key, candidate: candidate), including: canRemap ? .all : .none)
                .help(accessibilityTitle(candidate, key: key))
                .accessibilityLabel(accessibilityTitle(candidate, key: key))
                .accessibilityHint(candidate.isWindow ? "切换到这个窗口" : "切换到这个应用")
                .accessibilityAddTraits(selectedKey == key ? .isSelected : [])
                .contextMenu {
                    if canRemap {
                        Menu("移到按键") {
                            ForEach(Key.all, id: \.label) { destination in
                                Button(destination.label) { stopGuide(); _ = onRemap?(key, destination, candidate.id) }
                                    .disabled(destination == key)
                            }
                        }
                        if savedBindings[candidate.groupID] != nil {
                            Button("恢复自动分配", systemImage: "arrow.uturn.backward") {
                                stopGuide(); onResetBindings?(candidate.groupID)
                            }
                        }
                    }
                }
                if mode == .applications, onQuit != nil, !isLoading, draggedKey == nil,
                   candidate.groupID != "com.apple.finder" {
                    Button {
                        stopGuide()
                        onQuit?(key)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(palette.warning)
                            .frame(width: 28, height: 28)
                            .background(palette.base.opacity(0.94), in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(3)
                    .opacity(hoveredQuitKey == key || accessibilityFocusedQuitKey == key || previewQuitControls ? 1 : 0.01)
                    .allowsHitTesting(hoveredQuitKey == key || accessibilityFocusedQuitKey == key || previewQuitControls)
                    .help("退出「\(candidate.displayName)」应用（关闭所有窗口）")
                    .accessibilityLabel("退出「\(candidate.displayName)」应用，关闭所有窗口")
                    .accessibilityFocused($accessibilityFocusedQuitKey, equals: key)
                }
            }
            .onHover { inside in
                if inside && draggedKey == nil {
                    hoveredQuitKey = key
                    onSelect(key)
                } else if hoveredQuitKey == key { hoveredQuitKey = nil }
            }
        } else {
            VStack {
                HStack {
                    Spacer()
                    Text(key.label)
                        .font(.system(size: keyLabelSize(width: width), weight: .medium, design: .monospaced))
                        .foregroundStyle(contrast == .increased ? palette.secondaryText : palette.mutedText)
                }
                Spacer()
            }
            .padding(10)
            .frame(width: width, height: height)
            .background(palette.emptySurface, in: RoundedRectangle(cornerRadius: OverlayTheme.keyRadius))
            .overlay {
                RoundedRectangle(cornerRadius: OverlayTheme.keyRadius)
                    .strokeBorder(contrast == .increased ? palette.strongBorder : palette.border, lineWidth: 1)
            }
            .accessibilityHidden(true)
            .contentShape(Rectangle())
            .gesture(moveGesture)
        }
    }

    private func populatedKeycap(_ key: Key, candidate: Candidate, width: CGFloat, height: CGFloat) -> some View {
        let isSelected = selectedKey == key
        let compactContent = width < 85 || height < 105
        let nameSize = max(11, min(16, width * 0.105, height * 0.105))
        let detailSize = max(10, min(12, nameSize - 1))
        let spacing: CGFloat = height > 140 ? 8 : 3
        // 先为两行名称、窗口说明留位，剩余空间再用于图标；不再按固定 64pt 封顶。
        let detailHeight = compactContent ? 0 : (candidate.isWindow ? detailSize * 2.5 : (mode == .windows ? detailSize * 1.25 : 0))
        let textHeight = nameSize * (compactContent ? 1.4 : 2.5) + detailHeight + spacing * (detailHeight > 0 ? 2 : 1)
        let topReserve: CGFloat = compactContent ? 4 : 8
        let preferredIconSize = max(18, min(width * 0.68, height * 0.52, height - 16 - textHeight))
        let inlineKeyLabel = width < 70 || (height - preferredIconSize - textHeight) / 2 < keyLabelSize(width: width) + 20
        let keyLabelWidth = ceil(keyLabelSize(width: width) * 0.75)
        let iconWidth = width - 14 - (inlineKeyLabel ? keyLabelWidth + 2 : 0)
        let iconSize = min(preferredIconSize, max(18, iconWidth))
        return VStack(spacing: spacing) {
            if inlineKeyLabel {
                // 图标接近右上角键标时改为并排，短屏和长标题也不互相遮挡。
                HStack(alignment: .top, spacing: 2) {
                    if mode == .applications { keyLabel(key, width: width, selected: isSelected).frame(width: keyLabelWidth) }
                    appIcon(candidate, size: iconSize).matchedGeometryEffect(id: candidate.id, in: keyMotion)
                        .frame(maxWidth: .infinity)
                    if mode == .windows { keyLabel(key, width: width, selected: isSelected).frame(width: keyLabelWidth) }
                }
            } else {
                appIcon(candidate, size: iconSize).matchedGeometryEffect(id: candidate.id, in: keyMotion)
            }
            Text(candidate.displayName)
                .font(.system(size: nameSize, weight: .medium))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
                .lineLimit(compactContent ? 1 : 2)
                .truncationMode(.tail)
                .minimumScaleFactor(compactContent ? 0.85 : 1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            if candidate.isWindow && !compactContent {
                Text(candidate.title)
                    .font(.system(size: detailSize))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            } else if mode == .windows && !compactContent {
                Text("应用入口")
                    .font(.system(size: detailSize))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 7)
        .padding(.top, topReserve)
        .padding(.bottom, compactContent ? 4 : 8)
        .frame(width: width, height: height)
        .overlay(alignment: mode == .applications ? .topLeading : .topTrailing) {
            if !inlineKeyLabel {
                keyLabel(key, width: width, selected: isSelected)
                    .padding(10)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: OverlayTheme.hoverDuration), value: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: OverlayTheme.keyRadius))
        .accessibilityElement(children: .ignore)
    }

    private func keyLabel(_ key: Key, width: CGFloat, selected: Bool) -> some View {
        Text(key.label)
            .font(.system(size: keyLabelSize(width: width), weight: .semibold, design: .monospaced))
            .foregroundStyle(selected ? palette.primary : palette.secondaryText)
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
                .foregroundStyle(palette.secondaryText)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    private func keyLabelSize(width: CGFloat) -> CGFloat {
        max(12, min(18, width * 0.12))
    }

    private var remappingMenu: some View {
        Menu {
            Toggle("唤醒时显示拖拽引导", isOn: Binding(get: { showsDragGuide }, set: { onChangeDragGuide?($0) }))
            Button("重播拖拽引导", systemImage: "arrow.clockwise") { onChangeDragGuide?(true) }
            Divider()
            Button("恢复默认键位", systemImage: "arrow.uturn.backward") { confirmsReset = true }
                .disabled(savedBindings.isEmpty && appearanceNotice == nil)
        } label: {
            Image(systemName: "hand.draw").font(.system(size: 15))
                .foregroundStyle(palette.secondaryText).frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help("拖拽引导与键位设置").accessibilityLabel("拖拽与键位设置")
    }

    private var dragGuideBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.point.up.left").foregroundStyle(palette.primary)
            Text(dragHint).foregroundStyle(palette.secondaryText).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                stopGuide()
                onChangeDragGuide?(false)
            } label: {
                Label("不再提示", systemImage: "xmark").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(palette.secondaryText)
            .accessibilityLabel("不再显示拖拽引导")
        }
        .font(.system(size: 12)).frame(height: 24)
    }

    private var dragHint: String {
        if let draggedKey, let destination = dropKey, destination != draggedKey.source {
            return keyMap[destination] == nil ? "松手移到 \(destination.label)" : "松手与 \(destination.label) 交换"
        }
        if let guide {
            return "拖拽演示 \(guide.source.label) → \(guide.destination.label) · 试着把图标拖到另一个按键"
        }
        return "把图标拖到新按键，松手即可保存；已有图标时交换位置"
    }

    private func key(at point: CGPoint) -> Key? {
        guard keyViewport.contains(point) else { return nil }
        return Key.all.first { keyFrames[$0]?.contains(point) == true }
    }

    private func keyDrag(from source: Key, candidate: Candidate) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("key-drag"))
            .updating($keyGestureActive) { _, active, _ in active = true }
            .onChanged { value in
                guard canRemap, keyMap[source]?.id == candidate.id else { return }
                stopGuide()
                draggedKey = KeyDragSnapshot(source: source, candidateID: candidate.id,
                                              candidate: candidate, location: value.location)
                onDragStateChanged?(true)
            }
            .onEnded { value in
                let destination = key(at: value.location)
                cancelDrag()
                guard canRemap, let destination, destination != source,
                      keyMap[source]?.id == candidate.id else { return }
                if onRemap?(source, destination, candidate.id) == true { landingKey = destination }
            }
    }

    private func cancelDrag() {
        draggedKey = nil
        onDragStateChanged?(false)
    }

    private func stopGuide() {
        guideStopped = true
        guide = nil
    }

    @ViewBuilder
    private var dragVisuals: some View {
        GeometryReader { _ in
            if let draggedKey, let frame = keyFrames[draggedKey.source] {
                KeyDragVisual(icon: icons[draggedKey.candidate.groupID], size: min(72, frame.width * 0.65),
                              location: draggedKey.location, palette: palette)
            } else if let guide {
                Path { path in path.move(to: guide.start); path.addLine(to: guide.end) }
                    .stroke(palette.primary.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                let position = CGPoint(x: guide.start.x + (guide.end.x - guide.start.x) * guideProgress,
                                       y: guide.start.y + (guide.end.y - guide.start.y) * guideProgress)
                KeyDragVisual(icon: icons[guide.candidate.groupID], size: guide.size, location: position,
                              palette: palette, showsPointer: true, landed: guideLanded)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    @MainActor
    private func playGuide() async {
        guide = nil
        guideStopped = false
        guard canRemap, showsDragGuide, !keyMap.isEmpty, lastGuideRevision != guideRevision else { return }
        lastGuideRevision = guideRevision
        do {
            try await Task.sleep(for: .milliseconds(550))
            guard !guideStopped, draggedKey == nil else { return }
            let visible = Key.all.filter { keyFrames[$0].map { keyViewport.insetBy(dx: -1, dy: -1).contains($0) } == true }
            guard let source = visible.first(where: { keyMap[$0] != nil }), let candidate = keyMap[source],
                  let startFrame = keyFrames[source] else { return }
            let targets = visible.filter { $0 != source }
            let destination = targets.sorted { lhs, rhs in
                let leftEmpty = keyMap[lhs] == nil, rightEmpty = keyMap[rhs] == nil
                if leftEmpty != rightEmpty { return leftEmpty }
                let left = keyFrames[lhs]!, right = keyFrames[rhs]!
                return hypot(left.midX - startFrame.midX, left.midY - startFrame.midY)
                    < hypot(right.midX - startFrame.midX, right.midY - startFrame.midY)
            }.first
            guard let destination, let endFrame = keyFrames[destination] else { return }
            guideProgress = reduceMotion ? 1 : 0
            guideLanded = false
            guide = KeyGuideSample(source: source, destination: destination, candidate: candidate,
                                   start: CGPoint(x: startFrame.midX, y: startFrame.midY - startFrame.height * 0.1),
                                   end: CGPoint(x: endFrame.midX, y: endFrame.midY - endFrame.height * 0.1),
                                   size: min(64, startFrame.width * 0.6))
            try await Task.sleep(for: .milliseconds(400))
            guard !guideStopped else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.1)) { guideProgress = 1 }
            try await Task.sleep(for: .milliseconds(1150))
            guard !guideStopped else { return }
            guideLanded = true
            try await Task.sleep(for: .milliseconds(850))
            guard !guideStopped else { return }
            guide = nil
        } catch { }
    }

    private var footer: some View {
        VStack(spacing: 7) {
            Rectangle().fill(palette.border).frame(height: 1)
            HStack(spacing: 7) {
                if let message, !message.isEmpty {
                    Image(systemName: feedbackIsSuccess ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundStyle(feedbackIsSuccess ? palette.primary : palette.warning)
                    Text(message)
                        .foregroundStyle(feedbackIsSuccess ? palette.primary : palette.warning)
                        .lineLimit(2)
                } else if let candidate = inspectedCandidate {
                    Image(systemName: candidate.isWindow ? "macwindow" : "app")
                        .foregroundStyle(palette.secondaryText)
                    Text(candidate.isWindow ? "\(candidate.displayName) · \(candidate.title)" : candidate.displayName)
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                } else {
                    Text(keyMap.isEmpty ? (isLoading ? "可随时按 Esc 关闭" : "打开应用后再次唤出")
                         : (mode == .applications ? "按键或点按切换应用" : "窗口可单独选择，其余保留应用入口"))
                        .foregroundStyle(palette.secondaryText)
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
        .contentShape(Rectangle())
        .gesture(moveGesture)
    }

    private func shortcut(_ key: String, text: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(palette.border, lineWidth: 0.5))
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(palette.secondaryText)
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
                    .foregroundStyle(message == nil ? palette.secondaryText : palette.warning)
            }
            Text(isLoading ? "正在读取可用\(mode.title)" : (message == nil ? "暂无可切换的应用" : "暂时无法切换"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.text)
            Text(isLoading ? "请稍候，也可以按 Esc 关闭" : (message == nil ? "打开一个应用窗口后，再次唤出 AppSwitcher" : "按 Esc 关闭后重新唤出，或切换模式重试"))
                .font(.system(size: 12))
                .foregroundStyle(palette.secondaryText)
        }
        .multilineTextAlignment(.center)
        .padding(30)
        .accessibilityElement(children: .combine)
        .contentShape(Rectangle())
        .gesture(moveGesture)
    }

    private func accessibilityTitle(_ candidate: Candidate, key: Key) -> String {
        "\(key.label)，\(candidate.displayName)" + (candidate.isWindow ? "，\(candidate.title)" : "，应用入口")
    }
}
