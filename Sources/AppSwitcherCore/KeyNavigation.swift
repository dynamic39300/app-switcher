/// Physical ANSI key positions keep shortcuts usable with Chinese input methods.
public enum KeyInput {
    public static func key(for hardwareCode: UInt16) -> Key? {
        let labels: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y",
            17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "+",
            25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 31: "O", 32: "U", 34: "I",
            35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        ]
        guard let label = labels[hardwareCode] else { return nil }
        return Key.all.first { $0.label == label }
    }
}

public enum KeyNavigation {
    public enum Direction { case left, right, up, down }

    public static func ordered(_ available: Set<Key>) -> [Key] {
        (Key.numberRow + Key.letters).filter { available.contains($0) }
    }

    public static func move(from current: Key?, direction: Direction, available: Set<Key>) -> Key? {
        let keys = ordered(available)
        guard !keys.isEmpty else { return nil }
        guard let current, let index = keys.firstIndex(of: current) else { return keys.first }
        if direction == .left { return keys[(index + keys.count - 1) % keys.count] }
        if direction == .right { return keys[(index + 1) % keys.count] }
        let origin = position(current)
        let rows = Set(keys.map { position($0).y }).sorted()
        guard let row = rows.firstIndex(of: origin.y) else { return keys.first }
        let nextRow = rows[(row + (direction == .up ? rows.count - 1 : 1)) % rows.count]
        return keys.filter { position($0).y == nextRow }.min {
            let a = abs(position($0).x - origin.x), b = abs(position($1).x - origin.x)
            return a == b ? position($0).x < position($1).x : a < b
        }
    }

    private static func position(_ key: Key) -> (x: Double, y: Int) {
        if let index = Key.numberRow.firstIndex(of: key) { return (Double(index) - 1, -1) }
        let canonical = Key.letters.first { $0 == key }
        let row = canonical?.y ?? 0
        return (Double(canonical?.x ?? 0) + [0.0, 0.5, 1.5][row], row)
    }
}
