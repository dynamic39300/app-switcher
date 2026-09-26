/// 覆盖层键盘上的一个键位。V1 共 38 键：26 个字母 + 数字行 `1-0 - +`。
/// 字母键带 QWERTY 坐标（y=0 顶行、y=1 home 行、y=2 底行），数字行无坐标，仅作溢出区。
public struct Key: Hashable, Sendable {
    public let label: String
    public let isLetter: Bool
    public let x: Int?
    public let y: Int?

    public init(_ label: String, letter: Bool, x: Int? = nil, y: Int? = nil) {
        self.label = label
        self.isLetter = letter
        self.x = x
        self.y = y
    }

    // 以 label 为唯一标识：label 唯一决定键位，x/y 是派生坐标，不参与相等性/哈希。
    public static func == (lhs: Key, rhs: Key) -> Bool {
        lhs.label == rhs.label
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(label)
    }
}

public extension Key {
    /// 三排字母键，按 QWERTY 顺序（顶行→home→底行），x 自左向右递增。
    static let letters: [Key] = {
        let rows: [(y: Int, chars: String)] = [
            (0, "QWERTYUIOP"),
            (1, "ASDFGHJKL"),
            (2, "ZXCVBNM"),
        ]
        var result: [Key] = []
        for (y, chars) in rows {
            for (x, c) in chars.enumerated() {
                result.append(Key(String(c), letter: true, x: x, y: y))
            }
        }
        return result
    }()

    /// 数字行（`1-0 - +`），按从左到右顺序，仅作溢出区。
    static let numberRow: [Key] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "+"]
        .map { Key($0, letter: false) }

    /// 全部键位，字母在前、数字行在后（分配优先级顺序）。
    static let all: [Key] = letters + numberRow
}
