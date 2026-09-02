import Testing
import Foundation
@testable import Translator

@Suite("Translator PRD 完整核心逻辑与模型测试")
struct TranslatorTests {

    @Test("PRD 8 节本地分类引擎测试")
    func testLocalClassifier() {
        let classifier = LocalClassifier()

        // 单词
        let wordRes = classifier.classify("architecture")
        #expect(wordRes.contentType == .word)
        #expect(wordRes.language == .en)
        #expect(!wordRes.isTooLong)

        // 短语
        let phraseRes = classifier.classify("look forward to")
        #expect(phraseRes.contentType == .phrase)
        #expect(phraseRes.language == .en)

        // 句子
        let sentenceRes = classifier.classify("The feature that we discussed yesterday has been implemented.")
        #expect(sentenceRes.contentType == .sentence)
        #expect(sentenceRes.language == .en)

        // 中文句子
        let cnRes = classifier.classify("这个方案可以先作为一个兜底方案。")
        #expect(cnRes.contentType == .sentence)
        #expect(cnRes.language == .zh)

        // 500 字符限制 (PRD 13.5)
        let longText = String(repeating: "word ", count: 120)
        let longRes = classifier.classify(longText)
        #expect(longRes.isTooLong)
    }

    @Test("PRD 10.5 节语法切片校验器安全过滤测试")
    func testGrammarValidator() {
        let validator = GrammarValidator()
        let source = "The feature that we discussed yesterday has been implemented."

        let result = AnalysisResult(
            source: SourceMeta(text: source, language: .en, contentType: .sentence),
            translation: TranslationMeta(text: "功能已实现"),
            sentenceAnalysis: SentenceAnalysisData(
                skeleton: "The feature has been implemented.",
                chunks: [
                    // 合法 chunk (0...11: "The feature")
                    GrammarChunk(text: "The feature", start: 0, end: 11, role: .subject, label: "主语"),
                    // 越界或文字不符的非法 chunk
                    GrammarChunk(text: "invalid", start: 50, end: 90, role: .predicate, label: "越界谓语")
                ]
            )
        )

        let sanitized = validator.validateAndSanitize(result: result, sourceText: source)
        #expect(sanitized.sentenceAnalysis?.chunks.count == 1)
        #expect(sanitized.sentenceAnalysis?.chunks.first?.text == "The feature")
        #expect(sanitized.translation.text == "功能已实现") // 校验失败不影响翻译
        #expect(sanitized.warnings != nil)
    }

    @Test("PRD 15 节本地缓存存储与读取测试")
    func testCacheStore() async {
        let store = AnalysisCacheStore.shared
        let key = await store.makeKey(
            text: "architecture",
            sourceLang: .en,
            targetLang: .zh,
            contentType: .word,
            level: "fast",
            model: "MiniMax-M3"
        )

        let mockResult = AnalysisResult(
            source: SourceMeta(text: "architecture", language: .en, contentType: .word),
            translation: TranslationMeta(text: "架构")
        )

        await store.set(key: key, result: mockResult)
        let hit = await store.get(key: key)
        #expect(hit != nil)
        #expect(hit?.translation.text == "架构")
    }

    @Test("Fast Analyze 与 Deep Analyze 两级流水线测试")
    func testTwoTierPipeline() async throws {
        let service = MockTranslationService()
        let classifier = LocalClassifier()
        let text = "The feature that we discussed yesterday has been implemented."
        let classification = classifier.classify(text)

        // 1. Fast Analyze
        let fastResult = try await service.fastAnalyze(text: text, classification: classification)
        #expect(fastResult.sentenceAnalysis?.skeleton == "The feature has been implemented.")
        #expect(fastResult.sentenceAnalysis?.chunks.count == 3)
        #expect(fastResult.sentenceAnalysis?.clauses == nil) // 首屏不展示复杂从句

        // 2. Deep Analyze (用户主动点击后展开)
        let deepResult = try await service.deepAnalyze(text: text, existingResult: fastResult)
        #expect(deepResult.sentenceAnalysis?.clauses?.count == 1)
        #expect(deepResult.sentenceAnalysis?.grammarPoints?.count == 1)
    }
}
