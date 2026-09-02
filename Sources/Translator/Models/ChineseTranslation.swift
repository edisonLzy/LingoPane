import Foundation

/// 中译英单项表达（不同场景风格）
public struct TranslationStyleItem: Codable, Identifiable, Sendable {
    public var id: String { text }
    public let tag: String  // e.g. "自然日常沟通", "正式书面设计", "学术地道"
    public let text: String // 译文

    public init(tag: String, text: String) {
        self.tag = tag
        self.text = text
    }
}

/// 中文翻译结果模型
public struct ChineseAnalysis: Codable, Identifiable, Sendable {
    public var id: String { sourceText }
    public let sourceText: String
    public let translations: [TranslationStyleItem]

    public init(sourceText: String, translations: [TranslationStyleItem]) {
        self.sourceText = sourceText
        self.translations = translations
    }
}
