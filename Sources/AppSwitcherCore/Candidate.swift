import Foundation

/// 控制身份与展示标题分离；窗口 token 只在当前覆盖层会话内有效。
public enum CandidateTarget: Hashable, Sendable {
    case application(pid: Int)
    case window(pid: Int, token: String)

    public var pid: Int {
        switch self {
        case .application(let pid), .window(let pid, _): return pid
        }
    }
}

public enum ActivationResult: Equatable, Sendable {
    case success
    case failure(String)
}

/// 一个可切换的候选条目（App 级或多窗口展开后的单个窗口）。
/// - `groupID` 相同的条目属于同一 App，分配键位时相邻平铺。
/// - `activationCount` / `lastActivatedAt` 用于按使用频率排序。
public struct Candidate: Hashable, Identifiable, Sendable {
    public let id: String
    public let groupID: String
    public let displayName: String
    /// 临时展示的窗口标题；不作为控制身份或持久化数据。
    public let title: String
    public let target: CandidateTarget
    /// 当前快照已枚举的窗口数；0 表示没有枚举到，不代表应用没有窗口。
    public let windowCount: Int
    /// 绑定到产生此候选时的进程实例，避免后续快照覆盖旧候选的启动时间。
    public let processLaunchDate: Date?
    public let activationCount: Int
    public let lastActivatedAt: Date

    public var isWindow: Bool {
        if case .window = target { return true }
        return false
    }

    public init(
        id: String,
        groupID: String,
        displayName: String,
        title: String = "",
        activationCount: Int = 0,
        lastActivatedAt: Date = .distantPast,
        target: CandidateTarget = .application(pid: 0),
        windowCount: Int = 0,
        processLaunchDate: Date? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.displayName = displayName
        self.title = title
        self.target = target
        self.windowCount = max(0, windowCount)
        self.processLaunchDate = processLaunchDate
        self.activationCount = activationCount
        self.lastActivatedAt = lastActivatedAt
    }
}
