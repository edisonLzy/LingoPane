import XCTest
@testable import LingoPane

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        if path.contains("timeout") {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        if path.contains("offline") {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        if path.contains("cancel") { return }
        let status = path.contains("auth") ? 401 : 200
        let valid = #"{"primaryResult":"你好","meanings":[{"partOfSpeech":"interj.","meaning":"你好"},42],"ipa":42}"#
        if path == "/api/chat" {
            let bodyData: Data = request.httpBody ?? request.httpBodyStream.map { stream in
                stream.open()
                defer { stream.close() }
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    data.append(buffer, count: count)
                }
                return data
            } ?? Data()
            let body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            let validRequest = body?["format"] as? String == "json"
                && body?["think"] as? Bool == false
                && body?["keep_alive"] as? String == "10m"
                && request.value(forHTTPHeaderField: "Authorization") == nil
            let data = try! JSONSerialization.data(withJSONObject: [
                "message": ["content": validRequest ? valid : "invalid"],
                "done_reason": "stop"
            ])
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let content: String
        if request.url?.host == "api.minimax.io" {
            let bodyData: Data? = request.httpBody ?? request.httpBodyStream.flatMap { stream in
                stream.open()
                defer { stream.close() }
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    data.append(buffer, count: count)
                }
                return data
            }
            let body = bodyData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            if body?["stream"] as? Bool == true {
                let payloads: [[String: Any]] = [
                    ["choices": [["delta": ["reasoning_details": [["text": "思考中"]]], "finish_reason": NSNull()]]],
                    ["choices": [["delta": ["content": #"{"primaryResult":"你"#], "finish_reason": NSNull()]]],
                    ["choices": [["delta": ["content": #"{"primaryResult":"你好","ipa":"/həˈləʊ/","#], "finish_reason": NSNull()]]],
                    ["choices": [["delta": ["content": #"{"primaryResult":"你好","ipa":"/həˈləʊ/","meanings":[{"partOfSpeech":"interj.","meaning":"你好"}]}"#], "finish_reason": NSNull()]]],
                    ["choices": [["delta": [String: String](), "finish_reason": "stop"]]]
                ]
                let events = payloads.map { payload -> String in
                    let data = try! JSONSerialization.data(withJSONObject: payload)
                    return "data: " + String(decoding: data, as: UTF8.self) + "\n\n"
                }.joined() + "data: [DONE]\n\n"
                client?.urlProtocol(self, didReceive: HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "text/event-stream"]
                )!, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(events.utf8))
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            let thinking = body?["thinking"] as? [String: String]
            let hasMiniMaxControls = body?["reasoning_split"] as? Bool == true
                && thinking?["type"] == "disabled"
            content = hasMiniMaxControls ? valid : "invalid"
        } else if path.contains("invalid") {
            content = "invalid"
        } else if path.contains("thinking") {
            content = "<think>reasoning with { braces }</think>\n```json\n\(valid)\n```"
        } else {
            content = valid
        }
        let data = try! JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": content], "finish_reason": "stop"]]
        ])
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class NetworkingTests: XCTestCase {
    private func service(_ path: String) -> OpenAITranslationService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return OpenAITranslationService(
            configuration: ModelConfiguration(baseURL: "https://example.com/" + path, model: "test", apiKey: "test-key"),
            session: URLSession(configuration: config))
    }
    private let classification = Classification(language: .english, kind: .word)

    func testSuccessPreservesSourceAndDropsMalformedLearningFields() async throws {
        let result = try await service("success").analyze("hello", classification: classification)
        XCTAssertEqual(result.primaryResult, "你好")
        XCTAssertEqual(result.source, "hello")
        XCTAssertEqual(result.kind, .word)
        XCTAssertEqual(result.meanings.count, 1)
        XCTAssertNil(result.ipa)
    }

    func testMiniMaxThinkingAndJSONFenceAreIgnored() async throws {
        let result = try await service("thinking").analyze("hello", classification: classification)
        XCTAssertEqual(result.primaryResult, "你好")
    }

    func testMiniMaxM3RequestsSeparatedDisabledThinking() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let service = OpenAITranslationService(
            configuration: ModelConfiguration(
                baseURL: "https://api.minimax.io/v1",
                model: "MiniMax-M3",
                apiKey: "test-key"
            ),
            session: URLSession(configuration: config)
        )
        let result = try await service.analyze("hello", classification: classification)
        XCTAssertEqual(result.primaryResult, "你好")
    }

    @MainActor
    func testMiniMaxStreamPublishesReasoningAndPartialPrimaryResult() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let service = OpenAITranslationService(
            configuration: ModelConfiguration(
                baseURL: "https://api.minimax.io/v1",
                model: "MiniMax-M2.7-highspeed",
                apiKey: "test-key",
                provider: .miniMax
            ),
            session: URLSession(configuration: config)
        )
        var updates: [TranslationProgress] = []
        let result = try await service.analyze("hello", classification: classification) { update in
            updates.append(update)
        }
        XCTAssertEqual(result.primaryResult, "你好")
        XCTAssertTrue(updates.contains { if case .reasoning = $0 { true } else { false } })
        XCTAssertTrue(updates.contains {
            if case .partial(let partial) = $0 { partial.primaryResult == "你好" }
            else { false }
        })
        XCTAssertTrue(updates.contains {
            if case .partial(let partial) = $0 { partial.ipa == "/həˈləʊ/" }
            else { false }
        })
    }

    func testHTTPAndTransportFailures() async {
        for (path, expected) in [
            ("auth", PanelFailure.authentication),
            ("timeout", .networkTimeout),
            ("offline", .message("网络连接失败，请检查网络后重试")),
            ("invalid", .message("模型返回格式无效，请重试"))
        ] {
            do {
                _ = try await service(path).analyze("hello", classification: classification)
                XCTFail("Expected failure: " + path)
            } catch { XCTAssertEqual(error as? PanelFailure, expected) }
        }
    }

    func testCancellation() async throws {
        let service = service("cancel")
        let classification = classification
        let task = Task { try await service.analyze("hello", classification: classification) }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testConfigurationRejectsMissingKeyAndUnsafeURL() {
        XCTAssertThrowsError(try ModelConfiguration(baseURL: "https://example.com", model: "test", apiKey: "").endpoint())
        XCTAssertThrowsError(try ModelConfiguration(baseURL: "http://example.com", model: "test", apiKey: "key").endpoint())
        XCTAssertThrowsError(try ModelConfiguration(baseURL: "https://example.com?key=value", model: "test", apiKey: "key").endpoint())
    }

    func testLocalOllamaUsesNativeEndpointWithoutAPIKey() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let service = OpenAITranslationService(
            configuration: ModelConfiguration(
                baseURL: "http://127.0.0.1:11434/v1",
                model: "qwen3:4b",
                apiKey: "",
                provider: .ollama
            ),
            session: URLSession(configuration: config)
        )
        let result = try await service.analyze("hello", classification: classification)
        XCTAssertEqual(result.primaryResult, "你好")
    }

    func testOllamaRejectsNonLoopbackHTTP() {
        let configuration = ModelConfiguration(
            baseURL: "http://192.168.1.10:11434",
            model: "qwen3:4b",
            apiKey: "",
            provider: .ollama
        )
        XCTAssertThrowsError(try configuration.endpoint())
    }
}
