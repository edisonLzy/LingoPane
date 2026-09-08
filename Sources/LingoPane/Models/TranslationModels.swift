import Foundation

public enum Language: String, Codable, CaseIterable, Sendable {
    case chinese
    case english

    public var title: String { self == .chinese ? "中文" : "英文" }
    public var localeIdentifier: String { self == .chinese ? "zh-CN" : "en-US" }
}

public enum ContentKind: String, Codable, CaseIterable, Sendable {
    case chinese
    case word
    case sentence

    public var title: String {
        switch self {
        case .chinese: "中文内容"
        case .word: "单词/短语"
        case .sentence: "英文句子"
        }
    }

    public var shortTitle: String {
        switch self {
        case .chinese: "句子"
        case .word: "单词"
        case .sentence: "句子"
        }
    }
}

public struct Classification: Equatable, Sendable {
    public let language: Language
    public let kind: ContentKind

    public init(language: Language, kind: ContentKind) {
        self.language = language
        self.kind = kind
    }
}

public struct AlternativeExpression: Identifiable, Codable, Sendable {
    public let id: UUID
    public let label: String
    public let text: String
    public let note: String

    public init(id: UUID = UUID(), label: String, text: String, note: String) {
        self.id = id
        self.label = label
        self.text = text
        self.note = note
    }
}

public struct KeywordMapping: Identifiable, Codable, Sendable {
    public let id: UUID
    public let source: String
    public let target: String

    public init(id: UUID = UUID(), source: String, target: String) {
        self.id = id
        self.source = source
        self.target = target
    }
}

public struct WordMeaning: Identifiable, Codable, Sendable {
    public let id: UUID
    public let partOfSpeech: String
    public let meaning: String

    public init(id: UUID = UUID(), partOfSpeech: String, meaning: String) {
        self.id = id
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
    }
}

public struct Collocation: Identifiable, Codable, Sendable {
    public let id: UUID
    public let phrase: String
    public let meaning: String

    public init(id: UUID = UUID(), phrase: String, meaning: String) {
        self.id = id
        self.phrase = phrase
        self.meaning = meaning
    }
}

public struct ExampleSentence: Identifiable, Codable, Sendable {
    public let id: UUID
    public let english: String
    public let chinese: String

    public init(id: UUID = UUID(), english: String, chinese: String) {
        self.id = id
        self.english = english
        self.chinese = chinese
    }
}

public enum GrammarRole: String, Codable, CaseIterable, Sendable {
    case subject
    case predicate
    case object
    case complement
    case modifier
    case adverbial
    case clause

    public var title: String {
        switch self {
        case .subject: "主语"
        case .predicate: "谓语"
        case .object: "宾语"
        case .complement: "补语"
        case .modifier: "定语"
        case .adverbial: "状语"
        case .clause: "从句"
        }
    }
}

public struct GrammarAnnotation: Identifiable, Codable, Sendable {
    public let id: UUID
    public let text: String
    public let start: Int
    public let end: Int
    public let role: GrammarRole
    public let explanation: String
    public let modifies: String?

    public init(
        id: UUID = UUID(),
        text: String,
        start: Int,
        end: Int,
        role: GrammarRole,
        explanation: String,
        modifies: String? = nil
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.role = role
        self.explanation = explanation
        self.modifies = modifies
    }

    public func isValid(in source: String) -> Bool {
        guard start >= 0, end > start, end <= source.count else { return false }
        let lower = source.index(source.startIndex, offsetBy: start)
        let upper = source.index(source.startIndex, offsetBy: end)
        return String(source[lower..<upper]) == text
    }
}

public struct ClauseExplanation: Identifiable, Codable, Sendable {
    public let id: UUID
    public let text: String
    public let type: String
    public let explanation: String

    public init(id: UUID = UUID(), text: String, type: String, explanation: String) {
        self.id = id
        self.text = text
        self.type = type
        self.explanation = explanation
    }
}

public struct TranslationResult: Identifiable, Codable, Sendable {
    public let id: UUID
    public let source: String
    public let language: Language
    public let kind: ContentKind
    public let primaryResult: String
    public let ipa: String?
    public let meanings: [WordMeaning]
    public let contextMeaning: String?
    public let alternatives: [AlternativeExpression]
    public let keywordMappings: [KeywordMapping]
    public let expressionNotes: [String]
    public let collocations: [Collocation]
    public let wordForms: [String]
    public let examples: [ExampleSentence]
    public let sentenceSkeleton: String?
    public let annotations: [GrammarAnnotation]
    public let clauses: [ClauseExplanation]
    public let grammarPoints: [String]
    public let translationNote: String?

    public init(
        id: UUID = UUID(),
        source: String,
        language: Language,
        kind: ContentKind,
        primaryResult: String,
        ipa: String? = nil,
        meanings: [WordMeaning] = [],
        contextMeaning: String? = nil,
        alternatives: [AlternativeExpression] = [],
        keywordMappings: [KeywordMapping] = [],
        expressionNotes: [String] = [],
        collocations: [Collocation] = [],
        wordForms: [String] = [],
        examples: [ExampleSentence] = [],
        sentenceSkeleton: String? = nil,
        annotations: [GrammarAnnotation] = [],
        clauses: [ClauseExplanation] = [],
        grammarPoints: [String] = [],
        translationNote: String? = nil
    ) {
        self.id = id
        self.source = source
        self.language = language
        self.kind = kind
        self.primaryResult = primaryResult
        self.ipa = ipa
        self.meanings = meanings
        self.contextMeaning = contextMeaning
        self.alternatives = alternatives
        self.keywordMappings = keywordMappings
        self.expressionNotes = expressionNotes
        self.collocations = collocations
        self.wordForms = wordForms
        self.examples = examples
        self.sentenceSkeleton = sentenceSkeleton
        self.annotations = annotations.filter { $0.isValid(in: source) }
        self.clauses = clauses
        self.grammarPoints = grammarPoints
        self.translationNote = translationNote
    }
}

public struct HistoryItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let result: TranslationResult
    public let createdAt: Date

    public init(id: UUID = UUID(), result: TranslationResult, createdAt: Date = .now) {
        self.id = id
        self.result = result
        self.createdAt = createdAt
    }
}

public enum PanelFailure: LocalizedError, Equatable, Sendable {
    case noSelection
    case accessibilityPermission
    case networkTimeout
    case authentication
    case overlong(limit: Int)
    case grammarUnavailable
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .noSelection: "未检测到选区"
        case .accessibilityPermission: "需要辅助功能权限"
        case .networkTimeout: "网络请求超时"
        case .authentication: "模型鉴权失败"
        case .overlong(let limit): "内容超过 \(limit) 个字符"
        case .grammarUnavailable: "语法解析暂不可用"
        case .message(let message): message
        }
    }
}
