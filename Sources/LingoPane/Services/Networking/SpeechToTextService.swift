import Foundation

struct SpeechToTextConfiguration: Sendable {
    let baseURL: String
    let model: String
    let apiKey: String
    let provider: ModelProvider

    static let defaultModel = "gemma4:e2b"

    /// Reuses the translation provider/Base URL/API Key; only the speech
    /// model has its own setting.
    static func saved() throws -> Self {
        let translation = try ModelConfiguration.saved()
        let configured = UserDefaults.standard.string(forKey: "sttModel")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Self(
            baseURL: translation.baseURL,
            model: configured.isEmpty ? defaultModel : configured,
            apiKey: translation.apiKey,
            provider: translation.provider
        )
    }

    /// Audio goes through the OpenAI-compatible chat endpoint: Ollama's
    /// native `/api/chat` can silently drop audio payloads, while
    /// `/v1/chat/completions` accepts `input_audio` content blocks.
    func endpoint() throws -> URL {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PanelFailure.message("请在设置中配置语音识别模型")
        }
        guard var url = URL(string: baseURL),
              url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            throw PanelFailure.message("请配置有效的 Base URL")
        }
        if provider == .ollama {
            guard url.scheme == "https" || (url.scheme == "http" && url.isLoopback) else {
                throw PanelFailure.message("本地 Ollama 的 HTTP 地址必须使用 localhost、127.0.0.1 或 ::1")
            }
            if url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "v1" {
                url.deleteLastPathComponent()
            }
            return url.appendingPathComponent("v1/chat/completions")
        }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PanelFailure.message("请在设置中保存 API Key")
        }
        guard url.scheme == "https" else {
            throw PanelFailure.message("远程模型服务必须使用 HTTPS")
        }
        return url.appendingPathComponent("chat/completions")
    }
}

struct SpeechToTextService: Sendable {
    let configuration: SpeechToTextConfiguration
    var session: URLSession = .shared

    static let systemPrompt = """
    You are a speech-to-text engine. Transcribe the user's audio exactly as spoken, \
    keeping the original language (Chinese stays Chinese, English stays English). \
    Output only the transcribed text: no answers, no commentary, no quotation \
    marks, no markdown.
    """

    func transcribe(wav: Data) async throws -> String {
        guard !wav.isEmpty else { throw PanelFailure.message("没有可识别的音频内容") }
        var request = URLRequest(url: try configuration.endpoint())
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty { request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": configuration.model,
            "stream": false,
            "temperature": 0,
            "max_tokens": 512,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": [
                    // Audio must precede text for multimodal chat templates.
                    ["type": "input_audio", "input_audio": ["data": wav.base64EncodedString(), "format": "wav"]],
                    ["type": "text", "text": "Transcribe this audio verbatim."]
                ]]
            ]
        ]
        if configuration.provider == .ollama { body["think"] = false }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            try Self.validate(response)
            return try Self.decode(data)
        } catch let error as URLError {
            if Task.isCancelled || error.code == .cancelled { throw CancellationError() }
            if error.code == .timedOut { throw PanelFailure.networkTimeout }
            throw PanelFailure.message("语音识别服务连接失败")
        }
    }

    static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw PanelFailure.message("语音识别服务响应无效") }
        switch http.statusCode {
        case 200..<300: break
        case 401, 403: throw PanelFailure.authentication
        case 408, 504: throw PanelFailure.networkTimeout
        case 429: throw PanelFailure.message("请求过于频繁或额度不足，请稍后重试")
        default: throw PanelFailure.message("语音识别服务请求失败（HTTP \(http.statusCode)）")
        }
    }

    static func decode(_ data: Data) throws -> String {
        struct Envelope: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let content = envelope.choices.first?.message.content else {
            throw PanelFailure.message("语音识别服务返回格式无效")
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PanelFailure.message("未识别到语音内容") }
        // Models occasionally wrap the transcript in quotes.
        let quotePairs: [(Character, Character)] = [("\"", "\""), ("“", "”")]
        for (open, close) in quotePairs where trimmed.count >= 2 {
            guard trimmed.first == open, trimmed.last == close else { continue }
            let inner = trimmed.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
            if !inner.isEmpty { return inner }
        }
        return trimmed
    }
}

private extension URL {
    var isLoopback: Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "localhost" || host == "::1" || host.hasPrefix("127.")
    }
}
