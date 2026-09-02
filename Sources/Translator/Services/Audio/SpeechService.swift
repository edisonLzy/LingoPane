import Foundation
import AVFoundation
import Observation

/// 原生音频朗读服务（支持 @Observable 状态驱动与丝滑发音动效）
@Observable
@MainActor
public final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = SpeechService()

    public var currentlySpeakingText: String? = nil

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// 播放文本语音
    public func speak(_ text: String, language: String? = nil) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            currentlySpeakingText = nil
            return
        }

        currentlySpeakingText = cleanText

        let utterance = AVSpeechUtterance(string: cleanText)
        let targetLanguage: String
        if let language = language {
            targetLanguage = language
        } else {
            let isChinese = cleanText.range(of: "\\p{Han}", options: .regularExpression) != nil
            targetLanguage = isChinese ? "zh-CN" : "en-US"
        }

        utterance.voice = AVSpeechSynthesisVoice(language: targetLanguage)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentlySpeakingText = nil
    }

    public func isSpeaking(text: String) -> Bool {
        currentlySpeakingText == text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.currentlySpeakingText = nil
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.currentlySpeakingText = nil
        }
    }
}
