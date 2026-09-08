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
        let content = path.contains("invalid") ? "invalid" : #"{"primaryResult":"你好","meanings":[{"partOfSpeech":"interj.","meaning":"你好"},42],"ipa":42}"#
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
}
