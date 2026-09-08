import Foundation

/// Two atomic snapshots, each tagged with a generation. An interrupted write or one
/// corrupt copy recovers the newest complete generation, including an empty/cleared value.
struct SnapshotStore<Value: Codable> {
    private struct Snapshot: Codable {
        let generation: UInt64
        let value: Value
    }

    let url: URL
    var recoveryURL: URL { url.appendingPathExtension("recovery") }

    private func snapshot(at url: URL) -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private var newest: Snapshot? {
        [snapshot(at: url), snapshot(at: recoveryURL)].compactMap { $0 }
            .max { $0.generation < $1.generation }
    }

    func load() -> Value? {
        if let snapshot = newest { return snapshot.value }
        // Migrate the previous flat JSON cache format without losing valid entries.
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        let snapshot = Snapshot(generation: (newest?.generation ?? 0) + 1, value: value)
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        // Recovery is written first; either file may be the newest after interruption.
        try data.write(to: recoveryURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: recoveryURL.path)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
