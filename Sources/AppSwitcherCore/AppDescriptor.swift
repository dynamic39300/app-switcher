/// 一个运行中 App 的描述（纯值类型，无 AppKit 依赖）。
public struct AppDescriptor: Hashable, Identifiable, Sendable {
    public let pid: Int
    public let bundleIdentifier: String
    public let displayName: String

    public var id: String { bundleIdentifier }

    public init(pid: Int, bundleIdentifier: String, displayName: String) {
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
}
