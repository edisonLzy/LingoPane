@preconcurrency import AVFoundation
import Foundation

struct VoiceRecording: Sendable {
    let wavData: Data
    let duration: TimeInterval
}

/// Records microphone audio with `AVAudioEngine` while a voice hotkey is held.
///
/// Samples stay in memory only: `stop()` drains the buffer and encodes it to
/// an in-memory WAV, which is handed to the transcription service and then
/// released. No audio file is ever written to disk.
@MainActor
final class AudioRecorder {
    enum RecorderError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "无法访问麦克风输入设备"
        }
    }

    private let engine = AVAudioEngine()
    private let capture = AudioCaptureBuffer()

    private(set) var isRecording = false

    /// Latest normalized input level for the menu bar waveform.
    var latestLevel: Float { capture.latestLevel }

    func start() throws {
        guard !isRecording else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0,
              format.channelCount > 0,
              format.commonFormat == .pcmFormatFloat32 else {
            throw RecorderError.unavailable
        }

        capture.reset(sampleRate: format.sampleRate)
        let capture = self.capture
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            capture.ingest(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.unavailable
        }
        isRecording = true
    }

    func stop() -> VoiceRecording? {
        guard isRecording else { return nil }
        isRecording = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        let drained = capture.drainSamples()
        guard !drained.samples.isEmpty, drained.sampleRate > 0 else { return nil }
        let pcm = WAVEncoder.resample(drained.samples, from: drained.sampleRate)
        guard !pcm.isEmpty else { return nil }
        return VoiceRecording(
            wavData: WAVEncoder.wavData(pcm: pcm),
            duration: Double(drained.samples.count) / drained.sampleRate
        )
    }
}
