/// 一个窗口的描述（纯值类型，来自 CGWindowList 的归一化表示）。
public struct WindowDescriptor: Hashable, Sendable {
    public let pid: Int
    public let title: String
    public let windowNumber: Int
    public let layer: Int
    public let alpha: Double
    public let width: Double
    public let height: Double

    public init(
        pid: Int,
        title: String,
        windowNumber: Int,
        layer: Int,
        alpha: Double,
        width: Double,
        height: Double
    ) {
        self.pid = pid
        self.title = title
        self.windowNumber = windowNumber
        self.layer = layer
        self.alpha = alpha
        self.width = width
        self.height = height
    }
}
