import Foundation

public protocol TranslationService: Sendable {
    func analyze(_ text: String, classification: Classification) async throws -> TranslationResult
}

public struct MockTranslationService: TranslationService {
    public init() {}

    public func analyze(_ text: String, classification: Classification) async throws -> TranslationResult {
        try await Task.sleep(nanoseconds: 260_000_000)
        try Task.checkCancellation()

        switch classification.kind {
        case .chinese:
            return chineseResult(source: text)
        case .word:
            return wordResult(source: text)
        case .sentence:
            return sentenceResult(source: text)
        }
    }

    private func chineseResult(source: String) -> TranslationResult {
        let isFallback = source.contains("兜底") || source.contains("方案")
        let primary = isFallback
            ? "We can use this as a fallback for now."
            : "This is a natural English expression for the selected text."

        return TranslationResult(
            source: source,
            language: .chinese,
            kind: .chinese,
            primaryResult: primary,
            alternatives: [
                AlternativeExpression(
                    label: "技术沟通",
                    text: "We can keep this as a fallback option for now.",
                    note: "强调它是备用选项，适合产品或工程讨论。"
                ),
                AlternativeExpression(
                    label: "更直接",
                    text: "Let's use this as the fallback for now.",
                    note: "语气更有行动导向。"
                )
            ],
            keywordMappings: [
                KeywordMapping(source: "兜底方案", target: "fallback"),
                KeywordMapping(source: "先", target: "for now")
            ],
            expressionNotes: [
                "use A as B 是表达“把 A 作为 B 使用”的自然结构。",
                "for now 放在句尾，表示当前阶段的临时安排。"
            ],
            examples: [
                ExampleSentence(
                    english: "Keep the cached result as a fallback.",
                    chinese: "保留缓存结果作为兜底。"
                )
            ]
        )
    }

    private func wordResult(source: String) -> TranslationResult {
        let normalized = source.lowercased()
        if normalized == "architecture" {
            return TranslationResult(
                source: source,
                language: .english,
                kind: .word,
                primaryResult: "架构；体系结构；建筑学",
                ipa: "/ˈɑːrkɪtektʃər/",
                meanings: [
                    WordMeaning(partOfSpeech: "n.", meaning: "架构；体系结构"),
                    WordMeaning(partOfSpeech: "n.", meaning: "建筑学；建筑风格")
                ],
                contextMeaning: "当前语境：软件架构",
                collocations: [
                    Collocation(phrase: "system architecture", meaning: "系统架构"),
                    Collocation(phrase: "software architecture", meaning: "软件架构"),
                    Collocation(phrase: "architecture decision", meaning: "架构决策")
                ],
                wordForms: ["architect · n. 建筑师；架构师", "architectural · adj. 建筑的；架构的"],
                examples: [
                    ExampleSentence(
                        english: "The architecture keeps translation fast.",
                        chinese: "这一架构让翻译保持快速。"
                    )
                ]
            )
        }

        return TranslationResult(
            source: source,
            language: .english,
            kind: .word,
            primaryResult: "当前英文词或短语的核心含义",
            meanings: [WordMeaning(partOfSpeech: "phrase", meaning: "按整体语境解释")],
            collocations: [Collocation(phrase: source, meaning: "常见语境用法")],
            examples: [ExampleSentence(english: "This example shows how \(source) is used.", chinese: "这个例句展示了该表达的用法。")]
        )
    }

    private func sentenceResult(source: String) -> TranslationResult {
        let reference = "The feature that we discussed yesterday has been implemented."
        let effectiveSource = source == reference ? source : source
        let annotations = makeAnnotations(for: effectiveSource)
        let primary = source == reference
            ? "我们昨天讨论的功能已经实现了。"
            : "这是所选英文句子的中文翻译预览。"

        return TranslationResult(
            source: effectiveSource,
            language: .english,
            kind: .sentence,
            primaryResult: primary,
            sentenceSkeleton: source == reference ? "The feature has been implemented." : source,
            annotations: annotations,
            clauses: source == reference ? [
                ClauseExplanation(
                    text: "that we discussed yesterday",
                    type: "定语从句",
                    explanation: "修饰 feature，说明这是“我们昨天讨论过的”功能。"
                )
            ] : [],
            grammarPoints: source == reference ? [
                "has been implemented：现在完成时的被动语态",
                "discuss a feature：讨论一项功能"
            ] : ["基础翻译已经可用；更完整的语法分析将在接入模型后生成。"],
            translationNote: source == reference ? "中文中将定语从句前置，语序更自然。" : nil
        )
    }

    private func makeAnnotations(for source: String) -> [GrammarAnnotation] {
        let candidates: [(String, GrammarRole, String, String?)] = [
            ("The feature", .subject, "句子的主语，表示被实现的功能。", nil),
            ("that we discussed", .clause, "定语从句，补充说明 feature。", "feature"),
            ("yesterday", .adverbial, "时间状语，修饰 discussed。", "discussed"),
            ("has been implemented.", .predicate, "谓语，使用现在完成时的被动语态。", "The feature")
        ]

        return candidates.compactMap { text, role, explanation, modifies in
            guard let range = source.range(of: text) else { return nil }
            let start = source.distance(from: source.startIndex, to: range.lowerBound)
            let end = source.distance(from: source.startIndex, to: range.upperBound)
            return GrammarAnnotation(
                text: text,
                start: start,
                end: end,
                role: role,
                explanation: explanation,
                modifies: modifies
            )
        }
    }
}
