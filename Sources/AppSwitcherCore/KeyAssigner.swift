/// 键位分配（纯函数、确定性）。
///
/// 规则（对应 SPEC-001 AC-03/AC-04）：
/// 1. 输入按 rank 排序且同组相邻（由 `AppRanker.rank` 保证）。
/// 2. 组首条目：优先显示名首字母（a-z）；被占用时就近让位到最近空闲字母键
///    （QWERTY 距离，距离相同 home 行优先、再靠左）；无首字母（非 a-z）时直接落数字行。
/// 3. 同组后续条目：平铺到上一键右侧最近空闲键（相邻）。
/// 4. 字母区用尽后落数字行 `1-0 - +`；候选超过键位数时截断。
public enum KeyAssigner {
    public static func assign(_ candidates: [Candidate]) -> [Key: Candidate] {
        let limited = Array(candidates.prefix(Key.all.count))
        var used = Set<Key>()
        var result: [Key: Candidate] = [:]
        var prevKeyByGroup: [String: Key] = [:]

        for candidate in limited {
            let first = firstLetter(of: candidate.displayName)
            let key: Key?

            if let prev = prevKeyByGroup[candidate.groupID] {
                // 同组后续窗口：上一键右侧最近空闲键
                key = nextFreeKey(toTheRightOf: prev, used: used) ?? firstFreeKey(used)
            } else if let first, let ideal = letterKey(for: first), !used.contains(ideal) {
                // 组首：首字母空闲
                key = ideal
            } else if let first {
                // 组首：首字母被占，就近让位
                key = nearestFreeLetter(near: first, used: used) ?? firstFreeKey(used)
            } else {
                // 组首：非字母名，直接数字行
                key = firstFreeNumberRow(used) ?? firstFreeKey(used)
            }

            if let k = key {
                used.insert(k)
                prevKeyByGroup[candidate.groupID] = k
                result[k] = candidate
            }
        }
        return result
    }

    // MARK: - Helpers

    private static func firstLetter(of name: String) -> Character? {
        guard let c = name.first else { return nil }
        let lower = Character(String(c).lowercased())
        guard lower.isASCII, lower.isLetter else { return nil }
        return lower
    }

    private static func letterKey(for c: Character) -> Key? {
        let upper = String(c).uppercased()
        return Key.letters.first { $0.label == upper }
    }

    private static func firstFreeKey(_ used: Set<Key>) -> Key? {
        Key.all.first { !used.contains($0) }
    }

    private static func nextFreeKey(toTheRightOf prev: Key, used: Set<Key>) -> Key? {
        guard let idx = Key.all.firstIndex(of: prev) else { return nil }
        return Key.all.dropFirst(idx + 1).first { !used.contains($0) }
    }

    private static func firstFreeNumberRow(_ used: Set<Key>) -> Key? {
        Key.numberRow.first { !used.contains($0) }
    }

    private static func nearestFreeLetter(near c: Character, used: Set<Key>) -> Key? {
        guard let ideal = letterKey(for: c), let ix = ideal.x, let iy = ideal.y else { return nil }
        let free = Key.letters.filter { !used.contains($0) }
        guard !free.isEmpty else { return nil }
        return free.min { a, b in
            let da = distance(a, ix, iy)
            let db = distance(b, ix, iy)
            if da != db { return da < db }
            if (a.y == 1) != (b.y == 1) { return a.y == 1 }
            if a.x != b.x { return a.x! < b.x! }
            return a.label < b.label
        }
    }

    private static func distance(_ k: Key, _ x: Int, _ y: Int) -> Double {
        let dx = Double(k.x! - x)
        let dy = Double(k.y! - y)
        return (dx * dx + dy * dy).squareRoot()
    }
}
