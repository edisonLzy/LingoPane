import Foundation

// MARK: - 10.3 统一数据结构定义 (完全对齐 PRD 10.3 规范)

public enum Language: String, Codable, Sendable {
    case zh = "zh"
    case en = "en"

    public var title: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        }
    }
}

public enum ContentType: String, Codable, Sendable {
    case word = "word"
    case phrase = "phrase"
    case sentence = "sentence"

    public var title: String {
        switch self {
        case .word: return "单词"
        case .phrase: return "短语"
        case .sentence: return "句子"
        }
    }
}

public enum GrammarRole: String, Codable, CaseIterable, Sendable {
    case subject = "subject"
    case predicate = "predicate"
    case object = "object"
    case complement = "complement"
    case modifier = "modifier"
    case adverbial = "adverbial"
    case clause = "clause"

    public var title: String {
        switch self {
        case .subject: return "主语"
        case .predicate: return "谓语"
        case .object: return "宾语"
        case .complement: return "补语"
        case .modifier: return "定语/修饰语"
        case .adverbial: return "状语"
        case .clause: return "从句"
        }
    }
}

public enum ClauseType: String, Codable, Sendable {
    case main = "main"
    case relative = "relative"
    case conditional = "conditional"
    case object = "object"
    case subject = "subject"
    case adverbial = "adverbial"
    case complement = "complement"

    public var title: String {
        switch self {
        case .main: return "主句"
        case .relative: return "定语从句"
        case .conditional: return "条件状语从句"
        case .object: return "宾语从句"
        case .subject: return "主语从句"
        case .adverbial: return "状语从句"
        case .complement: return "补足语从句"
        }
    }
}

public struct SourceMeta: Codable, Sendable {
    public let text: String
    public let language: Language
    public let contentType: ContentType

    public init(text: String, language: Language, contentType: ContentType) {
        self.text = text
        self.language = language
        self.contentType = contentType
    }
}

public struct TranslationMeta: Codable, Sendable {
    public let text: String
    public let alternatives: [String]?
    public let tone: String?

    public init(text: String, alternatives: [String]? = nil, tone: String? = nil) {
        self.text = text
        self.alternatives = alternatives
        self.tone = tone
    }
}

public struct PronunciationMeta: Codable, Sendable {
    public let speakText: String
    public let locale: String // "en-US", "en-GB", "zh-CN"
    public let ipa: String?

    public init(speakText: String, locale: String = "en-US", ipa: String? = nil) {
        self.speakText = speakText
        self.locale = locale
        self.ipa = ipa
    }
}

public struct MeaningItem: Codable, Identifiable, Sendable {
    public var id: String { text }
    public let text: String
    public let usage: String?

    public init(text: String, usage: String? = nil) {
        self.text = text
        self.usage = usage
    }
}

public struct CollocationItem: Codable, Identifiable, Sendable {
    public var id: String { text }
    public let text: String
    public let meaning: String

    public init(text: String, meaning: String) {
        self.text = text
        self.meaning = meaning
    }
}

public struct ExampleItem: Codable, Identifiable, Sendable {
    public var id: String { source }
    public let source: String
    public let translation: String

    public init(source: String, translation: String) {
        self.source = source
        self.translation = translation
    }
}

public struct WordAnalysisData: Codable, Sendable {
    public let lemma: String
    public let partOfSpeech: [String]
    public let meanings: [MeaningItem]
    public let collocations: [CollocationItem]?
    public let examples: [ExampleItem]?

    public init(
        lemma: String,
        partOfSpeech: [String],
        meanings: [MeaningItem],
        collocations: [CollocationItem]? = nil,
        examples: [ExampleItem]? = nil
    ) {
        self.lemma = lemma
        self.partOfSpeech = partOfSpeech
        self.meanings = meanings
        self.collocations = collocations
        self.examples = examples
    }
}

public struct GrammarChunk: Codable, Identifiable, Sendable {
    public var id: String { "\(text)_\(start)_\(end)_\(role.rawValue)" }
    public let text: String
    public let start: Int
    public let end: Int
    public let role: GrammarRole
    public let label: String
    public let explanation: String?

    public init(
        text: String,
        start: Int,
        end: Int,
        role: GrammarRole,
        label: String,
        explanation: String? = nil
    ) {
        self.text = text
        self.start = start
        self.end = end
        self.role = role
        self.label = label
        self.explanation = explanation
    }
}

public struct Clause: Codable, Identifiable, Sendable {
    public var id: String { "\(text)_\(start)_\(end)" }
    public let text: String
    public let start: Int
    public let end: Int
    public let type: ClauseType
    public let label: String
    public let modifies: String?

    public init(
        text: String,
        start: Int,
        end: Int,
        type: ClauseType,
        label: String,
        modifies: String? = nil
    ) {
        self.text = text
        self.start = start
        self.end = end
        self.type = type
        self.label = label
        self.modifies = modifies
    }
}

public struct GrammarPoint: Codable, Identifiable, Sendable {
    public var id: String { "\(name)_\(start)" }
    public let text: String
    public let start: Int
    public let end: Int
    public let name: String
    public let explanation: String

    public init(text: String, start: Int, end: Int, name: String, explanation: String) {
        self.text = text
        self.start = start
        self.end = end
        self.name = name
        self.explanation = explanation
    }
}

public struct ExpressionNote: Codable, Identifiable, Sendable {
    public var id: String { "\(sourceText)_\(targetText)" }
    public let sourceText: String
    public let targetText: String
    public let explanation: String
    public let alternatives: [String]?

    public init(sourceText: String, targetText: String, explanation: String, alternatives: [String]? = nil) {
        self.sourceText = sourceText
        self.targetText = targetText
        self.explanation = explanation
        self.alternatives = alternatives
    }
}

public struct SentenceAnalysisData: Codable, Sendable {
    public let skeleton: String
    public let chunks: [GrammarChunk]
    public let clauses: [Clause]?
    public let grammarPoints: [GrammarPoint]?
    public let expressionNotes: [ExpressionNote]?

    public init(
        skeleton: String,
        chunks: [GrammarChunk],
        clauses: [Clause]? = nil,
        grammarPoints: [GrammarPoint]? = nil,
        expressionNotes: [ExpressionNote]? = nil
    ) {
        self.skeleton = skeleton
        self.chunks = chunks
        self.clauses = clauses
        self.grammarPoints = grammarPoints
        self.expressionNotes = expressionNotes
    }
}

/// PRD 核心标准结果数据模型
public struct AnalysisResult: Codable, Sendable {
    public let schemaVersion: String
    public let source: SourceMeta
    public let translation: TranslationMeta
    public let pronunciation: PronunciationMeta?
    public let wordAnalysis: WordAnalysisData?
    public let sentenceAnalysis: SentenceAnalysisData?
    public let warnings: [String]?

    public init(
        schemaVersion: String = "1.0.0",
        source: SourceMeta,
        translation: TranslationMeta,
        pronunciation: PronunciationMeta? = nil,
        wordAnalysis: WordAnalysisData? = nil,
        sentenceAnalysis: SentenceAnalysisData? = nil,
        warnings: [String]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.source = source
        self.translation = translation
        self.pronunciation = pronunciation
        self.wordAnalysis = wordAnalysis
        self.sentenceAnalysis = sentenceAnalysis
        self.warnings = warnings
    }
}
