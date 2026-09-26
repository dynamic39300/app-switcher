import AppKit
import Carbon.HIToolbox
import AppSwitcherCore
import Darwin

/// 只注册四修饰 F17–F19，不生成键盘事件、不唤起用户应用，结束释放全部注册。
@MainActor
enum ShortcutRegistrationProbe {
    private enum ProbeError: Error { case assertion(String), persistence }
    private static let first = AppShortcut(keyCode: 64, modifiers: .all)
    private static let blocked = AppShortcut(keyCode: 79, modifiers: .all)
    private static let replacement = AppShortcut(keyCode: 80, modifiers: .all)

    static func run() -> Int {
        if let index = CommandLine.arguments.firstIndex(of: "--hold-shortcut"),
           CommandLine.arguments.count > index + 2,
           let code = UInt16(CommandLine.arguments[index + 1]),
           let options = UInt32(CommandLine.arguments[index + 2]) {
            return hold(code: code, options: options)
        }
        let manager = GlobalHotKey.shared
        guard manager.currentShortcut == nil else {
            print("SKIP shortcuts: 请使用独立验证入口，不覆盖现有注册。")
            return 2
        }
        var child: Holder?
        defer { child?.stop(); manager.stop() }
        do {
            try manager.replace(with: first)
            try require(isOccupied(first), "初始组合已真实注册")
            child = try Holder(shortcut: blocked, options: UInt32(kEventHotKeyExclusive))
            try expectFailure { try manager.replace(with: blocked) }
            try require(manager.currentShortcut == first && isOccupied(first), "跨进程排他冲突失败仍保留旧键")

            try expectFailure { try manager.replace(with: replacement) { throw ProbeError.persistence } }
            try require(manager.currentShortcut == first && isOccupied(first) && isAvailable(replacement), "持久化失败释放新键并保留旧键")
            var persistedSame = false
            try manager.replace(with: first) { persistedSame = true }
            try require(persistedSame && isOccupied(first), "同一组合也提交持久化事务")

            try manager.replace(with: replacement)
            try require(manager.currentShortcut == replacement && isAvailable(first) && isOccupied(replacement), "成功替换后旧键释放新键生效")
            try manager.suspend()
            try require(manager.isSuspended && isAvailable(replacement), "录制暂停时释放当前组合")
            var blocker: EventHotKeyRef?
            let blockedResult = registerRaw(replacement, reference: &blocker)
            guard blockedResult == noErr, blocker != nil else { throw ProbeError.assertion("无法构造恢复冲突") }
            defer { if let blocker { _ = UnregisterEventHotKey(blocker) } }
            try expectFailure { try manager.resume() }
            try require(manager.isSuspended && manager.currentShortcut == replacement, "恢复冲突明确失败且保留待恢复配置")
            if let blocker { _ = UnregisterEventHotKey(blocker) }
            blocker = nil
            try manager.resume()
            try require(!manager.isSuspended && isOccupied(replacement), "冲突释放后可恢复原组合")
            manager.stop()
            try require(manager.currentShortcut == nil && isAvailable(replacement), "停止后注册已释放")

            child?.stop()
            child = try Holder(shortcut: blocked, options: 0)
            do {
                try manager.replace(with: blocked)
                print("NOTE shortcuts: 系统允许覆盖另一进程的非排他注册，这类冲突无法保证检出。")
            } catch {
                print("NOTE shortcuts: 本机拒绝了与另一进程非排他注册的冲突；这不是所有系统的保证。")
            }
            manager.stop()
            child?.stop()
            child = nil
            try manager.replace(with: blocked)
            manager.stop()
            try require(isAvailable(blocked), "子进程注销后组合可重新注册并释放")
            print("PASS shortcuts: Carbon 排他冲突、事务回滚和释放验证通过；非排他冲突边界见 NOTE。")
            return 0
        } catch ProbeError.assertion(let message) {
            print("FAIL shortcuts: \(message)")
            return 1
        } catch {
            print("FAIL shortcuts: \(error.localizedDescription)")
            return 1
        }
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ProbeError.assertion(message) }
        print("PASS shortcuts: \(message)")
    }

    private static func expectFailure(_ operation: () throws -> Void) throws {
        do { try operation() }
        catch { return }
        throw ProbeError.assertion("预期的冲突或持久化失败未被拒绝")
    }

    private static func registerRaw(_ shortcut: AppShortcut, reference: inout EventHotKeyRef?) -> OSStatus {
        RegisterEventHotKey(UInt32(shortcut.keyCode), shortcut.carbonModifiers,
                            EventHotKeyID(signature: OSType(0x50524F42), id: UInt32(shortcut.keyCode)),
                            GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
    }

    private static func isOccupied(_ shortcut: AppShortcut) -> Bool {
        var reference: EventHotKeyRef?
        let result = registerRaw(shortcut, reference: &reference)
        if let reference { _ = UnregisterEventHotKey(reference) }
        return result == eventHotKeyExistsErr
    }

    private static func isAvailable(_ shortcut: AppShortcut) -> Bool {
        var reference: EventHotKeyRef?
        let result = registerRaw(shortcut, reference: &reference)
        if let reference { _ = UnregisterEventHotKey(reference) }
        return result == noErr
    }

    private static func hold(code: UInt16, options: UInt32) -> Int {
        guard [first.keyCode, blocked.keyCode, replacement.keyCode].contains(code),
              options == 0 || options == UInt32(kEventHotKeyExclusive) else { return 2 }
        var reference: EventHotKeyRef?
        let result = RegisterEventHotKey(UInt32(code), AppShortcut(keyCode: code, modifiers: .all).carbonModifiers,
                                        EventHotKeyID(signature: OSType(0x484F4C44), id: 1),
                                        GetApplicationEventTarget(), OptionBits(options), &reference)
        print("READY \(result)")
        fflush(stdout)
        guard result == noErr, let reference else { return 2 }
        defer { _ = UnregisterEventHotKey(reference) }
        _ = FileHandle.standardInput.readDataToEndOfFile()
        return 0
    }

    private final class Holder {
        private let process = Process()
        private let input = Pipe()
        private let output = Pipe()

        init(shortcut: AppShortcut, options: UInt32) throws {
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            process.arguments = ["--verify-shortcuts", "--hold-shortcut", String(shortcut.keyCode), String(options)]
            process.standardInput = input
            process.standardOutput = output
            try process.run()
            try input.fileHandleForReading.close()
            try output.fileHandleForWriting.close()
            var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN | POLLHUP), revents: 0)
            guard poll(&descriptor, 1, 3_000) > 0 else { stop(); throw ProbeError.assertion("冲突子进程启动超时") }
            var buffer = [UInt8](repeating: 0, count: 128)
            let count = Darwin.read(output.fileHandleForReading.fileDescriptor, &buffer, buffer.count)
            guard count > 0, String(bytes: buffer.prefix(count), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "READY 0" else {
                stop()
                throw ProbeError.assertion("合成验证组合已被占用，未改动现有注册")
            }
        }

        func stop() {
            try? input.fileHandleForWriting.close()
            let deadline = Date().addingTimeInterval(1)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
            if process.isRunning { process.terminate() }
            try? output.fileHandleForReading.close()
        }
    }
}
