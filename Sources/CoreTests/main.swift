import AppSwitcherCore
import Foundation

// 最小测试运行器（无 Xcode 时的替代方案）。
// 装 Xcode 后，本文件的测试逻辑可平移为 Swift Testing（@Test/#expect）。

var passCount = 0
var failCount = 0

@MainActor
func check(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #filePath, line: Int = #line) {
    if condition() {
        passCount += 1
        print("    ✓ \(message)")
    } else {
        failCount += 1
        print("    ✗ \(message)  @\(file):\(line)")
    }
}

@MainActor
func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual == expected {
        passCount += 1
        print("    ✓ \(message)")
    } else {
        failCount += 1
        print("    ✗ \(message) — 期望 \(expected)，实际 \(actual)")
    }
}

func candidate(_ name: String, group: String? = nil, id: String? = nil) -> Candidate {
    Candidate(id: id ?? name, groupID: group ?? name, displayName: name)
}

func rankedCandidate(_ id: String, group: String, name: String, count: Int, daysAgo: Int) -> Candidate {
    Candidate(
        id: id, groupID: group, displayName: name, activationCount: count,
        lastActivatedAt: Date(timeIntervalSinceNow: TimeInterval(-daysAgo * 86400))
    )
}

func keys(_ result: [Key: Candidate]) -> [String: String] {
    Dictionary(uniqueKeysWithValues: result.map { ($0.key.label, $0.value.id) })
}

// MARK: - KeyAssigner

@MainActor
func testKeyAssigner() {
    print("KeyAssigner 键位分配")

    let input = [candidate("Safari"), candidate("Slack"), candidate("Spotify"), candidate("Mail")]
    check(KeyAssigner.assign(input) == KeyAssigner.assign(input), "确定性（同输入同输出）")

    var r = keys(KeyAssigner.assign([candidate("Safari"), candidate("Mail"), candidate("Terminal")]))
    expectEqual(r["S"], "Safari", "首字母 mnemonic：Safari→S")
    expectEqual(r["M"], "Mail", "首字母 mnemonic：Mail→M")
    expectEqual(r["T"], "Terminal", "首字母 mnemonic：Terminal→T")

    r = keys(KeyAssigner.assign([candidate("Safari"), candidate("Slack"), candidate("Spotify")]))
    expectEqual(r["S"], "Safari", "冲突：Safari 占 S")
    expectEqual(r["A"], "Slack", "冲突：Slack 就近让到 A")
    expectEqual(r["D"], "Spotify", "冲突：Spotify 就近让到 D")

    r = keys(KeyAssigner.assign([
        candidate("ChatGPT", group: "codex", id: "codex-1"),
        candidate("ChatGPT", group: "codex", id: "codex-2"),
        candidate("ChatGPT", group: "codex", id: "codex-3"),
    ]))
    expectEqual(r["C"], "codex-1", "多窗口平铺：第 1 个→C")
    expectEqual(r["V"], "codex-2", "多窗口平铺：第 2 个→V")
    expectEqual(r["B"], "codex-3", "多窗口平铺：第 3 个→B")

    r = keys(KeyAssigner.assign([candidate("微信")]))
    expectEqual(r["1"], "微信", "非字母名→数字行 1")

    var overflow: [Candidate] = []
    for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
        overflow.append(candidate("App \(c)", group: "app-\(c)"))
    }
    overflow.append(candidate("App AA", group: "app-aa"))
    overflow.append(candidate("App BB", group: "app-bb"))
    r = keys(KeyAssigner.assign(overflow))
    check(r.count == 28, "溢出：28 个候选全部有键位")
    expectEqual(r["1"], "App AA", "溢出：第 27 个→1")
    expectEqual(r["2"], "App BB", "溢出：第 28 个→2")
}

// MARK: - AppRanker

@MainActor
func testAppRanker() {
    print("AppRanker 排序")

    let a = rankedCandidate("a", group: "ga", name: "A", count: 1, daysAgo: 0)
    let b = rankedCandidate("b", group: "gb", name: "B", count: 9, daysAgo: 0)
    let c = rankedCandidate("c", group: "gc", name: "C", count: 5, daysAgo: 0)
    check(AppRanker.rank([a, b, c]).map(\.id) == ["b", "c", "a"], "按激活次数降序")

    let ra = rankedCandidate("a", group: "ga", name: "A", count: 3, daysAgo: 10)
    let rb = rankedCandidate("b", group: "gb", name: "B", count: 3, daysAgo: 1)
    check(AppRanker.rank([ra, rb]).map(\.id) == ["b", "a"], "次数相同按最近使用降序")

    let c1 = rankedCandidate("codex-1", group: "codex", name: "ChatGPT", count: 8, daysAgo: 0)
    let c2 = rankedCandidate("codex-2", group: "codex", name: "ChatGPT", count: 8, daysAgo: 0)
    let c3 = rankedCandidate("codex-3", group: "codex", name: "ChatGPT", count: 8, daysAgo: 0)
    let sf = rankedCandidate("safari", group: "safari", name: "Safari", count: 2, daysAgo: 0)
    check(
        AppRanker.rank([sf, c1, c2, c3]).map(\.id) == ["codex-1", "codex-2", "codex-3", "safari"],
        "同 App 多窗口保持相邻"
    )
}

// MARK: - 运行

testKeyAssigner()
testAppRanker()

print("")
if failCount == 0 {
    print("✅ 全部通过：\(passCount) 项")
} else {
    print("❌ \(failCount) 项失败，\(passCount) 项通过")
}
exit(failCount == 0 ? 0 : 1)
