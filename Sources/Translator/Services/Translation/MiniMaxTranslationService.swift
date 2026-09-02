import Foundation

/// 基于 MiniMax (OpenAI 兼容协议) 的双层分析智能流水线 (Fast + Deep Analyze)
public struct MiniMaxTranslationService: Sendable {
    private let client: OpenAIClient
    private let model: String
    private let validator = GrammarValidator()
    private let mockService = MockTranslationService()

    public init(client: OpenAIClient, model: String = "MiniMax-M3") {
        self.client = client
        self.model = model
    }

    // MARK: - 1. Fast Analyze (首屏秒出：翻译、单词基础释义、句子主干与成分)
    public func fastAnalyze(text: String, classification: ClassificationResult) async throws -> AnalysisResult {
        let systemPrompt = """
        你是一个精通中英双语的高性能机器翻译与语法分析引擎。
        请根据用户的输入（已分类为 \(classification.language.title) - \(classification.contentType.title)），迅速输出轻量化的首屏分析 JSON。
        严格返回 JSON 对象，不要包含 markdown 代码块或附加文字：
        {
          "schemaVersion": "1.0.0",
          "source": {
            "text": "\(text.replacingOccurrences(of: "\"", with: "\\\""))",
            "language": "\(classification.language.rawValue)",
            "contentType": "\(classification.contentType.rawValue)"
          },
          "translation": {
            "text": "核心精准翻译",
            "alternatives": ["更自然的表达1", "更正式的表达2"],
            "tone": "自然/正式"
          },
          "pronunciation": {
            "speakText": "适合发音的文本",
            "locale": "\(classification.language == .en ? "en-US" : "zh-CN")",
            "ipa": "/国际音标/"
          },
          "wordAnalysis": \(classification.contentType == .word ? """
          {
            "lemma": "\(text)",
            "partOfSpeech": ["n.", "v."],
            "meanings": [
              { "text": "核心中文释义", "usage": "主要用法" }
            ]
          }
          """ : "null"),
          "sentenceAnalysis": \(classification.contentType == .sentence ? """
          {
            "skeleton": "句子核心主干（主谓宾，不要修饰从句）",
            "chunks": [
              { "text": "子串", "start": 0, "end": 0, "role": "subject", "label": "主语" }
            ]
          }
          """ : "null")
        }
        注意：
        1. 如果是句子，chunks 中的每个片段 text 必须来自原句连续子串，start 和 end 必须是 UTF-16 偏移索引！
        2. role 必须为: subject, predicate, object, complement, modifier, adverbial, clause 之一。
        """

        let request = ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ],
            temperature: 0.1
        )

        do {
            let response = try await client.chats(query: request)
            guard let content = response.choices.first?.message.content else {
                throw OpenAIError.emptyResponse
            }
            let rawResult = try decodeJSON(AnalysisResult.self, from: content)
            return validator.validateAndSanitize(result: rawResult, sourceText: text)
        } catch {
            return try await mockService.fastAnalyze(text: text, classification: classification)
        }
    }

    // MARK: - 2. Deep Analyze (按需深析：从句、语法点、固定搭配、例句与表达说明)
    public func deepAnalyze(text: String, existingResult: AnalysisResult) async throws -> AnalysisResult {
        let systemPrompt = """
        你是一个精通英语语法体系与地道跨语言表达的高级语言学专家。
        用户正在查看详细解析，请对输入内容进行深度的语法或表达剖析。
        严格返回 JSON 对象，不要包含 markdown 标记：
        {
          "schemaVersion": "1.0.0",
          "source": {
            "text": "\(text.replacingOccurrences(of: "\"", with: "\\\""))",
            "language": "\(existingResult.source.language.rawValue)",
            "contentType": "\(existingResult.source.contentType.rawValue)"
          },
          "translation": {
            "text": "\(existingResult.translation.text.replacingOccurrences(of: "\"", with: "\\\""))",
            "alternatives": ["备选地道表达1", "备选地道表达2"],
            "tone": "日常技术沟通/正式书面设计"
          },
          "pronunciation": {
            "speakText": "\(existingResult.pronunciation?.speakText ?? text)",
            "locale": "\(existingResult.pronunciation?.locale ?? "en-US")",
            "ipa": "\(existingResult.pronunciation?.ipa ?? "")"
          },
          "wordAnalysis": {
            "lemma": "\(existingResult.wordAnalysis?.lemma ?? text)",
            "partOfSpeech": \(try! String(data: JSONEncoder().encode(existingResult.wordAnalysis?.partOfSpeech ?? ["n."]), encoding: .utf8)!),
            "meanings": \(try! String(data: JSONEncoder().encode(existingResult.wordAnalysis?.meanings ?? []), encoding: .utf8)!),
            "collocations": [
              { "text": "搭配短语", "meaning": "短语释义" }
            ],
            "examples": [
              { "source": "经典双语例句", "translation": "优雅译文" }
            ]
          },
          "sentenceAnalysis": {
            "skeleton": "\(existingResult.sentenceAnalysis?.skeleton ?? text)",
            "chunks": \(try! String(data: JSONEncoder().encode(existingResult.sentenceAnalysis?.chunks ?? []), encoding: .utf8)!),
            "clauses": [
              { "text": "从句子串", "start": 0, "end": 0, "type": "relative", "label": "定语从句", "modifies": "修饰的名词" }
            ],
            "grammarPoints": [
              { "text": "涉及的语法短语", "start": 0, "end": 0, "name": "语法点名称", "explanation": "详细时态或语态解释" }
            ],
            "expressionNotes": [
              { "sourceText": "原词", "targetText": "对应英文", "explanation": "用法说明", "alternatives": ["同义表达"] }
            ]
          }
        }
        注意：所有 text 必须是原文的子串，start/end 是精确的 UTF-16 偏移。
        """

        let request = ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ],
            temperature: 0.2
        )

        do {
            let response = try await client.chats(query: request)
            guard let content = response.choices.first?.message.content else {
                throw OpenAIError.emptyResponse
            }
            let rawResult = try decodeJSON(AnalysisResult.self, from: content)
            return validator.validateAndSanitize(result: rawResult, sourceText: text)
        } catch {
            return try await mockService.deepAnalyze(text: text, existingResult: existingResult)
        }
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from rawString: String) throws -> T {
        var clean = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") {
            clean = String(clean.dropFirst(7))
        } else if clean.hasPrefix("```") {
            clean = String(clean.dropFirst(3))
        }
        if clean.hasSuffix("```") {
            clean = String(clean.dropLast(3))
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = clean.data(using: .utf8) else {
            throw OpenAIError.decodingError(error: NSError(domain: "UTF8", code: 0), rawText: rawString)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
