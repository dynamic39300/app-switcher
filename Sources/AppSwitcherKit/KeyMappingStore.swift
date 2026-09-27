import Foundation
import AppSwitcherCore

/// Owns only app-to-key preferences and the optional guide; never persists process or window identity.
public final class KeyMappingStore {
    public let fileURL: URL
    public private(set) var preferences = KeyMappingPreferences()
    public private(set) var notice: String?
    private var loadFailed = false

    public init(fileURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("AppSwitcher/key-mapping.json")) {
        self.fileURL = fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            guard data.count <= 65_536 else { throw CocoaError(.fileReadCorruptFile) }
            let decoded = try JSONDecoder().decode(KeyMappingPreferences.self, from: data)
            guard decoded.isValid else { throw CocoaError(.fileReadCorruptFile) }
            preferences = decoded
        } catch {
            loadFailed = true
            notice = "键位配置无法读取，暂用自动分配；可在拖拽菜单中恢复默认键位。"
        }
    }

    @discardableResult
    public func save(_ next: KeyMappingPreferences) -> Bool {
        guard next.isValid else {
            notice = "键位设置无效，已保留原设置。"
            return false
        }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if loadFailed, FileManager.default.fileExists(atPath: fileURL.path) {
                let backup = directory.appendingPathComponent("key-mapping-unreadable-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: fileURL, to: backup)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(next).write(to: fileURL, options: .atomic)
            preferences = next
            loadFailed = false
            notice = nil
            return true
        } catch {
            notice = "键位设置未能保存，已保留原设置；请检查磁盘空间或目录权限后重试。"
            return false
        }
    }
}
