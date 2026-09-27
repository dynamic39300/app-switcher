import Foundation
import AppSwitcherCore
import AppSwitcherKit

@MainActor
func testKeyRemapping() {
    print("Application key remapping and guide preferences")
    let q = Key.letters.first { $0.label == "Q" }!
    let w = Key.letters.first { $0.label == "W" }!
    let e = Key.letters.first { $0.label == "E" }!
    let a = candidate("Quartz", group: "test.quartz", id: "process-1")
    let b = candidate("Web", group: "test.web", id: "process-2")
    let c = candidate("Editor", group: "test.editor", id: "process-3")
    let apps = [a, b, c]
    let original = [q: a, w: b, e: c]
    let defaults = KeyMappingPreferences()
    let number = Key.numberRow[0]
    let moved = KeyRemapping.moving(from: q, to: number, in: original, candidates: apps, preferences: defaults)!
    check(moved.map[q] == nil && moved.map[number] == a, "drop on empty number key moves exactly one app")
    check(moved.map[w] == b && moved.map[e] == c, "unrelated current keys remain unchanged")
    expectEqual(moved.preferences.bindings, [a.groupID: "1"], "persistence contains app identity and key, not PID")
    let swapped = KeyRemapping.moving(from: q, to: w, in: original, candidates: apps, preferences: defaults)!
    check(swapped.map[w] == a && swapped.map[q] == b && swapped.map[e] == c, "occupied destination swaps both apps")
    expectEqual(swapped.preferences.bindings, [a.groupID: "W", b.groupID: "Q"], "both ends of a swap persist")
    expectEqual(KeyAssigner.assign(apps, preferredKeys: swapped.preferences.preferredKeys), swapped.map, "next presentation preserves swapped keys")
    check(KeyRemapping.moving(from: q, to: q, in: original, candidates: apps, preferences: defaults) == nil, "same-key drop is a no-op")
    check(KeyRemapping.moving(from: q, to: Key("?", letter: false), in: original, candidates: apps, preferences: defaults) == nil, "invalid target key is rejected")
    check(KeyRemapping.moving(from: number, to: q, in: original, candidates: apps, preferences: defaults) == nil, "missing source is rejected")
    check(KeyRemapping.moving(from: q, to: w, in: original, candidates: [b, c], preferences: defaults) == nil, "stale source identity cannot move")
    let duplicate = candidate("Quartz", group: a.groupID, id: "process-4")
    check(KeyRemapping.moving(from: q, to: w, in: original, candidates: apps + [duplicate], preferences: defaults) == nil, "ambiguous source app cannot pin a random instance")
    check(KeyRemapping.moving(from: w, to: q, in: original, candidates: apps + [duplicate], preferences: defaults) == nil, "ambiguous destination app cannot be pinned by a swap")
    let window = Candidate(id: "window", groupID: "test.window", displayName: "Window", title: "private title", target: .window(pid: 1, token: "transient"))
    check(KeyRemapping.moving(from: q, to: w, in: [q: window, w: b], candidates: [window, b], preferences: defaults) == nil, "window identity is never persisted")
    let restoredApp = candidate("Renamed", group: a.groupID, id: "new-process")
    expectEqual(KeyAssigner.assign([restoredApp, b], preferredKeys: moved.preferences.preferredKeys)[number], restoredApp, "restart and display name changes preserve app key")
    check(KeyAssigner.assign([a, duplicate], preferredKeys: moved.preferences.preferredKeys)[number] == nil, "ambiguous app ignores saved pin during assignment")
    let absent = KeyMappingPreferences(bindings: ["test.closed": "W"])
    let reclaimed = KeyRemapping.moving(from: q, to: w, in: [q: a], candidates: [a], preferences: absent)!
    check(reclaimed.preferences.bindings["test.closed"] == nil && reclaimed.map[w] == a, "explicit move replaces an absent app reservation")
    expectEqual(KeyAssigner.assign([b], preferredKeys: ["test.closed": w])[w], b, "closed app does not block automatic allocation")
    let crowded = (0..<42).map { candidate("App \($0)", group: "test.\($0)") }
    let assigned = KeyAssigner.assign(crowded, preferredKeys: [crowded[41].groupID: number])
    check(assigned.count == 38 && Set(assigned.values.map(\.id)).count == 38, "capacity remains 38 unique targets")
    expectEqual(assigned[number], crowded[41], "saved app remains visible beyond the automatic rank cutoff")
    expectEqual(KeyAssigner.assign(apps, preferredKeys: [:]), KeyAssigner.assign(apps), "empty preferences retain default assignment")
    check(!KeyMappingPreferences(bindings: ["a": "Q", "b": "Q"]).isValid, "duplicate persisted keys are rejected")
    check(!KeyMappingPreferences(bindings: ["a": "?"]).isValid, "unknown persisted key is rejected")
    var future = defaults
    future.version = 2
    check(!future.isValid, "unknown schema version is rejected")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AppSwitcher-key-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("key-mapping.json")
    let store = KeyMappingStore(fileURL: url)
    check(store.preferences == defaults && store.notice == nil, "missing file defaults to automatic keys and enabled guide")
    check(store.save(swapped.preferences), "valid swap saves atomically")
    expectEqual(KeyMappingStore(fileURL: url).preferences, swapped.preferences, "reloaded store retains swap")
    var hidden = swapped.preferences
    hidden.showsDragGuide = false
    check(store.save(hidden), "guide dismissal saves independently of bindings")
    expectEqual(KeyMappingStore(fileURL: url).preferences, hidden, "restart keeps guide disabled and bindings intact")
    check(!store.save(KeyMappingPreferences(bindings: ["a": "invalid"])), "invalid save is refused")
    expectEqual(KeyMappingStore(fileURL: url).preferences, hidden, "invalid save preserves existing file")
    do {
        let corrupt = Data("{broken".utf8)
        try corrupt.write(to: url)
        let damaged = KeyMappingStore(fileURL: url)
        check(damaged.notice != nil && damaged.preferences == defaults, "corrupt file falls back with visible notice")
        let preserved = try Data(contentsOf: url)
        check(preserved == corrupt, "load preserves corrupt source for recovery")
        check(damaged.save(hidden), "explicit repair can save valid preferences")
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("key-mapping-unreadable-") }
        check(backups.count == 1, "repair preserves an unreadable-file backup")
        let backupData = try Data(contentsOf: backups[0])
        check(backupData == corrupt, "backup retains exact original bytes")
        let blocker = directory.appendingPathComponent("blocked")
        try Data().write(to: blocker)
        let failing = KeyMappingStore(fileURL: blocker.appendingPathComponent("key-mapping.json"))
        check(!failing.save(hidden) && failing.preferences == defaults && failing.notice != nil, "write failure preserves old in-memory preferences and reports error")
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        check(!text.contains("process-") && !text.contains("private title") && !text.contains("transient"), "persisted format contains no process or window content")
    } catch {
        check(false, "key preference integration failed: \(error.localizedDescription)")
    }
}
