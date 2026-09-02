import Foundation

/// PRD 规范级别的离线高质量示例数据库（完全契合 PRD 17 节验收数据与 Fast/Deep 链路）
public struct MockTranslationService: Sendable {
    public init() {}

    public func fastAnalyze(text: String, classification: ClassificationResult) async throws -> AnalysisResult {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 场景一：architecture 单词
        if clean.lowercased() == "architecture" {
            return AnalysisResult(
                source: SourceMeta(text: clean, language: .en, contentType: .word),
                translation: TranslationMeta(text: "架构；体系结构；建筑学"),
                pronunciation: PronunciationMeta(speakText: "architecture", locale: "en-US", ipa: "/ˈɑːrkɪtektʃər/"),
                wordAnalysis: WordAnalysisData(
                    lemma: "architecture",
                    partOfSpeech: ["n. 名词"],
                    meanings: [
                        MeaningItem(text: "架构；体系结构；系统布局", usage: "计算机与系统工程"),
                        MeaningItem(text: "建筑学；建筑物设计风格", usage: "工程与艺术")
                    ],
                    collocations: nil,
                    examples: nil
                ),
                sentenceAnalysis: nil
            )
        }

        // 场景二：英语句子 (The feature that we discussed yesterday has been implemented.)
        if clean.contains("The feature that we discussed") || clean.contains("implemented") {
            // "The feature that we discussed yesterday has been implemented."
            // 0...10: "The feature"
            // 12...39: "that we discussed yesterday"
            // 40...60: "has been implemented"
            let text = "The feature that we discussed yesterday has been implemented."
            return AnalysisResult(
                source: SourceMeta(text: text, language: .en, contentType: .sentence),
                translation: TranslationMeta(text: "我们昨天讨论的功能已经实现了。"),
                pronunciation: PronunciationMeta(speakText: text, locale: "en-US"),
                wordAnalysis: nil,
                sentenceAnalysis: SentenceAnalysisData(
                    skeleton: "The feature has been implemented.",
                    chunks: [
                        GrammarChunk(text: "The feature", start: 0, end: 11, role: .subject, label: "主语 (Subject)", explanation: "句子的核心主语名词短语"),
                        GrammarChunk(text: "that we discussed yesterday", start: 12, end: 39, role: .clause, label: "定语从句 (Relative Clause)", explanation: "修饰先行词 feature，说明是昨天讨论的那个功能"),
                        GrammarChunk(text: "has been implemented", start: 40, end: 60, role: .predicate, label: "谓语 (Predicate)", explanation: "现在完成时 + 被动语态")
                    ],
                    clauses: nil,
                    grammarPoints: nil,
                    expressionNotes: nil
                )
            )
        }

        // 场景二-B：复杂从句 (Although the system was originally designed...)
        if clean.contains("Although the system was originally designed") {
            let text = "Although the system was originally designed for small teams, it has gradually evolved into a platform that can support thousands of users."
            return AnalysisResult(
                source: SourceMeta(text: text, language: .en, contentType: .sentence),
                translation: TranslationMeta(text: "虽然该系统最初是为小型团队设计的，但它已经逐渐发展成一个能够支持数千名用户的平台。"),
                pronunciation: PronunciationMeta(speakText: text, locale: "en-US"),
                wordAnalysis: nil,
                sentenceAnalysis: SentenceAnalysisData(
                    skeleton: "it has evolved into a platform",
                    chunks: [
                        GrammarChunk(text: "Although the system was originally designed for small teams", start: 0, end: 59, role: .clause, label: "让步状语从句 (Concession)"),
                        GrammarChunk(text: "it", start: 61, end: 63, role: .subject, label: "主语 (Subject)"),
                        GrammarChunk(text: "has gradually evolved", start: 64, end: 85, role: .predicate, label: "谓语动词 (Predicate)"),
                        GrammarChunk(text: "into a platform", start: 86, end: 101, role: .object, label: "介词宾语 (Object)"),
                        GrammarChunk(text: "that can support thousands of users", start: 102, end: 137, role: .clause, label: "定语从句 (Relative Clause)")
                    ]
                )
            )
        }

        // 场景三：中文表达 (这个方案可以先作为一个兜底方案。)
        if clean.contains("兜底") || clean.contains("方案") {
            return AnalysisResult(
                source: SourceMeta(text: clean, language: .zh, contentType: .sentence),
                translation: TranslationMeta(
                    text: "We can use this as a fallback for now.",
                    alternatives: [
                        "This can serve as a fallback solution for now."
                    ],
                    tone: "日常技术沟通"
                ),
                pronunciation: PronunciationMeta(speakText: "We can use this as a fallback for now.", locale: "en-US"),
                wordAnalysis: nil,
                sentenceAnalysis: nil
            )
        }

        // 通用兜底
        return AnalysisResult(
            source: SourceMeta(text: clean, language: classification.language, contentType: classification.contentType),
            translation: TranslationMeta(
                text: classification.language == .en ? "中文翻译正在生成中..." : "English translation for: \(clean)"
            ),
            pronunciation: PronunciationMeta(speakText: clean, locale: classification.language == .en ? "en-US" : "zh-CN"),
            wordAnalysis: classification.contentType == .word ? WordAnalysisData(
                lemma: clean,
                partOfSpeech: ["n./v."],
                meanings: [MeaningItem(text: "\(clean) 的基本释义")]
            ) : nil,
            sentenceAnalysis: classification.contentType == .sentence ? SentenceAnalysisData(
                skeleton: clean,
                chunks: [
                    GrammarChunk(text: clean, start: 0, end: clean.utf16.count, role: .subject, label: "完整原句")
                ]
            ) : nil
        )
    }

    public func deepAnalyze(text: String, existingResult: AnalysisResult) async throws -> AnalysisResult {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.lowercased() == "architecture" {
            let wordData = WordAnalysisData(
                lemma: "architecture",
                partOfSpeech: ["n. 名词"],
                meanings: [
                    MeaningItem(text: "架构；体系结构；建筑学", usage: "系统工程与设计")
                ],
                collocations: [
                    CollocationItem(text: "software architecture", meaning: "软件架构"),
                    CollocationItem(text: "modular architecture", meaning: "模块化架构"),
                    CollocationItem(text: "system architecture", meaning: "系统架构")
                ],
                examples: [
                    ExampleItem(source: "The system uses a modular architecture.", translation: "系统采用模块化架构。"),
                    ExampleItem(source: "Good architecture makes software easier to maintain.", translation: "优秀的架构让软件更易于维护。")
                ]
            )
            return AnalysisResult(
                source: existingResult.source,
                translation: existingResult.translation,
                pronunciation: existingResult.pronunciation,
                wordAnalysis: wordData,
                sentenceAnalysis: nil
            )
        }

        if clean.contains("The feature that we discussed") || clean.contains("implemented") {
            let sentenceData = SentenceAnalysisData(
                skeleton: "The feature has been implemented.",
                chunks: existingResult.sentenceAnalysis?.chunks ?? [],
                clauses: [
                    Clause(text: "that we discussed yesterday", start: 12, end: 39, type: .relative, label: "定语从句", modifies: "feature")
                ],
                grammarPoints: [
                    GrammarPoint(text: "has been implemented", start: 40, end: 60, name: "时态与语态", explanation: "现在完成时 (have/has + been + 过去分词) + 被动语态，强调过去开始的动作对现在产生的影响")
                ],
                expressionNotes: [
                    ExpressionNote(sourceText: "implemented", targetText: "实现了/落地了", explanation: "在技术语境中表示将设计方案转化为实际代码落地")
                ]
            )
            return AnalysisResult(
                source: existingResult.source,
                translation: existingResult.translation,
                pronunciation: existingResult.pronunciation,
                wordAnalysis: nil,
                sentenceAnalysis: sentenceData
            )
        }

        if clean.contains("兜底") || clean.contains("方案") {
            let sentenceData = SentenceAnalysisData(
                skeleton: "This serves as a fallback.",
                chunks: [],
                clauses: nil,
                grammarPoints: nil,
                expressionNotes: [
                    ExpressionNote(
                        sourceText: "兜底方案",
                        targetText: "fallback / fallback solution",
                        explanation: "“兜底方案”在技术语境下通常使用 fallback，表示主流链路受阻时的容灾与保底手段。",
                        alternatives: ["safety net", "plan B"]
                    ),
                    ExpressionNote(
                        sourceText: "先",
                        targetText: "for now / in the interim",
                        explanation: "“先”可以根据语境翻译为 for now（更口语）或 in the interim（更书面）。",
                        alternatives: ["temporarily", "for the time being"]
                    )
                ]
            )
            return AnalysisResult(
                source: existingResult.source,
                translation: existingResult.translation,
                pronunciation: existingResult.pronunciation,
                wordAnalysis: nil,
                sentenceAnalysis: sentenceData
            )
        }

        return existingResult
    }
}
