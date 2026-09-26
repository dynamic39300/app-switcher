import Foundation

/// 候选排序（纯函数）：按使用频率/最近使用排序，并保持同一 App 的条目相邻。
public enum AppRanker {
    /// 返回排序后的候选：组间按（最大激活次数 desc → 最近激活 desc → groupID asc），
    /// 组内按显示标题排序；短期控制 token 不参与正常顺序，避免快照更新打乱键位。
    public static func rank(_ candidates: [Candidate]) -> [Candidate] {
        let grouped = Dictionary(grouping: candidates, by: \.groupID)
        let sortedGroups = grouped.values.sorted { a, b in
            let (aCount, aRecent) = (
                a.map(\.activationCount).max() ?? 0,
                a.map(\.lastActivatedAt).max() ?? .distantPast
            )
            let (bCount, bRecent) = (
                b.map(\.activationCount).max() ?? 0,
                b.map(\.lastActivatedAt).max() ?? .distantPast
            )
            if aCount != bCount { return aCount > bCount }
            if aRecent != bRecent { return aRecent > bRecent }
            return (a.first?.groupID ?? "") < (b.first?.groupID ?? "")
        }
        return sortedGroups.flatMap { group in
            group.sorted {
                if $0.title != $1.title { return $0.title < $1.title }
                return $0.id < $1.id
            }
        }
    }
}
