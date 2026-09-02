import Foundation

public struct ClassificationResult: Sendable {
    public let normalizedText: String
    public let language: Language
    public let contentType: ContentType
    public let isTooLong: Bool

    public init(
        normalizedText: String,
        language: Language,
        contentType: ContentType,
        isTooLong: Bool
    ) {
        self.normalizedText = normalizedText
        self.language = language
        self.contentType = contentType
        self.isTooLong = isTooLong
    }
}

/// 本地语种与内容类型快速判定引擎（遵循 PRD 第 8 节规范）
public struct LocalClassifier: Sendable {
    public init() {}

    /// 核心判断方法（0ms 纯本地 CPU 计算，不耗费网络与 Token）
    public func classify(_ rawText: String) -> ClassificationResult {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isTooLong = trimmed.count > 500

        // 1. 语言判定（PRD 8.2 节）
        let hanCount = trimmed.unicodeScalars.filter { CharacterSet(charactersIn: "\u{4E00}"..."\u{9FA5}").contains($0) }.count

        let language: Language
        if hanCount > 0 {
            // 只要含有汉字或者汉字比例突出即作为中文源输入
            language = .zh
        } else {
            language = .en
        }

        // 2. 内容类型判定（PRD 8.1 节）
        let contentType: ContentType
        if language == .en {
            let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if words.count <= 1 && !trimmed.contains(".") && !trimmed.contains("!") && !trimmed.contains("?") {
                contentType = .word
            } else if words.count <= 3 && !trimmed.contains(".") && !trimmed.contains("!") && !trimmed.contains("?") && !trimmed.contains(",") {
                contentType = .phrase
            } else {
                contentType = .sentence
            }
        } else {
            // 中文判定
            if trimmed.count <= 4 {
                contentType = .word
            } else if trimmed.count <= 8 && !trimmed.contains("，") && !trimmed.contains("。") {
                contentType = .phrase
            } else {
                contentType = .sentence
            }
        }

        return ClassificationResult(
            normalizedText: trimmed,
            language: language,
            contentType: contentType,
            isTooLong: isTooLong
        )
    }
}
