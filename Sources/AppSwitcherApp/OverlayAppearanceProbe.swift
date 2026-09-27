import Foundation

enum OverlayAppearanceProbe {
    private struct Failure: Error { let message: String }

    static func run() -> Int {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AppSwitcher-appearance-probe-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("appearance.json")
            let store = OverlayAppearanceStore(url: url)
            try require(store.style == .graphite && store.notice == nil, "missing preference uses graphite")
            try require(!FileManager.default.fileExists(atPath: url.path), "reading a missing preference does not write")
            for style in OverlayStyle.allCases {
                try require(store.select(style) && store.style == style && store.notice == nil, "save \(style.rawValue)")
                let reopened = OverlayAppearanceStore(url: url)
                try require(reopened.style == style && reopened.notice == nil, "reload \(style.rawValue)")
            }
            for source in ["invalid", "{\"version\":2,\"style\":\"smoke\"}", "{\"version\":1,\"style\":\"future\"}"] {
                let bytes = Data(source.utf8)
                try bytes.write(to: url)
                let damaged = OverlayAppearanceStore(url: url)
                try require(damaged.style == .graphite && damaged.notice != nil, "invalid preference has a visible fallback")
                let remaining = try Data(contentsOf: url)
                try require(remaining == bytes, "invalid preference remains untouched until explicit selection")
                try require(damaged.select(.porcelain) && damaged.notice == nil, "explicit selection repairs the preference")
            }
            // A file used as the parent is a deterministic write failure, even when running as root.
            let blocker = directory.appendingPathComponent("not-a-directory")
            try Data().write(to: blocker)
            let blocked = OverlayAppearanceStore(url: blocker.appendingPathComponent("appearance.json"))
            try require(!blocked.select(.smoke) && blocked.style == .graphite && blocked.notice != nil, "write failure retains previous theme and explains failure")
            for style in OverlayStyle.allCases {
                try require(style.detailPlacement(in: CGSize(width: 760, height: 300), hasNumberRow: true) == .none, "short crowded \(style.rawValue) gives all space to keys")
            }
            try require(OverlayStyle.graphite.detailPlacement(in: CGSize(width: 1900, height: 900), hasNumberRow: true) == .none, "graphite preserves full keyboard")
            try require(OverlayStyle.porcelain.detailPlacement(in: CGSize(width: 1300, height: 700), hasNumberRow: true) == .top, "porcelain uses top detail")
            try require(OverlayStyle.smoke.detailPlacement(in: CGSize(width: 1300, height: 700), hasNumberRow: true) == .side, "smoke uses side detail on wide screens")
            try require(OverlayStyle.smoke.detailPlacement(in: CGSize(width: 1100, height: 500), hasNumberRow: true) == .none, "38-key medium width does not squeeze keys for sidebar")
            let keyboard = CGRect(x: 20, y: 106, width: 1290, height: 580)
            var viewport = KeyViewportPreference.defaultValue
            KeyViewportPreference.reduce(value: &viewport) { keyboard }
            try require(viewport == keyboard, "drag viewport receives keyboard bounds")
            KeyViewportPreference.reduce(value: &viewport) { .zero }
            try require(viewport == keyboard, "empty sibling cannot erase drag viewport or guide bounds")
            return 0
        } catch {
            print("FAIL appearance: \((error as? Failure)?.message ?? error.localizedDescription)")
            return 1
        }
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message: message) }
        print("PASS appearance: \(message)")
    }
}
