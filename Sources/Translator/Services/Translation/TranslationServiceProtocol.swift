import Foundation

/// 统一翻译与结构化分析服务协议
public protocol TranslationServiceProtocol: Sendable {
    /// 单词解析：词根、音标、多词性含义、同义词、例句
    func analyzeWord(_ word: String) async throws -> WordAnalysis

    /// 句子解析：彩线下划线成分分析、重点词汇、关键短语、中文翻译
    func analyzeSentence(_ sentence: String) async throws -> SentenceAnalysis

    /// 中文翻译：多场景地道英文表达（自然日常沟通 vs 正式书面设计）
    func translateChinese(_ text: String) async throws -> ChineseAnalysis
}
