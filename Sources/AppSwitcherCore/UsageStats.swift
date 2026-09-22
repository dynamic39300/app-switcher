import Foundation

/// 单个 App 的使用统计（用于 rank 排序）。
public struct UsageStats: Hashable, Sendable, Codable {
    public var activationCount: Int
    public var lastActivatedAt: Date

    public init(activationCount: Int = 0, lastActivatedAt: Date = .distantPast) {
        self.activationCount = activationCount
        self.lastActivatedAt = lastActivatedAt
    }
}
