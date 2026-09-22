/// 窗口过滤（纯函数）：判定一个窗口是否为「内容窗口」。
///
/// 启发式规则（spike 实测）：
/// - 仅 layer 0（普通窗口层）
/// - alpha > 0.05（排除全透明）
/// - 宽高 ≥ 100（排除 1x1、0x0、64x64 等小窗）
/// - 高度 > 40（排除菜单栏状态条，实测 33px）
/// - 排除 500×500 占位窗（系统为带状态栏的 app 生成的假窗口）
public enum WindowFilter {
    public static func isContent(_ window: WindowDescriptor) -> Bool {
        guard window.layer == 0 else { return false }
        guard window.alpha > 0.05 else { return false }
        if window.width < 100 || window.height < 100 { return false }
        if window.height <= 40 { return false }
        if window.width == 500 && window.height == 500 { return false }
        return true
    }
}
