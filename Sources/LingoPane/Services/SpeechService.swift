@preconcurrency import AVFoundation

@MainActor
public final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = SpeechService()

    @Published public private(set) var isSpeaking = false
    private var currentText: String?
    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func toggle(_ text: String, language: Language = .english) {
        if currentText == text {
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
                isSpeaking = true
                return
            }
            if synthesizer.isSpeaking {
                synthesizer.pauseSpeaking(at: .immediate)
                isSpeaking = false
                return
            }
        }
        synthesizer.stopSpeaking(at: .immediate)
        currentText = text

        let utterance = AVSpeechUtterance(string: text)
        let configuredLocale = language == .english
            ? UserDefaults.standard.string(forKey: "speechLocale") ?? language.localeIdentifier
            : language.localeIdentifier
        utterance.voice = AVSpeechSynthesisVoice(language: configuredLocale)
        utterance.rate = 0.46
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.isSpeaking = false }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.isSpeaking = false }
    }
}
