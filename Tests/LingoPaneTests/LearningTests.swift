import AppKit
import XCTest
@testable import LingoPane

final class LearningTests: XCTestCase {
    func testDeepDecodingValidatesRangesAndKeepsLearningModules() throws {
        let content = #"{"primaryResult":"功能已经发布。","annotations":[{"text":"feature","start":4,"end":11,"role":"subject","explanation":"主语"},{"text":"wrong","start":0,"end":5,"role":"object","explanation":"无效"}],"alternatives":[{"label":"a","text":"A","note":"a"},{"label":"b","text":"B","note":"b"},{"label":"c","text":"C","note":"c"}],"confusingWords":[{"phrase":"release","meaning":"发布，与发货不同"}],"clauses":[{"text":"has shipped","type":"谓语","explanation":"现在完成时"}]}"#
        let data = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]]])
        let result = try OpenAITranslationService.decode(data, source: "The feature has shipped.",
            classification: Classification(language: .english, kind: .sentence))
        XCTAssertEqual(result.annotations.count, 1)
        XCTAssertEqual(result.alternatives.count, 2)
        XCTAssertEqual(result.confusingWords?.count, 1)
        XCTAssertEqual(result.clauses.count, 1)
    }

    func testDeepDecodingRepairsModelAnnotationOffsetsFromExactText() throws {
        let source = "👩🏽‍💻 The café works."
        let content = #"{"primaryResult":"这家咖啡馆可以营业。","annotations":[{"text":"café","start":99,"end":103,"role":"subject","explanation":"主语"}]}"#
        let data = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]]])
        let result = try OpenAITranslationService.decode(
            data,
            source: source,
            classification: Classification(language: .english, kind: .sentence)
        )
        let annotation = try XCTUnwrap(result.annotations.first)
        let range = try XCTUnwrap(source.range(of: "café"))
        XCTAssertEqual(annotation.start, source.distance(from: source.startIndex, to: range.lowerBound))
        XCTAssertEqual(annotation.end, source.distance(from: source.startIndex, to: range.upperBound))
        XCTAssertTrue(annotation.isValid(in: source))
    }

    func testCachePersistsExpiresAndClears() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = AnalysisCache(directory: directory)
        let result = TranslationResult(source: "hello", language: .english, kind: .word, primaryResult: "你好")
        let now = Date()
        await cache.put(result, key: "fast", now: now)
        let reload = AnalysisCache(directory: directory)
        let hit = await reload.get("fast", now: now)
        XCTAssertEqual(hit?.primaryResult, "你好")
        let deepMiss = await reload.get("deep", now: now)
        XCTAssertNil(deepMiss)
        let expired = await reload.get("fast", now: now.addingTimeInterval(8 * 86400))
        XCTAssertNil(expired)
        await cache.clear()
        let cleared = await cache.get("fast")
        XCTAssertNil(cleared)
    }

    func testVaultHistoryRoundTripPreservesUserNotesAndDailyEncounter() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultHistoryStore(rootURL: directory, movesDeletedItemsToTrash: false)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let result = TranslationResult(
            source: "architecture",
            language: .english,
            kind: .word,
            primaryResult: "架构",
            collocations: [Collocation(phrase: "software architecture", meaning: "软件架构")]
        )
        let item = HistoryItem(
            result: result,
            createdAt: now,
            updatedAt: now,
            lastSeenAt: now,
            encounterCount: 2,
            scenes: [.general, .technical],
            lastScene: .technical
        )

        let url = try store.save(item)
        try store.appendEncounter(for: item, at: now)
        var note = try String(contentsOf: url, encoding: .utf8)
        note = note.replacingOccurrences(
            of: VaultHistoryStore.userStart,
            with: VaultHistoryStore.userStart + "\n重点复习。"
        )
        try Data(note.utf8).write(to: url, options: .atomic)
        _ = try store.save(item)

        let loaded = try XCTUnwrap(store.load().first)
        XCTAssertEqual(loaded.id, item.id)
        XCTAssertEqual(loaded.result.primaryResult, "架构")
        XCTAssertEqual(loaded.encounterCount, 2)
        XCTAssertEqual(loaded.scenes, [.general, .technical])
        XCTAssertTrue(loaded.searchableText.contains("software architecture"))
        let savedNote = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(savedNote.contains("重点复习。"))
        XCTAssertTrue(savedNote.contains("%%\nlingopane-payload-v1:start"))
        XCTAssertFalse(savedNote.contains("<!-- lingopane-payload-v1:start -->"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: store.dailyURL, includingPropertiesForKeys: nil).count, 1)

        try store.delete(id: item.id)
        XCTAssertTrue(store.load().isEmpty)
    }

    func testVaultHistoryLoadMigratesLegacyPayloadWithoutRewritingNote() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultHistoryStore(rootURL: directory, movesDeletedItemsToTrash: false)
        let item = HistoryItem(
            result: TranslationResult(
                source: "legacy note",
                language: .english,
                kind: .word,
                primaryResult: "旧笔记"
            )
        )
        let url = try store.save(item)
        var note = try String(contentsOf: url, encoding: .utf8)
        note = note.replacingOccurrences(
            of: VaultHistoryStore.payloadStart,
            with: "<!-- lingopane-payload-v1:start -->"
        )
        note = note.replacingOccurrences(
            of: VaultHistoryStore.payloadEnd,
            with: "<!-- lingopane-payload-v1:end -->"
        )
        note = "保留这段手工内容。\n" + note
        try Data(note.utf8).write(to: url, options: .atomic)

        let loaded = try XCTUnwrap(store.load().first)
        XCTAssertEqual(loaded.id, item.id)

        let migrated = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(migrated.hasPrefix("保留这段手工内容。\n"))
        XCTAssertTrue(migrated.contains(VaultHistoryStore.payloadStart))
        XCTAssertTrue(migrated.contains(VaultHistoryStore.payloadEnd))
        XCTAssertFalse(migrated.contains("<!-- lingopane-payload-v1:start -->"))
        XCTAssertFalse(migrated.contains("<!-- lingopane-payload-v1:end -->"))
    }

    func testHotKeyDisplayNameUsesMacModifierOrder() {
        let shortcut = HotKeyShortcut(
            keyCode: 0,
            modifierFlags: NSEvent.ModifierFlags([.command, .option, .shift]).rawValue,
            keyLabel: "A"
        )
        XCTAssertEqual(shortcut.displayName, "⌥⇧⌘A")
    }

    func testArrangementUsesColumnsAndNeverOverflows() throws {
        let visible = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let frames = try XCTUnwrap(PanelArrangement.frames(sizes: Array(repeating: CGSize(width: 400, height: 400), count: 6), in: visible))
        XCTAssertEqual(frames.count, 6)
        XCTAssertTrue(frames.allSatisfy { visible.contains($0) })
        for i in frames.indices {
            for j in frames.indices where i != j { XCTAssertFalse(frames[i].intersects(frames[j])) }
        }
        XCTAssertNil(PanelArrangement.frames(sizes: Array(repeating: CGSize(width: 400, height: 560), count: 8), in: visible))
        let collapsed = PanelArrangement.frames(sizes: Array(repeating: CGSize(width: 400, height: 78), count: 8), in: visible)
        XCTAssertEqual(collapsed?.count, 8)
    }

    @MainActor
    func testPanelRestartResetsLearningAndDisclosure() {
        let model = PanelViewModel(source: "hello", classification: Classification(language: .english, kind: .word))
        model.deepReady = true
        model.deepFailure = "failed"
        model.isExpanded = true
        model.isCollapsed = true
        model.start(source: "world", classification: model.classification)
        XCTAssertFalse(model.deepReady)
        XCTAssertFalse(model.isExpanded)
        XCTAssertFalse(model.isCollapsed)
        XCTAssertNil(model.deepFailure)
    }
}
