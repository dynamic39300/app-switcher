import AppKit
import AppSwitcherCore
import AppSwitcherKit

/// Interactive fixture with local preferences and synthetic targets. Never activates a real app.
@MainActor
final class KeyRemappingPreview {
    private let store: KeyMappingStore
    private let panel: OverlayPanel
    private var mode: OverlayMode = .applications
    private let candidates = [
        Candidate(id: "fixture.safari", groupID: "fixture.safari", displayName: "Safari"),
        Candidate(id: "fixture.mail", groupID: "fixture.mail", displayName: "Mail"),
        Candidate(id: "fixture.notes", groupID: "fixture.notes", displayName: "Notes"),
        Candidate(id: "fixture.terminal", groupID: "fixture.terminal", displayName: "Terminal"),
        Candidate(id: "fixture.finder", groupID: "fixture.finder", displayName: "Finder")
    ]

    init(directory: URL) {
        store = KeyMappingStore(fileURL: directory.appendingPathComponent("key-mapping.json"))
        let paths = ["fixture.safari": "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
                     "fixture.mail": "/System/Applications/Mail.app", "fixture.notes": "/System/Applications/Notes.app",
                     "fixture.terminal": "/System/Applications/Utilities/Terminal.app",
                     "fixture.finder": "/System/Library/CoreServices/Finder.app"]
        panel = OverlayPanel(appearance: OverlayAppearanceStore(url: directory.appendingPathComponent("appearance.json")),
                             mappingStore: store, iconOverrides: paths.mapValues { NSWorkspace.shared.icon(forFile: $0) })
        panel.onRemap = { [weak self] source, destination, id in
            guard let self, mode == .applications, panel.keyMap[source]?.id == id,
                  let change = KeyRemapping.moving(from: source, to: destination, in: panel.keyMap,
                                                   candidates: candidates, preferences: store.preferences) else { return false }
            guard store.save(change.preferences) else { panel.update(keyMap: panel.keyMap, mode: mode); return false }
            panel.update(keyMap: change.map, mode: mode, message: "已保存 \(source.label) → \(destination.label)", isSuccess: true)
            print("REMAP \(source.label) -> \(destination.label)")
            return true
        }
        panel.onResetBindings = { [weak self] group in
            guard let self else { return }
            var next = store.preferences
            if let group { next.bindings.removeValue(forKey: group) } else { next.bindings = [:] }
            guard store.save(next) else { return }
            panel.update(keyMap: mapping(), mode: mode)
            print("RESET")
        }
        panel.onKey = { [weak self] key in
            guard let id = self?.panel.keyMap[key]?.id else { return }
            print("ACTIVATE \(key.label) -> \(id)")
        }
        panel.onCancel = { explicit in
            // Automation may dismiss transient panels while observing. End this fixture via its process.
            if explicit { print("CANCEL requested; fixture retained") }
        }
        panel.onToggleMode = { [weak self] in
            guard let self else { return }
            mode = mode == .applications ? .windows : .applications
            panel.update(keyMap: mapping(), mode: mode)
        }
    }

    func show() {
        panel.show(keyMap: mapping())
        print("READY synthetic key remapping; guide=\(store.preferences.showsDragGuide)")
    }

    private func mapping() -> [Key: Candidate] {
        KeyAssigner.assign(AppRanker.rank(candidates), preferredKeys: mode == .applications ? store.preferences.preferredKeys : [:])
    }
}
