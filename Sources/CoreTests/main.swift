import AppSwitcherCore
import AppSwitcherKit
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

// MARK: - WindowFilter

@MainActor
func testWindowFilter() {
    print("WindowFilter 窗口过滤")

    func w(_ layer: Int = 0, alpha: Double = 1, width: Double = 800, height: Double = 600) -> WindowDescriptor {
        WindowDescriptor(pid: 1, title: "", windowNumber: 1, layer: layer, alpha: alpha, width: width, height: height)
    }

    check(WindowFilter.isContent(w()), "普通窗口通过")
    check(!WindowFilter.isContent(w(3)), "非 layer0 排除")
    check(!WindowFilter.isContent(w(alpha: 0)), "全透明排除")
    check(!WindowFilter.isContent(w(width: 64, height: 64)), "小窗排除")
    check(!WindowFilter.isContent(w(width: 1512, height: 33)), "菜单栏条排除")
    check(!WindowFilter.isContent(w(width: 500, height: 500)), "500x500 占位窗排除")
}

// MARK: - CandidateFactory

@MainActor
func testCandidateFactory() {
    print("CandidateFactory 能力与身份")
    let app = AppDescriptor(pid: 42, bundleIdentifier: "fixture", displayName: "Fixture")
    let other = AppDescriptor(pid: 43, bundleIdentifier: "fixture", displayName: "Fixture")
    func window(_ token: String?, _ title: String, raise: Bool = true, main: Bool = true) -> WindowDescriptor {
        WindowDescriptor(pid: 42, title: title, windowNumber: 100, layer: 0, alpha: 1, width: 800, height: 600,
                         targetToken: token, canRaise: raise, canSetMain: main)
    }
    func make(_ windows: [WindowDescriptor], unavailable: Set<Int> = []) -> [Candidate] {
        CandidateFactory.makeWindowCandidates(apps: [app], windows: windows, unavailablePIDs: unavailable)
    }
    func isFallback(_ candidates: [Candidate]) -> Bool {
        candidates.count == 1 && candidates[0].target == .application(pid: 42) && candidates[0].title.isEmpty
    }
    let applications = CandidateFactory.makeApplicationCandidates(apps: [app, other])
    check(applications.count == 2, "同bundle的不同进程各自保留入口")
    check(Set(applications.map(\.id)).count == 2, "应用身份包含PID，不误选首个同bundle进程")
    check(applications.allSatisfy { !$0.isWindow && $0.title.isEmpty }, "默认只生成应用入口，没有伪窗口编号")
    check(isFallback(make([])), "无窗口仍可切换应用")
    check(isFallback(make([window(nil, "Document")])), "仅有标题/CG编号不能冒充可控窗口")
    check(isFallback(make([window("a", ""), window("b", " \n")])), "无标题整应用回退，回归旧版数字窗口缺陷")
    check(isFallback(make([window("a", "Untitled"), window("b", "Untitled")])), "同名窗口不按标题取第一个")
    check(isFallback(make([window("a", " Mail "), window("b", "Mail")])), "去除首尾空白后同名也回退")
    check(isFallback(make([window("a", "Café"), window("b", "Cafe\u{301}")])), "Unicode等价标题不冒充可辨认窗口")
    check(isFallback(make([window("a", "One"), window("a", "Two")])), "重复控制token拒绝展开")
    check(isFallback(make([window("", "One")])), "空token拒绝展开")
    check(isFallback(make([window("a", "One", raise: false)])), "缺少窗口置前能力回退")
    check(isFallback(make([window("a", "One", main: false)])), "缺少主窗口写入能力回退")
    check(isFallback(make([window("a", "One"), window("b", "Two", raise: false)])), "同应用部分窗口不可控时整体回退")
    check(isFallback(make([window("a", "One")], unavailable: [42])), "超时/不完整快照即使含部分有效窗也回退")
    let windows = make([window("b", "Work"), window("a", "Mail")])
    check(windows.count == 2 && windows.allSatisfy(\.isWindow), "独立对象+唯一标题+能力完整时展开")
    check(windows.map(\.target) == [.window(pid: 42, token: "a"), .window(pid: 42, token: "b")], "窗口控制身份保留PID和token")
    check(windows.map(\.title) == ["Mail", "Work"], "窗口按标题稳定展示，与枚举z-order无关")
    let renamed = make([window("a", "Renamed")])
    check(renamed.first?.target == windows.first?.target, "同一token改标题不改变控制目标")
    check(renamed.first?.id == windows.first?.id, "展示名称与窗口身份解耦")
    let remaining = make([window("b", "Work")])
    check(remaining.first?.target == windows.last?.target && remaining.first?.title == "Work", "关闭别窗不重新编号目标")
    let refreshed = make([window("z", "Mail"), window("y", "Work")])
    let map1 = KeyAssigner.assign(AppRanker.rank(windows)).mapValues(\.title)
    let map2 = KeyAssigner.assign(AppRanker.rank(refreshed)).mapValues(\.title)
    check(map1 == map2, "随机token更新不打乱同标题集合键位")
    let stats = CandidateFactory.makeApplicationCandidates(apps: [app], usage: ["fixture": UsageStats(activationCount: 7)])
    check(stats.first?.activationCount == 7, "使用统计沿用bundle维度")
    let legacy = CandidateFactory.makeCandidates(apps: [app], windows: [window(nil, ""), window(nil, "")])
    check(isFallback(legacy), "旧CG入口安全降级为一个应用，原失败用例转绿")
}

@MainActor
func testKeyboardNavigation() {
    print("键盘与完整38键")
    let mapped = (UInt16(0)...UInt16(126)).compactMap { KeyInput.key(for: $0) }
    check(Set(mapped) == Set(Key.all) && mapped.count == 38, "物理键映射覆盖38键且无重复")
    check(KeyInput.key(for: 24)?.label == "+", "等号物理键触发界面加号，无需依赖输入法文本")
    check(KeyInput.key(for: 8)?.label == "C", "C键按硬件位置识别")
    check(KeyInput.key(for: 53) == nil, "Esc不会意外激活候选")
    let available: Set<Key> = [Key("Q", letter: true), Key("A", letter: true), Key("Z", letter: true), Key("1", letter: false)]
    check(KeyNavigation.move(from: nil, direction: .right, available: available)?.label == "1", "默认选择首个可用视觉键")
    check(KeyNavigation.move(from: Key("Q", letter: true), direction: .down, available: available)?.label == "A", "向下选择最近的下一排目标")
    check(KeyNavigation.move(from: Key("Q", letter: true), direction: .up, available: available)?.label == "1", "方向键能访问数字溢出行")
    check(KeyNavigation.move(from: Key("1", letter: false), direction: .left, available: available)?.label == "Z", "水平导航跳过空键并循环")
    check(KeyNavigation.move(from: nil, direction: .up, available: []) == nil, "空界面方向键安全")
    let many = (0..<50).map { candidate("App \($0)", group: "group\($0)") }
    let mapping = KeyAssigner.assign(many)
    check(mapping.count == 38 && Set(mapping.keys) == Set(Key.all), "超过容量时恰好38个可见可达入口")
}

// MARK: - Key 相等性

@MainActor
func testKeyEquality() {
    print("Key 相等性（以 label 为标识）")
    check(Key("C", letter: true) == Key("C", letter: true, x: 2, y: 2), "同 label 不同坐标相等")
    check(Key("C", letter: true) != Key("V", letter: true, x: 3, y: 2), "不同 label 不等")
    check(Set([Key("C", letter: true, x: 2, y: 2)]).contains(Key("C", letter: true)), "Set 按 label 命中")
}

// MARK: - 用户快捷键配置

@MainActor
func testShortcutPreferences() {
    print("快捷键校验与独立配置持久化")
    expectEqual(AppShortcut.default.displayName, "⌃⌥Space", "升级后保留默认组合键")
    check(AppShortcut.default.validationMessage == nil, "默认组合合法")
    check(ShortcutPreferences.default.sequenceEnabled, "升级后默认保留F→J")
    check(AppShortcut(keyCode: 0, modifiers: []).validationMessage != nil, "拒绝裸字母，避免影响正常输入")
    check(AppShortcut(keyCode: 0, modifiers: .shift).validationMessage != nil, "拒绝只有Shift的普通字母")
    check(AppShortcut(keyCode: 0, modifiers: [.control, .shift]).validationMessage == nil, "允许Control加Shift组合")
    check(AppShortcut(keyCode: 53, modifiers: .command).validationMessage != nil, "Esc保留用于退出录制")
    check(AppShortcut(keyCode: 55, modifiers: .command).validationMessage != nil, "修饰键本身不能作为触发键")
    check(AppShortcut(keyCode: .max, modifiers: .command).validationMessage != nil, "拒绝未知物理键码")
    check(AppShortcut(keyCode: 0, modifiers: ShortcutModifiers(rawValue: 128)).validationMessage != nil, "拒绝配置中未知修饰位")
    let custom = ShortcutPreferences(hotKey: AppShortcut(keyCode: 8, modifiers: [.control, .option, .shift]), sequenceEnabled: false)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AppSwitcher-shortcut-tests-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ShortcutStore(fileURL: directory.appendingPathComponent("shortcuts.json"))
    do {
        let missing = try store.load()
        check(missing == nil, "旧版本没有配置文件时使用默认值")
        try store.save(custom)
        let restartedStore = ShortcutStore(fileURL: directory.appendingPathComponent("shortcuts.json"))
        let persisted = try restartedStore.load()
        expectEqual(persisted, custom, "重建存储后保留自定义组合及F→J关闭状态")
        let invalid = ShortcutPreferences(hotKey: AppShortcut(keyCode: 0, modifiers: []), sequenceEnabled: true)
        do {
            try store.save(invalid)
            check(false, "非法配置不得覆盖已保存值")
        } catch {
            check(true, "非法配置不得覆盖已保存值")
        }
        let afterFailure = try store.load()
        expectEqual(afterFailure, custom, "非法保存后原配置仍完整")
        try Data("{invalid-json".utf8).write(to: directory.appendingPathComponent("shortcuts.json"))
        do {
            _ = try store.load()
            check(false, "损坏配置必须报告失败，不伪装为空配置")
        } catch {
            check(true, "损坏配置必须报告失败，不伪装为空配置")
        }
    } catch {
        check(false, "快捷键持久化测试意外失败：\(error.localizedDescription)")
    }
}

// MARK: - 运行

testKeyAssigner()
testAppRanker()
testWindowFilter()
testCandidateFactory()
testKeyEquality()
testKeyboardNavigation()
testShortcutPreferences()

print("")
if failCount == 0 {
    print("✅ 全部通过：\(passCount) 项")
} else {
    print("❌ \(failCount) 项失败，\(passCount) 项通过")
}
exit(failCount == 0 ? 0 : 1)
