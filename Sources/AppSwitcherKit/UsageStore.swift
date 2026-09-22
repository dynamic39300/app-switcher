import Foundation
import AppSwitcherCore

/// 使用统计持久化（JSON 文件，原子写入）。
public struct UsageStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> [String: UsageStats] {
        guard let data = try? Data(contentsOf: fileURL),
              let stats = try? JSONDecoder().decode([String: UsageStats].self, from: data) else {
            return [:]
        }
        return stats
    }

    public func save(_ stats: [String: UsageStats]) throws {
        let data = try JSONEncoder().encode(stats)
        try data.write(to: fileURL, options: .atomic)
    }
}
