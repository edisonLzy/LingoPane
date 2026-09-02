import Foundation

/// 句子重点核心词汇
public struct KeyWord: Codable, Identifiable, Sendable {
    public var id: String { word }
    public let word: String
    public let pos: String
    public let def: String

    public init(word: String, pos: String, def: String) {
        self.word = word
        self.pos = pos
        self.def = def
    }
}

/// 句子关键短语搭配
public struct KeyPhrase: Codable, Identifiable, Sendable {
    public var id: String { phrase }
    public let phrase: String
    public let def: String

    public init(phrase: String, def: String) {
        self.phrase = phrase
        self.def = def
    }
}

/// 英语句子解析完整模型
public struct SentenceAnalysis: Codable, Identifiable, Sendable {
    public var id: String { original }
    public let original: String
    public let translation: String
    public let syntaxSpans: [SyntaxSpan]
    public let keyWords: [KeyWord]
    public let keyPhrases: [KeyPhrase]

    public init(
        original: String,
        translation: String,
        syntaxSpans: [SyntaxSpan],
        keyWords: [KeyWord],
        keyPhrases: [KeyPhrase]
    ) {
        self.original = original
        self.translation = translation
        self.syntaxSpans = syntaxSpans
        self.keyWords = keyWords
        self.keyPhrases = keyPhrases
    }
}
