import Foundation

/// OpenAI 协议的 Chat Completion 请求模型
public struct ChatCompletionRequest: Codable, Sendable {
    public let model: String
    public let messages: [ChatMessage]
    public let temperature: Double?
    public let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }

    public init(
        model: String,
        messages: [ChatMessage],
        temperature: Double? = 0.3,
        responseFormat: ResponseFormat? = ResponseFormat(type: "json_object")
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.responseFormat = responseFormat
    }
}

public struct ResponseFormat: Codable, Sendable {
    public let type: String // "json_object" or "text"

    public init(type: String = "json_object") {
        self.type = type
    }
}

public struct ChatMessage: Codable, Sendable {
    public let role: String // "system", "user", "assistant"
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// OpenAI 协议的 Chat Completion 响应模型
public struct ChatCompletionResponse: Codable, Sendable {
    public let id: String?
    public let choices: [ChatChoice]
    public let usage: ChatUsage?

    public init(id: String?, choices: [ChatChoice], usage: ChatUsage?) {
        self.id = id
        self.choices = choices
        self.usage = usage
    }
}

public struct ChatChoice: Codable, Sendable {
    public let index: Int?
    public let message: ChatMessage
    public let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

public struct ChatUsage: Codable, Sendable {
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}
