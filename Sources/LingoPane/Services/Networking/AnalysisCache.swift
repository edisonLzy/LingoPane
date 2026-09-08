import Foundation

actor AnalysisCache {
    static let shared = AnalysisCache()
    private struct Entry: Codable {
        let result: TranslationResult
        let savedAt: Date
    }
    private var entries: [String: Entry]
    private let store: SnapshotStore<[String: Entry]>
    private let lifetime: TimeInterval = 7 * 24 * 3600

    init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("LingoPane")) {
        store = SnapshotStore(url: directory.appendingPathComponent("analysis-cache-v1.json"))
        entries = store.load() ?? [:]
    }

    func get(_ key: String, now: Date = .now) -> TranslationResult? {
        guard let entry = entries[key], now.timeIntervalSince(entry.savedAt) < lifetime else {
            entries[key] = nil
            return nil
        }
        return entry.result
    }

    func put(_ result: TranslationResult, key: String, now: Date = .now) {
        entries = entries.filter { now.timeIntervalSince($0.value.savedAt) < lifetime }
        entries[key] = Entry(result: result, savedAt: now)
        if entries.count > 200 {
            let keep = Set(entries.sorted { $0.value.savedAt > $1.value.savedAt }.prefix(200).map(\.key))
            entries = entries.filter { keep.contains($0.key) }
        }
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    private func persist() {
        do {
            try store.save(entries)
        } catch {
            // A cache is optional; an unavailable disk must not discard a successful translation.
        }
    }
}
