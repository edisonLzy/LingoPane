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

    func testHistoryRetentionAndPermanentMode() {
        let now = Date()
        let result = TranslationResult(source: "hello", language: .english, kind: .word, primaryResult: "你好")
        let items = [HistoryItem(result: result, createdAt: now),
            HistoryItem(result: result, createdAt: now.addingTimeInterval(-40 * 86400))]
        XCTAssertEqual(HistoryStore.prune(items, now: now, days: 30).count, 1)
        XCTAssertEqual(HistoryStore.prune(items, now: now, days: 0).count, 2)
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
