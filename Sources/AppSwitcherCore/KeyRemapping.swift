import Foundation

public struct KeyMappingPreferences: Codable, Equatable, Sendable {
    public var version = 1
    public var bindings: [String: String]
    public var showsDragGuide: Bool

    public init(bindings: [String: String] = [:], showsDragGuide: Bool = true) {
        self.bindings = bindings
        self.showsDragGuide = showsDragGuide
    }

    public var isValid: Bool {
        version == 1 && bindings.count <= Key.all.count
            && Set(bindings.values).count == bindings.count
            && bindings.allSatisfy { !$0.key.isEmpty && $0.key.utf8.count <= 512
                && Key.all.contains(Key($0.value, letter: false)) }
    }

    public var preferredKeys: [String: Key] {
        bindings.compactMapValues { label in Key.all.first { $0.label == label } }
    }
}

public enum KeyRemapping {
    public struct Change: Equatable, Sendable {
        public let map: [Key: Candidate]
        public let preferences: KeyMappingPreferences
    }

    /// Move or swap only the displayed snapshot; do not re-rank unrelated apps during a drag.
    public static func moving(from source: Key, to destination: Key, in map: [Key: Candidate],
                              candidates: [Candidate], preferences: KeyMappingPreferences) -> Change? {
        guard preferences.isValid, source != destination, Key.all.contains(destination),
              let moved = map[source], !moved.isWindow else { return nil }
        let displaced = map[destination]
        let affected = [moved, displaced].compactMap { $0 }
        guard affected.allSatisfy({ candidate in
            !candidate.isWindow && candidates.filter { $0.groupID == candidate.groupID }.count == 1
                && candidates.contains(candidate)
        }) else { return nil }
        var next = preferences
        // Explicit reassignment supersedes a saved binding even when its app is not running.
        next.bindings = next.bindings.filter { $0.value != destination.label && $0.key != moved.groupID }
        next.bindings[moved.groupID] = destination.label
        var result = map
        result[source] = displaced
        result[destination] = moved
        if let displaced {
            next.bindings = next.bindings.filter { $0.value != source.label && $0.key != displaced.groupID }
            next.bindings[displaced.groupID] = source.label
        }
        guard next.isValid else { return nil }
        return Change(map: result, preferences: next)
    }
}
