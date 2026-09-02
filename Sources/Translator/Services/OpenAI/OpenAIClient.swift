import Foundation

/// 纯原生实现的 OpenAI 兼容客户端（零三方依赖，完全兼容 MiniMax / OpenAI 协议）
public actor OpenAIClient {
    public var configuration: OpenAIConfiguration
    private let urlSession: URLSession

    public init(configuration: OpenAIConfiguration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    public func updateToken(_ token: String) {
        self.configuration.token = token
    }

    public func updateHost(_ host: String) {
        self.configuration.host = host
    }

    /// 发起 Chat Completion 对话请求
    public func chats(query: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        guard let url = configuration.url(for: "chat/completions") else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !configuration.token.isEmpty {
            request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(query)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ChatCompletionResponse.self, from: data)
        } catch {
            let responseString = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError.decodingError(error: error, rawText: responseString)
        }
    }
}

public enum OpenAIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case decodingError(error: Error, rawText: String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "API 地址格式不正确"
        case .invalidResponse:
            return "收到非法的 HTTP 响应"
        case .apiError(let statusCode, let message):
            return "API 请求失败 [HTTP \(statusCode)]: \(message)"
        case .decodingError(let error, let rawText):
            return "JSON 解析失败: \(error.localizedDescription) \n原始响应: \(rawText)"
        case .emptyResponse:
            return "模型未返回任何有效文本"
        }
    }
}
