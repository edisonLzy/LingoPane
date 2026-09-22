import AppKit
import AVFoundation
import Foundation

/// Orchestrates push-to-talk voice input:
/// hold the voice hotkey → record with a live menu bar waveform →
/// release → speech-to-text → fill the quick-input field for confirmation.
///
/// Audio is only ever kept in memory: the in-memory WAV is handed to the
/// transcription request and released as soon as it completes.
@MainActor
public final class VoiceInputController: NSObject {
    public static let shared = VoiceInputController()

    enum Phase {
        case idle
        case recording
        case transcribing
    }

    /// Shorter presses are treated as accidental taps and ignored.
    static let minimumRecordingDuration: TimeInterval = 0.35
    /// gemma4's audio encoder accepts at most ~30 s of audio
    /// (750 audio tokens × 40 ms), so recording auto-stops just below that.
    static let maximumRecordingDuration: TimeInterval = 29
    private static let waveformFrameRate: TimeInterval = 1.0 / 30.0

    private let recorder = AudioRecorder()
    private var state: AppState?
    private var phase: Phase = .idle
    private var levels: [Float] = []
    private var frameTimer: Timer?
    private var limitTimer: Timer?
    private var transcribeTask: Task<Void, Never>?
    private var startedAt = Date()

    private override init() {
        super.init()
    }

    public func attach(state: AppState) {
        self.state = state
    }

    // MARK: - Hotkey entry points

    public func beginRecording() {
        if phase == .transcribing { cancelTranscription() }
        guard phase == .idle else { return }

        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            startRecording()
        case .denied:
            report(.microphonePermission)
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.startRecordingIfNeeded()
                    } else {
                        self.report(.microphonePermission)
                    }
                }
            }
        @unknown default:
            report(.microphonePermission)
        }
    }

    public func endRecording() {
        guard phase == .recording else { return }
        finishRecording()
    }

    public func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Recording lifecycle

    fileprivate func startRecordingIfNeeded() {
        guard phase == .idle else { return }
        startRecording()
    }

    private func startRecording() {
        do {
            try recorder.start()
        } catch {
            report(.message("无法启动麦克风录音，请检查系统设置"))
            return
        }
        phase = .recording
        levels = []
        startedAt = Date()
        StatusBarController.shared.beginVoiceVisualization()
        frameTimer = Timer.scheduledTimer(
            timeInterval: Self.waveformFrameRate,
            target: self,
            selector: #selector(frameTick),
            userInfo: nil,
            repeats: true
        )
        limitTimer = Timer.scheduledTimer(
            timeInterval: Self.maximumRecordingDuration,
            target: self,
            selector: #selector(limitReached),
            userInfo: nil,
            repeats: false
        )
    }

    @objc private func frameTick() {
        switch phase {
        case .recording:
            WaveformLevels.append(raw: recorder.latestLevel, to: &levels)
            StatusBarController.shared.updateVoiceLevels(levels)
        case .transcribing:
            let elapsed = Date().timeIntervalSince(startedAt)
            StatusBarController.shared.updateVoiceLevels(WaveformLevels.idleLevels(at: elapsed))
        case .idle:
            break
        }
    }

    @objc private func limitReached() {
        finishRecording()
    }

    private func finishRecording() {
        guard phase == .recording else { return }
        limitTimer?.invalidate()
        limitTimer = nil
        let recording = recorder.stop()

        if let recording, recording.duration >= Self.minimumRecordingDuration {
            phase = .transcribing
            transcribe(recording)
        } else {
            // Accidental tap or empty audio: quietly restore the menu bar icon.
            stopVisuals()
        }
    }

    private func transcribe(_ recording: VoiceRecording) {
        transcribeTask = Task { [weak self] in
            do {
                let configuration = try SpeechToTextConfiguration.saved()
                let transcript = try await SpeechToTextService(configuration: configuration)
                    .transcribe(wav: recording.wavData)
                guard !Task.isCancelled else { return }
                self?.finish(transcript: transcript)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finish(failure: (error as? PanelFailure) ?? .message(error.localizedDescription))
            }
        }
    }

    private func cancelTranscription() {
        transcribeTask?.cancel()
        transcribeTask = nil
        stopVisuals()
    }

    private func finish(transcript: String) {
        transcribeTask = nil
        stopVisuals()
        guard let state else { return }
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            report(.message("未识别到语音内容"))
            return
        }
        state.lastError = nil
        // Existing text is preserved so repeated dictation appends instead of
        // overwriting something the user is about to translate.
        let existing = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        state.query = existing.isEmpty ? text : state.query + text
        StatusBarController.shared.showPopover()
    }

    private func finish(failure: PanelFailure) {
        transcribeTask = nil
        stopVisuals()
        report(failure)
    }

    private func report(_ failure: PanelFailure) {
        state?.lastError = failure
        StatusBarController.shared.showPopover()
    }

    private func stopVisuals() {
        phase = .idle
        frameTimer?.invalidate()
        frameTimer = nil
        limitTimer?.invalidate()
        limitTimer = nil
        levels = []
        StatusBarController.shared.endVoiceVisualization()
    }
}
