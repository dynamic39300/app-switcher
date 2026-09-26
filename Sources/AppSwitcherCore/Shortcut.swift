import Foundation

/// 独立于 Carbon/NSEvent 的持久化修饰键；不保存逐键输入。
public struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let shift = Self(rawValue: 1 << 2)
    public static let command = Self(rawValue: 1 << 3)
    public static let all: Self = [.control, .option, .shift, .command]
}

public struct AppShortcut: Codable, Hashable, Sendable {
    public let keyCode: UInt16
    public let modifiers: ShortcutModifiers

    public init(keyCode: UInt16, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let `default` = Self(keyCode: 49, modifiers: [.control, .option])

    /// 使用物理键位置的 ANSI 标签，不随当前输入法把同一配置解释成不同组合。
    public var displayName: String {
        var value = ""
        if modifiers.contains(.control) { value += "⌃" }
        if modifiers.contains(.option) { value += "⌥" }
        if modifiers.contains(.shift) { value += "⇧" }
        if modifiers.contains(.command) { value += "⌘" }
        return value + (Self.keyLabels[keyCode] ?? "未知键")
    }

    public var validationMessage: String? {
        guard modifiers.subtracting(.all).isEmpty else { return "快捷键包含不支持的修饰键，请重新录制。" }
        guard !modifiers.intersection([.command, .control, .option]).isEmpty else {
            return "请至少按住 ⌘、⌃ 或 ⌥ 中的一个键，再按另一个键。"
        }
        guard Self.keyLabels[keyCode] != nil else { return "不支持这个按键；Esc、Fn 和单独的修饰键不能用作唤出键。" }
        let commandOnly: Set<UInt16> = [4, 12, 13, 46, 48, 49, 50]
        if (modifiers == .command && commandOnly.contains(keyCode))
            || (modifiers == [.command, .shift] && [48, 50].contains(keyCode))
            || (modifiers == [.command, .control] && keyCode == 12)
            || (modifiers == [.command, .option] && keyCode == 49) {
            return "这个组合保留给系统或常用应用操作，请换一个组合。"
        }
        return nil
    }

    private static let keyLabels: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "−", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete",
        64: "F17", 65: "小键盘 .", 67: "小键盘 ×", 69: "小键盘 +", 71: "Clear", 75: "小键盘 ÷",
        76: "小键盘 Enter", 78: "小键盘 −", 79: "F18", 80: "F19", 81: "小键盘 =",
        82: "小键盘 0", 83: "小键盘 1", 84: "小键盘 2", 85: "小键盘 3", 86: "小键盘 4",
        87: "小键盘 5", 88: "小键盘 6", 89: "小键盘 7", 90: "F20", 91: "小键盘 8", 92: "小键盘 9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        114: "Help", 115: "Home", 116: "Page Up", 117: "Forward Delete", 118: "F4",
        119: "End", 120: "F2", 121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}

public struct ShortcutPreferences: Codable, Equatable, Sendable {
    public var hotKey: AppShortcut
    public var sequenceEnabled: Bool

    public init(hotKey: AppShortcut = .default, sequenceEnabled: Bool = true) {
        self.hotKey = hotKey
        self.sequenceEnabled = sequenceEnabled
    }

    public static let `default` = Self()
}
