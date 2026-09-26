/// 窗口探测结果。真实 AX 对象留在适配器，Core 只接收快照 token 和能力。
public struct WindowDescriptor: Hashable, Sendable {
    public let pid: Int
    public let title: String
    public let windowNumber: Int
    public let layer: Int
    public let alpha: Double
    public let width: Double
    public let height: Double
    public let targetToken: String?
    public let canRaise: Bool
    public let canSetMain: Bool

    public init(
        pid: Int,
        title: String,
        windowNumber: Int,
        layer: Int,
        alpha: Double,
        width: Double,
        height: Double,
        targetToken: String? = nil,
        canRaise: Bool = false,
        canSetMain: Bool = false
    ) {
        self.pid = pid
        self.title = title
        self.windowNumber = windowNumber
        self.layer = layer
        self.alpha = alpha
        self.width = width
        self.height = height
        self.targetToken = targetToken
        self.canRaise = canRaise
        self.canSetMain = canSetMain
    }
}
