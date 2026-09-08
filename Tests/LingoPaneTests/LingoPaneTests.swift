import XCTest
@testable import LingoPane

final class LingoPaneTests: XCTestCase {
    func testClassifierRoutesChineseContent() {
        let result = LocalClassifier().classify("这个方案可以先作为兜底方案。")
        XCTAssertEqual(result, Classification(language: .chinese, kind: .chinese))
    }

    func testClassifierRoutesEnglishWordAndPhrase() {
        let classifier = LocalClassifier()
        XCTAssertEqual(
            classifier.classify("architecture"),
            Classification(language: .english, kind: .word)
        )
        XCTAssertEqual(
            classifier.classify("look forward to"),
            Classification(language: .english, kind: .word)
        )
    }

    func testClassifierRoutesEnglishSentence() {
        let result = LocalClassifier().classify("The feature has been implemented.")
        XCTAssertEqual(result, Classification(language: .english, kind: .sentence))
    }

    func testGrammarAnnotationRequiresExactContinuousSubstring() {
        let source = "The feature has shipped."
        XCTAssertTrue(
            GrammarAnnotation(
                text: "The feature",
                start: 0,
                end: 11,
                role: .subject,
                explanation: "subject"
            ).isValid(in: source)
        )
        XCTAssertFalse(
            GrammarAnnotation(
                text: "feature has",
                start: 0,
                end: 11,
                role: .subject,
                explanation: "invalid range"
            ).isValid(in: source)
        )
    }
}
