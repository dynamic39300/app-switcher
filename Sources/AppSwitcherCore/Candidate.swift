import Foundation

/// 一个可切换的候选条目（App 级或多窗口展开后的单个窗口）。
/// - `groupID` 相同的条目属于同一 App，分配键位时相邻平铺。
/// - `activationCount` / `lastActivatedAt` 用于按使用频率排序。
public struct Candidate: Hashable, Identifiable, Sendable {
    public let id: String
    public let groupID: String
    public let displayName: String
    public let activationCount: Int
    public let lastActivatedAt: Date

    public init(
        id: String,
        groupID: String,
        displayName: String,
        activationCount: Int = 0,
        lastActivatedAt: Date = .distantPast
    ) {
        self.id = id
        self.groupID = groupID
        self.displayName = displayName
        self.activationCount = activationCount
        self.lastActivatedAt = lastActivatedAt
    }
}
