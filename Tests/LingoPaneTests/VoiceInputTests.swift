import AVFoundation
import AppKit
import Carbon
import XCTest
@testable import LingoPane

// MARK: - Audio capture & WAV encoding

final class AudioCaptureTests: XCTestCase {
    func testIngestAccumulatesMonoSamplesAndNormalizesLevel() throws {
        let format = try XCTUnwrap(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)
        )
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128))
        buffer.frameLength = 128
        for frame in 0..<128 { buffer.floatChannelData![0][frame] = 0.5 }

        let capture = AudioCaptureBuffer()
        capture.reset(sampleRate: 48_000)
        capture.ingest(buffer)

        let drained = capture.drainSamples()
        XCTAssertEqual(drained.samples.count, 128)
        XCTAssertEqual(drained.sampleRate, 48_000)
        XCTAssertEqual(drained.samples[0], 0.5, accuracy: 0.0001)
        // RMS 0.5 exceeds the 0.20 ceiling, so the level saturates at 1.
        XCTAssertEqual(capture.latestLevel, 1, accuracy: 0.01)
        // Draining releases the samples so audio is not retained after stop.
        XCTAssertTrue(capture.drainSamples().samples.isEmpty)
    }

    func testResampleBoxAveragesSourceFrames() {
        let source: [Float] = [1, 1, 1, 0, 0, 0]
        let output = WAVEncoder.resample(source, from: 6, to: 2)
        XCTAssertEqual(output, [32767, 0])
    }

    func testResampleKeepsDurationAtCommonRates() {
        let output = WAVEncoder.resample([Float](repeating: 0.5, count: 48_000), from: 48_000, to: 16_000)
        XCTAssertEqual(output.count, 16_000)
    }

    func testWAVHeaderDescribesMono16KPCM() {
        let pcm = WAVEncoder.resample([Float](repeating: 0.25, count: 16_000), from: 16_000, to: 16_000)
        let data = WAVEncoder.wavData(pcm: pcm)

        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data.subdata(in: 8..<12), as: UTF8.self), "WAVE")
        XCTAssertEqual(String(decoding: data.subdata(in: 12..<16), as: UTF8.self), "fmt ")
        XCTAssertEqual(littleEndianUInt16(data, at: 20), 1, "PCM format")
        XCTAssertEqual(littleEndianUInt16(data, at: 22), 1, "mono")
        XCTAssertEqual(littleEndianUInt32(data, at: 24), 16_000, "sample rate")
        XCTAssertEqual(littleEndianUInt16(data, at: 32), 2, "block align")
        XCTAssertEqual(littleEndianUInt16(data, at: 34), 16, "bits per sample")
        XCTAssertEqual(String(decoding: data.subdata(in: 36..<40), as: UTF8.self), "data")
        XCTAssertEqual(littleEndianUInt32(data, at: 40), 32_000, "payload size")
        XCTAssertEqual(data.count, 44 + 32_000)
    }

    private func littleEndianUInt16(_ data: Data, at offset: Int) -> UInt32 {
        let bytes = [UInt8](data.subdata(in: offset..<(offset + 2)))
        return UInt32(bytes[0]) | (UInt32(bytes[1]) << 8)
    }

    private func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let bytes = [UInt8](data.subdata(in: offset..<(offset + 4)))
        return UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
    }
}

// MARK: - Menu bar waveform

final class WaveformTests: XCTestCase {
    func testLevelsDecayBetweenUpdates() {
        var levels: [Float] = []
        WaveformLevels.append(raw: 1, to: &levels)
        WaveformLevels.append(raw: 0, to: &levels)
        XCTAssertEqual(levels.last ?? 0, 0.86, accuracy: 0.001)
        WaveformLevels.append(raw: 0, to: &levels)
        XCTAssertEqual(levels.last ?? 0, 0.86 * 0.86, accuracy: 0.001)
    }

    func testLevelsClampAndTrimToBarCount() {
        var levels: [Float] = []
        for _ in 0..<40 { WaveformLevels.append(raw: 4, to: &levels) }
        XCTAssertEqual(levels.count, WaveformLevels.barCount)
        XCTAssertEqual(levels.last ?? 0, 1)
    }

    func testIdleLevelsMatchBarCountAndRange() {
        let levels = WaveformLevels.idleLevels(at: 1.25)
        XCTAssertEqual(levels.count, WaveformLevels.barCount)
        XCTAssertTrue(levels.allSatisfy { $0 > 0 && $0 < 1 })
    }

    func testWaveformImageIsTemplateAtMenuBarSize() {
        let image = WaveformRenderer.image(levels: [0, 0.5, 1])
        XCTAssertEqual(image.size, WaveformRenderer.defaultSize)
        XCTAssertTrue(image.isTemplate)
    }

    func testWaveformActuallyPaintsBars() {
        let image = WaveformRenderer.image(levels: Array(repeating: 1, count: WaveformLevels.barCount))
        guard let rep = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()) else {
            return XCTFail("waveform should rasterize into a bitmap")
        }
        let opaquePixels = (0..<rep.pixelsWide).flatMap { x in
            (0..<rep.pixelsHigh).map { y in rep.colorAt(x: x, y: y)?.alphaComponent ?? 0 }
        }
        XCTAssertGreaterThan(opaquePixels.max() ?? 0, 0.9, "full-height bars should paint solid pixels")
        XCTAssertLessThan(opaquePixels.filter { $0 > 0.1 }.count, rep.pixelsWide * rep.pixelsHigh, "bars should leave gaps")
    }
}

// MARK: - Voice hotkey preferences

final class VoiceHotKeyPreferencesTests: XCTestCase {
    func testDefaultsToOptionV() {
        let shortcut = VoiceHotKeyPreferences.defaultShortcut
        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_V))
        XCTAssertEqual(shortcut.modifierFlags, NSEvent.ModifierFlags.option.rawValue)
        XCTAssertEqual(shortcut.displayName, "⌥V")
    }

    func testRoundTripPersistsCustomShortcut() {
        let original = VoiceHotKeyPreferences.current
        VoiceHotKeyPreferences.save(
            HotKeyShortcut(keyCode: 12, modifierFlags: NSEvent.ModifierFlags.command.rawValue, keyLabel: "W")
        )
        XCTAssertEqual(VoiceHotKeyPreferences.current.keyLabel, "W")
        XCTAssertEqual(VoiceHotKeyPreferences.current.displayName, "⌘W")
        VoiceHotKeyPreferences.save(original)
        XCTAssertEqual(VoiceHotKeyPreferences.current, original)
    }
}

// MARK: - Speech-to-text endpoint & payload

private final class STTStubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var bodyData = request.httpBody
        if bodyData == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
            bodyData = data
        }
        STTStubProtocol.lastBody = bodyData

        let envelope = ["choices": [["message": ["content": "你好"]]]]
        let data = try! JSONSerialization.data(withJSONObject: envelope)
        client?.urlProtocol(
            self,
            didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class SpeechToTextServiceTests: XCTestCase {
    private func configuration(
        baseURL: String,
        provider: ModelProvider,
        model: String = "gemma4:e2b",
        apiKey: String = ""
    ) -> SpeechToTextConfiguration {
        SpeechToTextConfiguration(baseURL: baseURL, model: model, apiKey: apiKey, provider: provider)
    }

    func testOllamaEndpointUsesOpenAICompatibleChatPath() throws {
        let direct = try configuration(baseURL: "http://127.0.0.1:11434", provider: .ollama).endpoint()
        XCTAssertEqual(direct.absoluteString, "http://127.0.0.1:11434/v1/chat/completions")

        let withVersion = try configuration(baseURL: "http://localhost:11434/v1", provider: .ollama).endpoint()
        XCTAssertEqual(withVersion.absoluteString, "http://localhost:11434/v1/chat/completions")
    }

    func testRemoteEndpointRequiresHTTPSAndKey() {
        XCTAssertThrowsError(
            try configuration(baseURL: "http://example.com/v1", provider: .openAICompatible, apiKey: "key").endpoint()
        )
        XCTAssertThrowsError(
            try configuration(baseURL: "https://example.com/v1", provider: .openAICompatible, apiKey: "").endpoint()
        )
        XCTAssertEqual(
            try configuration(baseURL: "https://example.com/v1", provider: .openAICompatible, apiKey: "key").endpoint()
                .absoluteString,
            "https://example.com/v1/chat/completions"
        )
    }

    func testOllamaEndpointRejectsNonLoopbackHTTP() {
        XCTAssertThrowsError(
            try configuration(baseURL: "http://ollama.internal:11434", provider: .ollama).endpoint()
        )
    }

    func testEmptyModelIsRejected() {
        XCTAssertThrowsError(
            try configuration(baseURL: "http://127.0.0.1:11434", provider: .ollama, model: "  ").endpoint()
        )
    }

    func testDecodeTrimsAndUnwrapsQuotedTranscript() throws {
        let quoted = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": "  “你好” "]]]])
        XCTAssertEqual(try SpeechToTextService.decode(quoted), "你好")

        let plain = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": "hello world"]]]])
        XCTAssertEqual(try SpeechToTextService.decode(plain), "hello world")
    }

    func testDecodeRejectsEmptyAndMalformedResponses() {
        let empty = try! JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": "   "]]]])
        XCTAssertThrowsError(try SpeechToTextService.decode(empty))
        XCTAssertThrowsError(try SpeechToTextService.decode(Data("not json".utf8)))
    }

    func testTranscribeSendsAudioBeforeTextAndDisablesOllamaThinking() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [STTStubProtocol.self]
        STTStubProtocol.lastBody = nil
        let service = SpeechToTextService(
            configuration: configuration(baseURL: "http://127.0.0.1:11434", provider: .ollama),
            session: URLSession(configuration: config)
        )

        let wav = Data([0x52, 0x49, 0x46, 0x46])
        let transcript = try await service.transcribe(wav: wav)
        XCTAssertEqual(transcript, "你好")

        let body = try XCTUnwrap(STTStubProtocol.lastBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gemma4:e2b")
        XCTAssertEqual(json["stream"] as? Bool, false)
        XCTAssertEqual(json["think"] as? Bool, false)

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[1]["role"] as? String, "user")

        let content = try XCTUnwrap(messages[1]["content"] as? [[String: Any]])
        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0]["type"] as? String, "input_audio", "audio must precede text")
        let audio = try XCTUnwrap(content[0]["input_audio"] as? [String: Any])
        XCTAssertEqual(audio["format"] as? String, "wav")
        XCTAssertEqual(audio["data"] as? String, wav.base64EncodedString())
        XCTAssertEqual(content[1]["type"] as? String, "text")
    }

    func testTranscribeRejectsEmptyAudio() async {
        let service = SpeechToTextService(
            configuration: configuration(baseURL: "http://127.0.0.1:11434", provider: .ollama)
        )
        do {
            _ = try await service.transcribe(wav: Data())
            XCTFail("expected an error for empty audio")
        } catch {
            XCTAssertEqual(error as? PanelFailure, .message("没有可识别的音频内容"))
        }
    }
}
