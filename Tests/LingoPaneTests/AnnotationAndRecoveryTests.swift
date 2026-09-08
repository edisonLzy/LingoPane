import XCTest
@testable import LingoPane

final class AnnotationAndRecoveryTests: XCTestCase {
    private func annotation(_ text: String, in source: String, role: GrammarRole) -> GrammarAnnotation {
        let range = source.range(of: text)!
        return GrammarAnnotation(text: text, start: source.distance(from: source.startIndex, to: range.lowerBound),
            end: source.distance(from: source.startIndex, to: range.upperBound), role: role, explanation: role.title)
    }

    func testNestedClausesAndUTF16Offsets() throws {
        let source = "👩🏽‍💻 I know that she said that café works."
        let outer = annotation("that she said that café works", in: source, role: .clause)
        let inner = annotation("that café works", in: source, role: .clause)
        let subject = annotation("café", in: source, role: .subject)
        let layout = AnnotationLayout(source: source, annotations: [subject, inner, outer])
        XCTAssertEqual(layout.visible(includeNested: false).map(\.id), [outer.id])
        XCTAssertEqual(layout.visible(includeNested: true).count, 3)
        XCTAssertTrue(layout.hasNested)
        let native = try XCTUnwrap(layout.nativeRange(of: subject))
        XCTAssertEqual((source as NSString).substring(with: native), "café")
        XCTAssertGreaterThan(native.location, subject.start, "Emoji offsets must be converted to UTF-16")
        XCTAssertEqual(layout.annotation(atUTF16: native.location, includeNested: true)?.id, subject.id)
        XCTAssertEqual(layout.annotation(atUTF16: native.location, includeNested: false)?.id, outer.id)
    }

    @MainActor
    func testEscapeDismissesFocusedCardBeforeDisclosureAndWindow() {
        let model = PanelViewModel(source: "Hello.", classification: Classification(language: .english, kind: .sentence))
        var closed = false
        model.closeAction = { closed = true }
        model.isExpanded = true
        let id = UUID()
        model.focusAnnotation(id)
        XCTAssertEqual(model.activeAnnotationID, id)
        model.handleEscape()
        XCTAssertNil(model.activeAnnotationID)
        XCTAssertTrue(model.isExpanded)
        model.focusAnnotation(id)
        XCTAssertNil(model.activeAnnotationID, "Unchanged keyboard focus must not reopen a dismissed card")
        model.handleEscape()
        XCTAssertFalse(model.isExpanded)
        XCTAssertFalse(closed)
        model.handleEscape()
        XCTAssertTrue(closed)
    }

    @MainActor
    func testNativeAnnotationKeepsTheEntireOriginalString() {
        let source = "The café 👩🏽‍💻 works.\n  Keep  whitespace."
        let view = AnnotationTextView(frame: .zero)
        view.configure(source: source, annotations: [annotation("café", in: source, role: .subject)], includeNested: false)
        XCTAssertEqual(view.string, source)
        XCTAssertEqual(view.textStorage?.string, source)
        XCTAssertEqual(view.accessibilityCustomActions()?.count, 1)
    }

    func testSnapshotRecoversInterruptedWriteAndClearedData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnapshotStore<[String]>(url: directory.appendingPathComponent("history.json"))
        try store.save(["old"])
        let oldPrimary = try Data(contentsOf: store.url)
        try store.save(["new"])
        // Simulate interruption after the recovery generation was committed.
        try oldPrimary.write(to: store.url, options: .atomic)
        XCTAssertEqual(store.load(), ["new"])
        try store.save([])
        try Data("corrupt".utf8).write(to: store.url)
        XCTAssertEqual(store.load(), [], "Clear must not resurrect an older nonempty backup")
    }

    func testSnapshotSurvivesCorruptRecoveryAndMigratesLegacyJSON() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = SnapshotStore<[String]>(url: directory.appendingPathComponent("cache.json"))
        try JSONEncoder().encode(["legacy"]).write(to: store.url)
        XCTAssertEqual(store.load(), ["legacy"])
        try store.save(["current"])
        try Data("broken".utf8).write(to: store.recoveryURL)
        XCTAssertEqual(store.load(), ["current"])
    }
}
