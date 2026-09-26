import Foundation
import AppSwitcherCore

public struct ShortcutStore: Sendable {
    public let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> ShortcutPreferences? {
        let data: Data
        do { data = try Data(contentsOf: fileURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
        guard data.count <= 16_384 else { throw ShortcutStoreError.invalid("快捷键配置文件过大，请重新设置。") }
        let preferences: ShortcutPreferences
        do { preferences = try JSONDecoder().decode(ShortcutPreferences.self, from: data) }
        catch { throw ShortcutStoreError.invalid("快捷键配置损坏，请重新设置后保存。") }
        if let message = preferences.hotKey.validationMessage { throw ShortcutStoreError.invalid(message) }
        return preferences
    }

    public func save(_ preferences: ShortcutPreferences) throws {
        if let message = preferences.hotKey.validationMessage { throw ShortcutStoreError.invalid(message) }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(preferences).write(to: fileURL, options: .atomic)
    }
}

public enum ShortcutStoreError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}
