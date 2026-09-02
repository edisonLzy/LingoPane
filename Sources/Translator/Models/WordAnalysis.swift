import Foundation

/// 单词词性及定义
public struct WordMeaning: Codable, Identifiable, Sendable {
    public var id: String { "\(pos)_\(def)" }
    public let pos: String       // e.g. "adj.", "n.", "v."
    public let def: String       // e.g. "对称的；匀称的；两边大小形状完全一致的"

    public init(pos: String, def: String) {
        self.pos = pos
        self.def = def
    }
}

/// 双语例句
public struct ExampleSentence: Codable, Identifiable, Sendable {
    public var id: String { en }
    public let en: String        // e.g. "Mount Fuji presents a beautiful, nearly symmetric profile."
    public let cn: String        // e.g. "从远处看，富士山呈现出优美、近乎对称的轮廓。"

    public init(en: String, cn: String) {
        self.en = en
        self.cn = cn
    }
}

/// 英语单词解析完整模型
public struct WordAnalysis: Codable, Identifiable, Sendable {
    public var id: String { word }
    public let word: String
    public let phonetic: String
    public let root: String
    public let meanings: [WordMeaning]
    public let synonyms: [String]
    public let examples: [ExampleSentence]

    public init(
        word: String,
        phonetic: String,
        root: String,
        meanings: [WordMeaning],
        synonyms: [String],
        examples: [ExampleSentence]
    ) {
        self.word = word
        self.phonetic = phonetic
        self.root = root
        self.meanings = meanings
        self.synonyms = synonyms
        self.examples = examples
    }
}
